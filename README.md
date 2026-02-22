# mistaike-local-stack

Self-contained local development environment for mistaike.ai. Runs the full stack — database, API, UI, and backend pipeline — via Docker Compose with git submodules.

## Quick Start

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/mistaike-ai/mistaike-local-stack.git
cd mistaike-local-stack

# Or if already cloned:
git submodule update --init --recursive

# Start everything
docker compose up -d

# Verify
docker compose ps
curl http://localhost:3002/health    # API
open http://localhost:3001           # UI
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| UI | 3001 | Next.js frontend |
| API (public) | 3002 | FastAPI public endpoints |
| PostgreSQL | 3003 | pgvector/pgvector:pg16 |
| PGAdmin | 3004 | Database admin UI |
| API (internal) | 3005 | FastAPI internal endpoints |
| Redis | 6379 | Cache |
| Ollama | 11434 | Local LLM for validation |
| Validator | — | Tier 2 validation pipeline |
| Tier 3 | — | Full-context validation |
| Tier 4 | — | Reject recovery |
| Sanitizer | — | Content sanitization |
| Extractor | — | Embedding extraction |

Backend pipeline services have no exposed ports — they communicate via PostgreSQL.

## Database Init

On first `docker compose up`, PostgreSQL automatically runs:
1. `init/00_create_roles.sql` — creates `app_user` role
2. `repos/middleware/db/migrations/` — middleware schema (sorted)
3. `repos/backend/db/migrations/` — backend pipeline schema (sorted)
4. `seed/01_test_dumps.sql` — test data (3 validated dumps for sanitizer testing)

To reset the database: `docker compose down -v && docker compose up -d`

## Extractor (Embeddings)

The extractor service needs GCP credentials for Gemini embeddings. It mounts `~/.config/gcloud/application_default_credentials.json` automatically. Run `gcloud auth application-default login` if not already set up.

## Updating Submodules

```bash
git submodule update --remote --merge
```

## Schema Validation

The local stack schema was validated against production on 2026-02-22. Differences are limited to backend migrations 03-05 (split embeddings + sanitizer) which are merged to main but not yet applied to prod.
