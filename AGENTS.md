# Repository Agent Rules

This repository expects agents to leave a clean, reviewable git history.

## Commit Requirement

- If you change any repository file, create a git commit for that change before you conclude your work unless the user explicitly says not to commit.
- Do not perform task work directly on `main`; while an agent is actively working, that work must live on a dedicated branch checked out in a dedicated worktree unless the user explicitly says otherwise.
- If a user asks an agent to resume or follow up on previously finished work, the agent must recreate a dedicated branch and worktree before making additional changes so the work still happens off `main`.
- Once an agent has finished and verified its work, it must merge that work back into `main` before concluding unless the user explicitly says not to.
- If `main` has advanced since the agent branched, the agent must inspect the intervening commit or commits before merging and confirm there is no logical conflict with the branch changes, including behavior or user-experience regressions that Git would merge cleanly without flagging as a textual conflict.
- After merging verified work back into `main`, the agent must delete the task worktree and remove the task branch before concluding unless the user explicitly says not to.
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

## Privacy & PII

- Never send a user's location history, coordinates, photo metadata, thumbnails, or other PII to any external server or network-backed service by default.
- Any exception requires the user's explicit permission for that specific transfer before the code path is introduced or used.
- Prefer fully local processing and local-only platform APIs. If a platform integration can cause data to sync outside the app, disclose that caveat before making user-facing privacy guarantees.

## Verification

- Run the smallest useful verification for the change before committing.
- Treat compiler warnings as failures during verification. Use `make lint` and `make test` so warnings fail the build or test run.
- Report the verification you ran and any known gaps.
