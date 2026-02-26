# Changelog

All notable changes to `mistaike-local-stack` are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: SemVer — MAJOR=Ring completion, MINOR=milestone, PATCH=hotfix batch

---

## [Unreleased]

---

## [0.1.0] — 2026-02-26

### Added
- Full local development environment: all services via docker-compose with git submodules
- Redis service with `REDIS_URL` wired into dependent services
- MCP submodule + `VAULT_PLATFORM_KEY` environment variable
- Reusable `deploy-service.yml` workflow for Hetzner deploys

### Changed
- Ollama: use host Ollama proxy (`host.docker.internal:11434`) with cloud model routing
- Seed data updated to match production schema structure

### Fixed
- Skip cloudflared in local dev (not needed outside prod)
- Port conflict resolution for local service bindings
- UI environment variables aligned with production shape
