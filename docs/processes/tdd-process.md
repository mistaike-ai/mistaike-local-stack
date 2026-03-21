# TDD Process (mistaike.ai)

## Mandatory for all implementation
Red → Green → Refactor. No exceptions. No skipping tests.

## Pre-flight (before any test generation)
- **Python**: read pyproject.toml, tests/unit/conftest.py, 2 nearest test files, docs/dev/test-conventions.md
- **UI**: read ui/tsconfig.json, ui/vite.config.ts, 2 nearest __tests__ files, docs/dev/test-conventions.md, run npm run type-check

## Test Locations
- Middleware unit: mistaike-db-middleware/tests/unit/
- Middleware integration: mistaike-db-middleware/tests/integration/
- UI: mistaike-db-ui/ui/src/__tests__/
- MCP: mistaike-mcp/tests/
- Backend: mistaike-db-backend/src/tests/unit/
- Smoke/E2E: mistaike-portainer/smoke/ (NEVER in service repos)

## Coverage
- 90% minimum enforced (hard gate in CI)
- Every PR must raise coverage threshold by ≥5% or bring actual above current floor
- Coverage ratchet was repeatedly ignored → user enforced hard 90%

## Model Routing for Tests
- All implementation: gemini-3.1-pro-preview (unlimited, preferred)
- Quick stubs: gemini-3-flash-preview
- Test failure diagnosis: DeepSeek V3.2 via Ollama cloud
- React/TypeScript tests: Kimi K2.5 via Ollama cloud

## Issue Template TDD Requirement
Every GitHub issue must include:
- TDD requirement section (tests first, verify they fail)
- Tests location (exact path)
- MCP check requirement (which domain/language to query)

## For test-only issues
TDD not strictly required — write and run tests directly. Acceptance criteria should specify test file paths, test function names, pass/fail behaviour.
