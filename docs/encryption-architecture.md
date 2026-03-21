# mistaike.ai — Encryption Architecture

How customer data is encrypted at rest and in transit across the mistaike platform.

---

## Overview

mistaike uses **envelope encryption** — a pattern where data is encrypted with a unique per-record key (DEK), and that key is itself encrypted with a per-user key (KEK), which is in turn protected by a platform master key. No single key compromise exposes customer data without the rest of the chain.

```
Customer Data
    ↓
[AES-256-GCM with random DEK]
    ↓
DEK wrapped with user KEK (derived via HKDF-SHA256)
    ↓
User key wrapped with platform master key (Fernet)
    ↓
Platform key encrypted with DATABASE_ENCRYPTION_KEY (Fernet)
    ↓
Stored in PostgreSQL
```

---

## Key Hierarchy

### Layer 1: DATABASE_ENCRYPTION_KEY

- Environment variable, set at deployment
- Fernet key (AES-128-CBC + HMAC-SHA256)
- Encrypts the platform master key in the `system_settings` table
- Never stored in the database — lives only in the runtime environment

### Layer 2: Vault Platform Key (Master Key)

- Stored encrypted in the `system_settings` table under key `vault_platform_key`
- Encrypted at rest with `DATABASE_ENCRYPTION_KEY` using Fernet
- Base64-encoded Fernet key (32-byte symmetric key)
- Retrieved by the middleware at runtime, decrypted in memory, never logged
- Used to wrap/unwrap per-user vault keys

### Layer 3: Per-User Vault Key

- 32 bytes generated via `os.urandom(32)` (CSPRNG) on first vault access
- Stored in the `users.vault_key_encrypted` column, wrapped with the platform key using Fernet
- Each user has a unique key — no key sharing between users
- Generated automatically when a user first enables their vault
- The raw key is never persisted in plaintext

### Layer 4: Per-Record Data Encryption Key (DEK)

- 32 bytes generated via CSPRNG for **every encryption operation**
- Used once, then discarded after wrapping
- Fresh DEK per record means identical plaintext produces different ciphertext
- Wrapped with the user's KEK (derived from their vault key via HKDF-SHA256)

---

## Encryption Process (Write Path)

When a customer's data is stored:

1. **Generate DEK**: A fresh 32-byte random key is created
2. **Encrypt content**: Plaintext is encrypted with AES-256-GCM using the DEK, producing ciphertext + 12-byte IV + 16-byte authentication tag
3. **Derive KEK**: The user's vault key is passed through HKDF-SHA256 with info context `b"user-kek-v1"` to produce a 32-byte key encryption key
4. **Wrap DEK**: The DEK is encrypted with AES-256-GCM using the KEK, producing a wrapped DEK + its own IV + authentication tag
5. **Store envelope**: Six fields are written to the database:

| Column | Contents |
|--------|----------|
| `encrypted_blob` | AES-256-GCM ciphertext of the record |
| `content_iv` | 12-byte nonce for content encryption |
| `content_auth_tag` | 16-byte GCM tag for content integrity |
| `dek_encrypted` | AES-256-GCM ciphertext of the DEK |
| `dek_iv` | 12-byte nonce for DEK wrapping |
| `dek_auth_tag` | 16-byte GCM tag for DEK integrity |

---

## Decryption Process (Read Path)

When a customer requests their data:

1. **Authenticate**: User proves identity via MFA (TOTP challenge)
2. **Retrieve platform key**: Fetched from `system_settings`, decrypted with `DATABASE_ENCRYPTION_KEY`
3. **Unwrap user key**: User's `vault_key_encrypted` decrypted with the platform key
4. **Derive KEK**: HKDF-SHA256 with `b"user-kek-v1"` context
5. **Unwrap DEK**: `dek_encrypted` decrypted with the KEK, verified by `dek_auth_tag`
6. **Decrypt content**: `encrypted_blob` decrypted with the recovered DEK, verified by `content_auth_tag`
7. **Return plaintext**: Delivered over HTTPS to the authenticated user

---

## What Is Encrypted

The envelope encryption pattern is applied consistently across all sensitive data:

| Data Type | Table | What's Encrypted |
|-----------|-------|-----------------|
| Vault submissions | `pattern_submissions` | User-submitted code patterns |
| MCP call logs | `mcp_call_logs` | Request/response payloads from tool calls |
| MCP hub credentials | `mcp_hub_registrations` | OAuth tokens, API keys for connected servers |
| Security events | `mcp_security_events` | DLP hits, blocked requests, audit data |
| OAuth provider tokens | `user_oauth_providers` | Third-party auth credentials |
| Memory Vault entries | `user_memories` | Agent memories, project context, notes |

---

## Algorithms

| Purpose | Algorithm | Parameters |
|---------|-----------|------------|
| Content encryption | AES-256-GCM | 32-byte key, 12-byte IV, 16-byte tag |
| DEK wrapping | AES-256-GCM | 32-byte key, 12-byte IV, 16-byte tag |
| KEK derivation | HKDF-SHA256 | 32-byte output, no salt, info = `user-kek-v1` |
| User key wrapping | Fernet | AES-128-CBC + HMAC-SHA256 |
| Platform key wrapping | Fernet | AES-128-CBC + HMAC-SHA256 |
| Content hashing | HMAC-SHA256 | Keyed with user KEK (for dedup in Memory Vault) |
| Random generation | `os.urandom()` | CSPRNG — DEKs, user keys, IVs |

---

## Authenticated Encryption

AES-256-GCM provides both **confidentiality** (data is unreadable without the key) and **integrity** (any modification to ciphertext, IV, or tag is detected on decryption). This is enforced at two levels:

- **Content layer**: The GCM tag on the encrypted blob ensures the record hasn't been tampered with
- **Key layer**: The GCM tag on the wrapped DEK ensures the key material hasn't been substituted

If either tag fails verification, decryption is rejected entirely. There is no partial decryption.

---

## MFA Gating

Platform-managed decryption requires a valid TOTP code before the server will unwrap any keys. The sequence is:

1. User requests decryption of a record
2. Server challenges for TOTP code
3. User provides 6-digit code from their authenticator app
4. Server verifies TOTP against the user's stored secret
5. Only on success: keys are unwrapped and content is decrypted
6. Decrypted content returned over HTTPS

Without a valid MFA code, the server will not access the user's vault key — even if the request is authenticated with a valid session token.

---

## Team Sharing

When a user shares an encrypted record with a team:

1. The record's DEK is unwrapped using the sharing user's KEK
2. The team's KEK is derived from the team key via HKDF-SHA256 with info `b"team-kek-v1"`
3. The DEK is re-wrapped with the team's KEK
4. The team's wrapped DEK is stored in `vault_team_keys` alongside `granted_by` and `granted_at` metadata

The record's ciphertext is never re-encrypted — only the DEK wrapping changes. Team members decrypt by unwrapping the DEK with their team's KEK, then decrypting the content with the recovered DEK.

---

## Memory Vault Deduplication

Memory Vault uses content hashing to prevent duplicate entries:

1. Before storing, `HMAC-SHA256(plaintext, user_KEK)` is computed
2. If the hash matches an existing memory's `content_hash`, the existing record is updated
3. The HMAC is keyed with the user's KEK — so identical content from different users produces different hashes
4. The hash reveals nothing about the plaintext without the key

---

## In Transit

- All client-server communication over HTTPS (TLS 1.2+)
- Cloudflare WAF terminates TLS at the edge, re-encrypts to origin
- Encrypted payloads transmitted as base64-encoded JSON — no plaintext secrets in request/response bodies
- API keys transmitted via `Authorization: Bearer` header, never in query strings or request bodies

---

## Safeguards Summary

| Threat | Mitigation |
|--------|------------|
| Database breach | All sensitive data encrypted with AES-256-GCM; keys stored encrypted |
| Single key compromise | Envelope pattern — DEK, user key, and platform key are all separate |
| Ciphertext tampering | GCM authentication tags on both content and DEK layers |
| Key reuse | Fresh 32-byte DEK generated per encryption operation |
| Cross-user access | Per-user keys — one user's key cannot decrypt another's data |
| Stolen session token | MFA required before any decryption operation |
| Insider access | Platform key encrypted at rest; raw keys exist only in process memory |
| IV reuse | 12-byte random IV generated per encryption; with unique DEKs, collision risk is negligible |
| Key material in logs | Keys never logged; decrypted content never persisted outside the response |
