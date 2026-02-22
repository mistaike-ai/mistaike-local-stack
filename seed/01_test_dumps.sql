-- Seed data for local-stack E2E testing
-- Inserts test raw_dumps with validated pipeline state so the sanitizer picks them up
-- Structure matches production schema (schemaVersion 1.0)

BEGIN;

-- Test dump 1: Python null reference bug (single file)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0001-4000-8000-000000000001',
    'test-org/python-app',
    101,
    '{
        "schemaVersion": "1.0",
        "repo": "test-org/python-app",
        "prNumber": "101",
        "title": "fix: handle None return from user lookup",
        "body": "Fixes #99. get_user() crashes with AttributeError when user not found.",
        "createdAt": "2026-01-15T10:00:00Z",
        "mergedAt": "2026-01-15T14:30:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "MIT",
        "licenseUrl": "https://opensource.org/licenses/MIT",
        "copyright": "Test Org",
        "attribution": "test-org/python-app#101",
        "fixScore": {"score": 75, "signals": ["title keyword: fix (25)", "file changes: modified only (30)", "small diff (20)"], "rawScore": 75, "confidence": "high"},
        "files": [
            {
                "filename": "app/users.py",
                "status": "modified",
                "additions": 3,
                "deletions": 1,
                "changes": 4,
                "patch": "@@ -15,7 +15,9 @@\n def get_user(user_id):\n-    return db.query(User).filter_by(id=user_id).first().name\n+    user = db.query(User).filter_by(id=user_id).first()\n+    if user is None:\n+        raise NotFoundError(f\"User {user_id} not found\")\n+    return user.name"
            }
        ],
        "commits": [{"message": "fix: handle None return from user lookup"}],
        "reviews": [],
        "labels": ["bug"]
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0001-4000-8000-000000000001',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump 2: JavaScript off-by-one in pagination (single file)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0002-4000-8000-000000000002',
    'test-org/js-lib',
    202,
    '{
        "schemaVersion": "1.0",
        "repo": "test-org/js-lib",
        "prNumber": "202",
        "title": "fix: off-by-one error in paginate()",
        "body": "Page 1 was returning items starting at index perPage instead of 0.",
        "createdAt": "2026-01-20T09:00:00Z",
        "mergedAt": "2026-01-20T11:00:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "Apache-2.0",
        "licenseUrl": "https://opensource.org/licenses/Apache-2.0",
        "copyright": "Test Org",
        "attribution": "test-org/js-lib#202",
        "fixScore": {"score": 80, "signals": ["title keyword: fix (25)", "file changes: modified only (30)", "small diff (25)"], "rawScore": 80, "confidence": "high"},
        "files": [
            {
                "filename": "src/paginate.js",
                "status": "modified",
                "additions": 1,
                "deletions": 1,
                "changes": 2,
                "patch": "@@ -8,7 +8,7 @@\n function paginate(items, page, perPage) {\n-    const start = page * perPage;\n+    const start = (page - 1) * perPage;\n     const end = start + perPage;\n     return items.slice(start, end);\n }"
            }
        ],
        "commits": [{"message": "fix: off-by-one in pagination"}],
        "reviews": [{"state": "APPROVED"}],
        "labels": ["bug"]
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0002-4000-8000-000000000002',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump 3: Go SQL injection fix (single file)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0003-4000-8000-000000000003',
    'test-org/go-api',
    303,
    '{
        "schemaVersion": "1.0",
        "repo": "test-org/go-api",
        "prNumber": "303",
        "title": "fix: use parameterized query to prevent SQL injection",
        "body": "The search endpoint was vulnerable to SQL injection via the q parameter.",
        "createdAt": "2026-02-01T15:00:00Z",
        "mergedAt": "2026-02-01T16:00:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "MIT",
        "licenseUrl": "https://opensource.org/licenses/MIT",
        "copyright": "Test Org",
        "attribution": "test-org/go-api#303",
        "fixScore": {"score": 85, "signals": ["title keyword: fix (25)", "file changes: modified only (30)", "security fix (30)"], "rawScore": 85, "confidence": "high"},
        "files": [
            {
                "filename": "handlers/search.go",
                "status": "modified",
                "additions": 1,
                "deletions": 1,
                "changes": 2,
                "patch": "@@ -22,7 +22,7 @@\n func SearchHandler(w http.ResponseWriter, r *http.Request) {\n     query := r.URL.Query().Get(\"q\")\n-    rows, err := db.Query(\"SELECT * FROM items WHERE name LIKE ''%\" + query + \"%''\")\n+    rows, err := db.Query(\"SELECT * FROM items WHERE name LIKE $1\", \"%\"+query+\"%\")"
            }
        ],
        "commits": [{"message": "fix: parameterize search query"}],
        "reviews": [{"state": "APPROVED"}],
        "labels": ["security", "bug"]
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0003-4000-8000-000000000003',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

COMMIT;
