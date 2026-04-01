# Repository Agent Rules

This repository expects agents to leave a clean, reviewable git history.

## Commit Requirement

- If you change any repository file, create a git commit for that change before you conclude your work unless the user explicitly says not to commit.
- Once an agent has finished and verified its work, it must merge that work back into `main` before concluding unless the user explicitly says not to.
- Do not leave verified code or documentation edits unstaged or uncommitted.
- Keep commits focused. Use one commit per logical change when practical.
- `make lint` must pass before creating a commit. Do not commit while lint is failing or warnings remain.

## Commit Message Format

- Follow the Lore commit protocol.
- The first line must explain why the change exists.
- After a blank line, include any relevant trailers such as `Constraint:`, `Rejected:`, `Confidence:`, `Scope-risk:`, `Reversibility:`, `Directive:`, `Tested:`, and `Not-tested:`.

## What Not To Commit

- Never commit generated build output or local tool state such as `.build/` or `.omx/`.
- Never commit raw Google Timeline exports, local secrets, or other machine-specific artifacts.

## Verification

- Run the smallest useful verification for the change before committing.
- Treat compiler warnings as failures during verification. Use `make lint` and `make test` so warnings fail the build or test run.
- Report the verification you ran and any known gaps.
