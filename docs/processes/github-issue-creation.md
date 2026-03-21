# GitHub Issue Creation Process (mistaike.ai)

## Only the coordinator (Claude) creates issues. Gemini MUST NEVER create issues.

## Mandatory Labels (every issue, no exceptions)
- Ring: `ring:1` (default) / `ring:2` / `ring:3`
- Type: `type:bug` / `type:feature` / `type:test` / `type:refactor` / `type:infra`
- Priority: `priority:high` if blocking launch or Ring gate
- Assignment: `assigned:gemini` when dispatched

## Issue Body Template

```
## Context
[What this is and why we need it]

## MCP Checks Required
Before writing any code:
- `check_known_failures` query: "[problem domain]" language: "[Python|TypeScript|etc]"
- `search_by_code` on any existing code you're modifying
After any bug fix:
- `submit_error_pattern` with the error + fix

## Acceptance Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]

## TDD Requirement
Write tests first. Verify they fail before implementing.
Tests location: [exact path]

## Implementation Notes — MANDATORY CONSTRAINTS
1. Only modify files required for this issue. Files in scope: [list exact paths]
2. Verify all imports before using them
3. No local imports inside functions when module-level exists
4. All retry loops MUST have max retry count
5. AUTH CHANGES REQUIRE EXPLICIT APPROVAL
6. String escaping: use "\n" not "\\n"
6b. Alembic revision IDs must be generated, never hand-written
6c. Verify component is actually imported before modifying it
6d. Never run raw DDL against prod/UAT
7. Coverage floor: every PR must raise threshold by ≥5%
8. PR description = issue body verbatim
9. PR must reference #NNN, include Closes #NNN, update CHANGELOG
10. Branch setup: fetch → checkout main → reset → checkout -b feat/
11. Never cherry-pick unrelated commits — rebase instead
12. When merging UI PRs that change text, grep smoke tests for matches

Do NOT create any GitHub issues. If you identify a gap, document it in the PR description only.
```

## PR Structure (CI-enforced)
- Reference #NNN in title or body
- `Closes #NNN` on its own line
- Update CHANGELOG.md under [Unreleased]
- Kimi hard-fails if changelog diff is empty or alignment doesn't match
