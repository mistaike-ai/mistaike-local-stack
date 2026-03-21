# CLAUDE.md Rules Summary (mistaike.ai)

Coordinator (Claude) plans, specs, reviews, dispatches. Gemini (gemini-3.1-pro-preview, unlimited) executes. Gemini MUST NEVER create GitHub issues.

## Non-Negotiable Rules
1. **MCP at every moment**: check_known_failures before implementing, submit_error_pattern after every fix
2. **Issue-first**: every task needs a GitHub issue with ring label, acceptance criteria, TDD requirement
3. **TDD always**: Red → Green → Refactor, no exceptions
4. **Branch + PR always**: never push to main directly
5. **Tags and changelogs**: every merged PR reflected in CHANGELOG.md under [Unreleased]
6. **No infra config changes** without explicit instruction

## CI/CD
- Build/deploy: `[self-hosted, linux, m700]` always (Hetzner runners)
- Never `ubuntu-latest` (except mcp-hub public repo)
- PR must reference #NNN issue + update CHANGELOG + Closes #NNN
- Kimi K2.5 peer review is a hard gate

## Git Rules
- Worktrees preferred over checkout/reset
- Never `git reset --hard origin/main` on a feature branch
- Never cherry-pick unrelated commits onto PR branches — rebase instead
- Never `--no-verify`, never `--admin` on merge

## Auth Rules
- Auth changes require explicit human approval
- Vault platform key: read from system_settings DB, never env var

## Alembic Rules
- Never hand-write revision IDs
- Never run raw DDL against prod/UAT
- All schema changes via alembic revision + migration in a PR

## Deploy Pipeline
push main → build on Hetzner → UAT webhook → smoke tests (Playwright) → semver tag → prod deploy
- Smoke tests live in mistaike-portainer/smoke/ only
- Smoke accounts: smoke-plain@mistaike.ai, smoke-mfa@mistaike.ai
