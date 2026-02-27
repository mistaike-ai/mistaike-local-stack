"""
MCP Hub smoke tests — runs against local-stack (http://localhost:3002).

Coverage:
  Registrations:
    POST   /registrations — valid (none auth)
    POST   /registrations — valid (api_key + credential encrypted, cred not leaked)
    POST   /registrations — invalid name format → 400
    POST   /registrations — quota exceeded (4th) → 403
    GET    /registrations — returns list, no credential fields
    PATCH  /registrations/{id} — field update
    PATCH  /registrations/{id} — credential re-encryption (auth_type change + new cred)
    PATCH  /registrations/{id} — 404 on unknown id
    DELETE /registrations/{id} — success → 204
    DELETE /registrations/{id} — 404 on unknown id
    POST   /registrations/{id}/sync — cache invalidation

  Settings:
    GET    /settings — auto-creates defaults
    GET    /settings — idempotent (second call returns same row)
    PATCH  /settings — updates field

  Logs:
    GET    /logs — empty set
    GET    /logs — with entries, no filter
    GET    /logs — filter by registration_id
    GET    /logs — filter by status
    GET    /logs/{id}/decrypt — valid encrypted payload → plaintext
    GET    /logs/{id}/decrypt — 404 when no encrypted_payload
    DELETE /logs/{id} — success → 204
    DELETE /logs/{id} — 404 on unknown id
    DELETE /logs  — bulk delete by registration_id

  Auth:
    Any endpoint — unauthenticated → 401
"""

import base64
import json
import os
import secrets
import subprocess
import sys
import uuid
from datetime import datetime, timezone

import requests
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

BASE = "http://localhost:3002/api/v1/mcp-hub"
AUTH_URL = "http://localhost:3002/api/v1/auth/login"
SMOKE_EMAIL = "mcp-smoke@example.com"
SMOKE_PASSWORD = "SmokeHub123@"
VAULT_PLATFORM_KEY = os.environ.get(
    "VAULT_PLATFORM_KEY", "FBlDrawLFRMBwd98e7IPYCT8SlI6VfNvyozEBdbG2iA="
)
DB_DSN = os.environ.get(
    "DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:3003/pattern_db"
)

PASS = 0
FAIL = 0
RESULTS = []


# ── Helpers ───────────────────────────────────────────────────────────────────

def ok(label, detail=""):
    global PASS
    PASS += 1
    msg = f"  PASS  {label}"
    if detail:
        msg += f"\n        {detail}"
    print(msg)
    RESULTS.append((True, label))


def fail(label, detail=""):
    global FAIL
    FAIL += 1
    msg = f"  FAIL  {label}"
    if detail:
        msg += f"\n        {detail}"
    print(msg)
    RESULTS.append((False, label))


def check(label, resp, expected_status):
    if resp.status_code == expected_status:
        ok(label)
        return True
    else:
        fail(label, f"got {resp.status_code}, want {expected_status}: {resp.text[:200]}")
        return False


def psql(sql):
    """Run SQL directly against local postgres."""
    result = subprocess.run(
        ["docker", "exec", "mistake-postgres-dev",
         "psql", "-U", "postgres", "-d", "pattern_db", "-t", "-c", sql],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"psql error: {result.stderr}")
    return result.stdout.strip()


def get_user_vault_key(user_id: str) -> bytes:
    """Decrypt the user's vault key using the platform Fernet key."""
    row = psql(f"SELECT vault_key_encrypted FROM users WHERE id='{user_id}';")
    if not row:
        raise RuntimeError(f"No vault_key_encrypted for user {user_id}")
    fernet = Fernet(VAULT_PLATFORM_KEY.encode())
    return fernet.decrypt(row.strip().encode())


def make_encrypted_log_payload(user_key: bytes, payload: dict) -> dict:
    """Encrypt a log payload the same way the route expects to decrypt it.
    Route decrypt: AESGCM(user_key).decrypt(payload_iv, encrypted_payload+payload_auth_tag, None)
    """
    nonce = os.urandom(12)
    data = json.dumps(payload).encode()
    ciphertext_with_tag = AESGCM(user_key).encrypt(nonce, data, None)
    encrypted_payload = ciphertext_with_tag[:-16]
    auth_tag = ciphertext_with_tag[-16:]
    return {
        "payload_iv": nonce,
        "encrypted_payload": encrypted_payload,
        "payload_auth_tag": auth_tag,
    }


def insert_log_entry(registration_id: str, tool_name: str, enc: dict | None = None) -> str:
    """Insert a mcp_call_logs row directly. Returns the log id."""
    log_id = str(uuid.uuid4())
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S+00")
    if enc:
        iv_hex = "\\x" + enc["payload_iv"].hex()
        ep_hex = "\\x" + enc["encrypted_payload"].hex()
        tag_hex = "\\x" + enc["payload_auth_tag"].hex()
        psql(
            f"INSERT INTO mcp_call_logs "
            f"(id, registration_id, tool_name, called_at, status, "
            f" encrypted_payload, payload_iv, payload_auth_tag) "
            f"VALUES ('{log_id}', '{registration_id}', '{tool_name}', '{now_str}', 'success', "
            f" '{ep_hex}', '{iv_hex}', '{tag_hex}');"
        )
    else:
        psql(
            f"INSERT INTO mcp_call_logs "
            f"(id, registration_id, tool_name, called_at, status) "
            f"VALUES ('{log_id}', '{registration_id}', '{tool_name}', '{now_str}', 'success');"
        )
    return log_id


# ── Auth ──────────────────────────────────────────────────────────────────────

def get_token() -> tuple[str, str]:
    """Login and return (token, user_id)."""
    r = requests.post(AUTH_URL, json={"email": SMOKE_EMAIL, "password": SMOKE_PASSWORD})
    if r.status_code != 200:
        print(f"FATAL: login failed {r.status_code}: {r.text}")
        sys.exit(1)
    d = r.json()
    return d["access_token"], d.get("user_id") or d.get("id", "")


def headers(token):
    return {"Authorization": f"Bearer {token}"}


# ── Test sections ─────────────────────────────────────────────────────────────

def test_unauthenticated():
    print("\n── Unauthenticated ──")
    r = requests.get(f"{BASE}/settings")
    check("GET /settings without token → 401", r, 401)


def test_settings(token):
    print("\n── Settings ──")
    h = headers(token)

    # First call — auto-creates defaults
    r = requests.get(f"{BASE}/settings", headers=h)
    if check("GET /settings (auto-create)", r, 200):
        d = r.json()
        assert "include_native_tools" in d, "missing include_native_tools"
        assert "log_retention_days" in d, "missing log_retention_days"
        ok("GET /settings response shape")

    # Second call — idempotent, same created_at
    r2 = requests.get(f"{BASE}/settings", headers=h)
    if check("GET /settings (idempotent, 2nd call)", r2, 200):
        if r.json()["created_at"] == r2.json()["created_at"]:
            ok("GET /settings created_at unchanged on 2nd call")
        else:
            fail("GET /settings created_at changed — settings re-created")

    # PATCH
    r = requests.patch(f"{BASE}/settings", headers=h,
                       json={"log_retention_days": 30, "include_native_tools": False})
    if check("PATCH /settings", r, 200):
        d = r.json()
        assert d["log_retention_days"] == 30
        assert d["include_native_tools"] is False
        ok("PATCH /settings response values correct")

    # Restore
    requests.patch(f"{BASE}/settings", headers=h,
                   json={"log_retention_days": 90, "include_native_tools": True})


def test_registrations(token) -> list[str]:
    """Returns list of created registration IDs for cleanup."""
    print("\n── Registrations ──")
    h = headers(token)
    created_ids = []

    # Valid — no credential
    r = requests.post(f"{BASE}/registrations", headers=h, json={
        "name": "test-server",
        "url": "https://mcp.example.com/sse",
        "auth_type": "none",
        "log_mode": "metadata",
    })
    if check("POST /registrations (none auth)", r, 201):
        reg_id = r.json()["id"]
        created_ids.append(reg_id)
        # Credential columns must not appear
        body = r.json()
        for col in ("credentials_encrypted", "credentials_iv", "credentials_auth_tag", "credentials_salt"):
            if col in body:
                fail(f"POST /registrations — {col} leaked in response")
            else:
                ok(f"POST /registrations — {col} not in response")
    else:
        reg_id = None

    # Valid — api_key with credential
    r = requests.post(f"{BASE}/registrations", headers=h, json={
        "name": "auth-server",
        "url": "https://mcp2.example.com/sse",
        "auth_type": "api_key",
        "credential": "sk-secret-12345",
        "log_mode": "metadata",
    })
    if check("POST /registrations (api_key + credential)", r, 201):
        reg2_id = r.json()["id"]
        created_ids.append(reg2_id)
        if "sk-secret" not in r.text:
            ok("POST /registrations — credential not leaked in response")
        else:
            fail("POST /registrations — raw credential in response body")

    # Invalid name (spaces → 400)
    r = requests.post(f"{BASE}/registrations", headers=h, json={
        "name": "invalid name!",
        "url": "https://mcp.example.com/sse",
        "auth_type": "none",
    })
    check("POST /registrations — invalid name → 400", r, 400)

    # Third registration
    r = requests.post(f"{BASE}/registrations", headers=h, json={
        "name": "third-server",
        "url": "https://mcp3.example.com/sse",
        "auth_type": "none",
    })
    if check("POST /registrations (3rd — at quota limit)", r, 201):
        created_ids.append(r.json()["id"])

    # Fourth → quota exceeded
    r = requests.post(f"{BASE}/registrations", headers=h, json={
        "name": "fourth-server",
        "url": "https://mcp4.example.com/sse",
        "auth_type": "none",
    })
    check("POST /registrations — quota exceeded → 403", r, 403)

    # GET list
    r = requests.get(f"{BASE}/registrations", headers=h)
    if check("GET /registrations", r, 200):
        items = r.json()
        assert len(items) == 3, f"expected 3, got {len(items)}"
        ok(f"GET /registrations — count={len(items)}")
        for item in items:
            for col in ("credentials_encrypted", "credentials_iv"):
                if col in item:
                    fail(f"GET /registrations — {col} in list item")

    if reg_id:
        # PATCH — field update
        r = requests.patch(f"{BASE}/registrations/{reg_id}", headers=h,
                           json={"enabled": False})
        if check("PATCH /registrations/{id} — field update", r, 200):
            assert r.json()["enabled"] is False
            ok("PATCH /registrations/{id} — enabled=False confirmed")

        # PATCH — credential re-encryption (change to api_key + new cred)
        r = requests.patch(f"{BASE}/registrations/{reg_id}", headers=h,
                           json={"auth_type": "api_key", "credential": "sk-new-cred-xyz"})
        if check("PATCH /registrations/{id} — credential re-encryption", r, 200):
            if "sk-new-cred" not in r.text:
                ok("PATCH /registrations/{id} — new credential not leaked")
            else:
                fail("PATCH /registrations/{id} — new credential in response")

        # PATCH — 404
        r = requests.patch(f"{BASE}/registrations/{uuid.uuid4()}", headers=h,
                           json={"enabled": True})
        check("PATCH /registrations/{id} — 404 on unknown id", r, 404)

        # POST /sync
        r = requests.post(f"{BASE}/registrations/{reg_id}/sync", headers=h)
        check("POST /registrations/{id}/sync", r, 200)

        # DELETE — success
        r = requests.delete(f"{BASE}/registrations/{reg_id}", headers=h)
        check("DELETE /registrations/{id} — success → 204", r, 204)
        created_ids.remove(reg_id)

        # DELETE — 404 (same id again)
        r = requests.delete(f"{BASE}/registrations/{reg_id}", headers=h)
        check("DELETE /registrations/{id} — 404 on already-deleted", r, 404)

        # DELETE — 404 random
        r = requests.delete(f"{BASE}/registrations/{uuid.uuid4()}", headers=h)
        check("DELETE /registrations/{id} — 404 on unknown id", r, 404)

    return created_ids


def test_logs(token, user_id, registration_id):
    print("\n── Logs ──")
    h = headers(token)

    # GET /logs — empty
    r = requests.get(f"{BASE}/logs", headers=h)
    if check("GET /logs — empty", r, 200):
        assert r.json() == [], f"expected [], got {r.json()}"
        ok("GET /logs — empty list confirmed")

    # Insert log entries directly to exercise filter and decrypt paths
    user_key = get_user_vault_key(user_id)

    # Log with encrypted payload
    enc = make_encrypted_log_payload(user_key, {"args": {"query": "null pointer"}, "result": "found 3 patterns"})
    encrypted_log_id = insert_log_entry(registration_id, "search__find_patterns", enc)

    # Plain log (no payload)
    plain_log_id = insert_log_entry(registration_id, "search__count_patterns")

    # Log with different status
    plain_log_id2 = insert_log_entry(registration_id, "search__find_patterns")
    psql(f"UPDATE mcp_call_logs SET status='error' WHERE id='{plain_log_id2}';")

    # GET /logs — with entries
    r = requests.get(f"{BASE}/logs", headers=h)
    if check("GET /logs — with entries", r, 200):
        items = r.json()
        assert len(items) == 3, f"expected 3, got {len(items)}"
        ok(f"GET /logs — {len(items)} entries returned")
        # Encrypted payload columns must not appear in list
        for item in items:
            if "encrypted_payload" in item:
                fail("GET /logs — encrypted_payload leaked in list")

    # GET /logs — filter by registration_id
    r = requests.get(f"{BASE}/logs", headers=h,
                     params={"registration_id": registration_id})
    if check("GET /logs — filter by registration_id", r, 200):
        ok(f"GET /logs?registration_id — {len(r.json())} items")

    # GET /logs — filter by status=error
    r = requests.get(f"{BASE}/logs", headers=h, params={"status": "error"})
    if check("GET /logs — filter by status=error", r, 200):
        items = r.json()
        if all(i["status"] == "error" for i in items):
            ok(f"GET /logs?status=error — all {len(items)} items have status=error")
        else:
            fail("GET /logs?status=error — returned non-error items")

    # GET /logs/{id}/decrypt — success
    r = requests.get(f"{BASE}/logs/{encrypted_log_id}/decrypt", headers=h)
    if check("GET /logs/{id}/decrypt — success", r, 200):
        d = r.json()
        if "decrypted_payload" in d:
            payload = d["decrypted_payload"]
            if payload.get("args", {}).get("query") == "null pointer":
                ok("GET /logs/{id}/decrypt — payload content correct")
            else:
                fail(f"GET /logs/{id}/decrypt — wrong content: {payload}")
        else:
            fail(f"GET /logs/{id}/decrypt — missing decrypted_payload key: {d}")

    # GET /logs/{id}/decrypt — 404 when no encrypted payload
    r = requests.get(f"{BASE}/logs/{plain_log_id}/decrypt", headers=h)
    check("GET /logs/{id}/decrypt — 404 when no encrypted_payload", r, 404)

    # GET /logs/{id}/decrypt — 404 unknown id
    r = requests.get(f"{BASE}/logs/{uuid.uuid4()}/decrypt", headers=h)
    check("GET /logs/{id}/decrypt — 404 unknown id", r, 404)

    # DELETE /logs/{id} — success
    r = requests.delete(f"{BASE}/logs/{plain_log_id}", headers=h)
    check("DELETE /logs/{id} — success → 204", r, 204)

    # DELETE /logs/{id} — 404
    r = requests.delete(f"{BASE}/logs/{plain_log_id}", headers=h)
    check("DELETE /logs/{id} — 404 on already-deleted", r, 404)

    # DELETE /logs — bulk by registration_id
    r = requests.delete(f"{BASE}/logs", headers=h,
                        params={"registration_id": registration_id})
    if check("DELETE /logs — bulk delete by registration_id", r, 200):
        count = r.json().get("count", -1)
        ok(f"DELETE /logs bulk — deleted {count} entries")

    # Confirm logs empty after bulk delete
    r = requests.get(f"{BASE}/logs", headers=h)
    if check("GET /logs — empty after bulk delete", r, 200):
        items = r.json()
        if len(items) == 0:
            ok("GET /logs — confirmed empty after bulk delete")
        else:
            fail(f"GET /logs — expected 0, got {len(items)} after bulk delete")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("MCP Hub smoke tests — local-stack")
    print("=" * 60)

    token, user_id = get_token()

    # If user_id not in login response, fetch from /me or DB
    if not user_id:
        row = psql(f"SELECT id FROM users WHERE email='{SMOKE_EMAIL}';")
        user_id = row.strip()
    print(f"  user_id = {user_id}")

    test_unauthenticated()
    test_settings(token)
    reg_ids = test_registrations(token)

    # Use first surviving registration for log tests
    if reg_ids:
        test_logs(token, user_id, reg_ids[0])
    else:
        print("\nWARN: no surviving registrations — skipping log tests")

    # Cleanup remaining registrations
    h = headers(token)
    for rid in reg_ids:
        requests.delete(f"{BASE}/registrations/{rid}", headers=h)

    print("\n" + "=" * 60)
    print(f"  PASSED: {PASS}   FAILED: {FAIL}")
    print("=" * 60)
    return FAIL


if __name__ == "__main__":
    sys.exit(main())
