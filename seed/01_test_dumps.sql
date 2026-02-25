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

-- Test dump A: changedetection.io mark_viewed refactor (minimal context test)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'bbbbbbbb-0001-4000-8000-000000000001',
    'dgtlmoon/changedetection.io',
    3888,
    '{
        "schemaVersion": "1.0",
        "repo": "dgtlmoon/changedetection.io",
        "prNumber": 3888,
        "title": "fix: mark_viewed uses background thread only for large watch counts",
        "body": "",
        "createdAt": "2026-02-01T10:00:00Z",
        "mergedAt": "2026-02-01T14:00:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "Apache-2.0",
        "licenseUrl": "https://opensource.org/licenses/Apache-2.0",
        "copyright": "dgtlmoon",
        "attribution": "dgtlmoon/changedetection.io#3888",
        "fixScore": {"score": 70, "signals": ["title keyword: fix (25)", "file changes: modified only (30)", "small diff (15)"], "rawScore": 70, "confidence": "medium"},
        "files": [
            {
                "filename": "changedetectionio/blueprint/tags/__init__.py",
                "status": "modified",
                "additions": 7,
                "deletions": 5,
                "changes": 12,
                "patch": "@@ -194,9 +194,9 @@ def mark_all_viewed():\n         tag_limit = request.args.get(''tag'')\n         now = int(time.time())\n \n-        # Mark watches as viewed in background thread to avoid blocking\n-        def mark_viewed_background():\n-            \"\"\"Background thread to mark watches as viewed - discarded after completion.\"\"\"\n+        # Mark watches as viewed - use background thread only for large watch counts\n+        def mark_viewed_impl():\n+            \"\"\"Mark watches as viewed - synchronous for small counts.\"\"\"\n             for watch_uuid, watch in self.watching.items():\n                 if not tag_limit or watch.get(''tags'') and tag_limit in watch.get(''tags''):\n                     watch[''last_viewed''] = now\n-        t = threading.Thread(target=mark_viewed_background)\n-        t.start()\n+        if len(self.watching) < 10:\n+            mark_viewed_impl()\n+        else:\n+            t = threading.Thread(target=mark_viewed_impl)\n+            t.start()"
            }
        ],
        "commits": [{"message": "fix: optimise mark_viewed for small watch counts"}],
        "reviews": [],
        "labels": ["bug"]
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'bbbbbbbb-0001-4000-8000-000000000001',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump B: roboflow mask dtype fix (minimal context test)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'bbbbbbbb-0002-4000-8000-000000000002',
    'roboflow/supervision',
    1445,
    '{
        "schemaVersion": "1.0",
        "repo": "roboflow/supervision",
        "prNumber": 1445,
        "title": "fix: cast detection mask to bool dtype before applying",
        "body": "",
        "createdAt": "2026-02-05T09:00:00Z",
        "mergedAt": "2026-02-05T11:00:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "MIT",
        "licenseUrl": "https://opensource.org/licenses/MIT",
        "copyright": "Roboflow",
        "attribution": "roboflow/supervision#1445",
        "fixScore": {"score": 68, "signals": ["title keyword: fix (25)", "file changes: modified only (30)", "small diff (13)"], "rawScore": 68, "confidence": "medium"},
        "files": [
            {
                "filename": "supervision/annotators/core.py",
                "status": "modified",
                "additions": 1,
                "deletions": 1,
                "changes": 2,
                "patch": "@@ -440,7 +440,7 @@ def annotate(\n                 if custom_color_lookup is None\n                 else custom_color_lookup,\n             )\n-            mask = detections.mask[detection_idx]\n+            mask = np.asarray(detections.mask[detection_idx], dtype=bool)\n             colored_mask[mask] = color.as_bgr()"
            }
        ],
        "commits": [{"message": "fix: ensure mask is bool array for numpy indexing"}],
        "reviews": [],
        "labels": ["bug"]
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'bbbbbbbb-0002-4000-8000-000000000002',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

-- Test dump C: TODO removal (non-bug, should be accurately described)
INSERT INTO raw_dumps (id, repo, pr_number, content) VALUES (
    'bbbbbbbb-0003-4000-8000-000000000003',
    'some-org/some-app',
    999,
    '{
        "schemaVersion": "1.0",
        "repo": "some-org/some-app",
        "prNumber": 999,
        "title": "Remove TODO comments",
        "body": "",
        "createdAt": "2026-02-10T08:00:00Z",
        "mergedAt": "2026-02-10T10:00:00Z",
        "scrapedAt": "2026-02-20T00:00:00Z",
        "license": "MIT",
        "licenseUrl": "https://opensource.org/licenses/MIT",
        "copyright": "Test Org",
        "attribution": "some-org/some-app#999",
        "fixScore": {"score": 30, "signals": ["small diff (15)", "comment removal (15)"], "rawScore": 30, "confidence": "low"},
        "files": [
            {
                "filename": "src/utils.py",
                "status": "modified",
                "additions": 0,
                "deletions": 2,
                "changes": 2,
                "patch": "@@ -1,5 +1,3 @@\n-# TODO: clean this up later\n-# TODO: add error handling\n def process(x):\n     return x * 2"
            }
        ],
        "commits": [{"message": "chore: remove TODO comments"}],
        "reviews": [],
        "labels": []
    }'::jsonb
) ON CONFLICT (repo, pr_number) DO NOTHING;

INSERT INTO dump_pipeline_state (dump_id, status, current_tier) VALUES (
    'bbbbbbbb-0003-4000-8000-000000000003',
    'validated',
    'tier2'
) ON CONFLICT (dump_id) DO NOTHING;

COMMIT;
