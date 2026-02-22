-- Seed data for local-stack E2E testing
-- Inserts test raw_dumps with validated pipeline state so the sanitizer picks them up

BEGIN;

-- Test dump 1: Python null reference bug
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0001-4000-8000-000000000001',
    'test-org/python-app',
    101,
    '{
        "title": "Fix null reference in user lookup",
        "diff": "--- a/app/users.py\n+++ b/app/users.py\n@@ -15,7 +15,8 @@\n def get_user(user_id):\n-    return db.query(User).filter_by(id=user_id).first().name\n+    user = db.query(User).filter_by(id=user_id).first()\n+    if user is None:\n+        raise NotFoundError(f\"User {user_id} not found\")\n+    return user.name",
        "language": "Python",
        "files_changed": ["app/users.py"],
        "additions": 3,
        "deletions": 1
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0001-4000-8000-000000000001',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump 2: JavaScript off-by-one
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0002-4000-8000-000000000002',
    'test-org/js-lib',
    202,
    '{
        "title": "Fix off-by-one in pagination",
        "diff": "--- a/src/paginate.js\n+++ b/src/paginate.js\n@@ -8,7 +8,7 @@\n function paginate(items, page, perPage) {\n-    const start = page * perPage;\n+    const start = (page - 1) * perPage;\n     const end = start + perPage;\n     return items.slice(start, end);\n }",
        "language": "JavaScript",
        "files_changed": ["src/paginate.js"],
        "additions": 1,
        "deletions": 1
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0002-4000-8000-000000000002',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump 3: Go SQL injection fix
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'aaaaaaaa-0003-4000-8000-000000000003',
    'test-org/go-api',
    303,
    '{
        "title": "Fix SQL injection in search endpoint",
        "diff": "--- a/handlers/search.go\n+++ b/handlers/search.go\n@@ -22,7 +22,7 @@\n func SearchHandler(w http.ResponseWriter, r *http.Request) {\n     query := r.URL.Query().Get(\"q\")\n-    rows, err := db.Query(\"SELECT * FROM items WHERE name LIKE ''%\" + query + \"%''\")\n+    rows, err := db.Query(\"SELECT * FROM items WHERE name LIKE $1\", \"%\"+query+\"%\")",
        "language": "Go",
        "files_changed": ["handlers/search.go"],
        "additions": 1,
        "deletions": 1
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'aaaaaaaa-0003-4000-8000-000000000003',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

COMMIT;
