# Gemini Dispatch Process (mistaike.ai)

## Chain: Claude (coordinator) → Haiku (dispatcher) → Gemini (executor)

Claude does NOT call Gemini directly. Claude dispatches via `mistaike-implementor` subagent which uses Haiku. Haiku then sends the work to Gemini (`gemini-3.1-pro-preview`, unlimited quota).

## Dispatch Flow
1. Claude creates GitHub issue with full template (labels, acceptance criteria, TDD, constraints)
2. Claude launches `mistaike-implementor` subagent (Haiku)
3. Haiku formats the prompt with all file content inline (don't let Gemini read files iteratively — wastes Claude tokens)
4. Haiku sends to `gemini-3.1-pro-preview` via `mcp__gemini-minion__run_gemini_yolo`
5. Gemini implements: creates branch, writes tests first, implements, opens PR
6. Claude validates the PR (reads diff, checks CI, runs lint/tests if needed)

## Model Rules
- **Always prefer `gemini-3.1-pro-preview`** — unlimited quota
- **`gemini-3-flash-preview`** — has 24hr quota cap; failover to 3.1-pro if exhausted
- **Never use gemini-2.5 models** — broken/unreliable
- **Ollama cloud (`*:cloud`)** — completely unlimited, use for diagnosis/architecture/stubs

## Timeout Protocol
- `run_gemini_yolo` times out at 1200s but Gemini keeps running in background
- On timeout: check `git branch -a | grep <feature>` and `gh pr list --state open`
- If branch/PR exists → succeeded. Validate the diff. Do NOT re-dispatch.

## Mandatory Dispatch Constraints
Every issue sent to Gemini MUST include:
- "Do NOT create any GitHub issues. If you identify a gap, document it in the PR description only."
- Files in scope: [list exact paths]
- All 12 implementation constraints from the issue template
- Full file content inline in the prompt

## Validation (automatic after Gemini completes)
Whenever Gemini creates a PR, pushes a branch, or reports completion — Claude MUST proactively validate:
- Read the diff
- Check CI status
- Run lint/tests if needed
- Either approve or flag issues
This is automatic — do not wait to be asked.
