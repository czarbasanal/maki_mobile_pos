# CLAUDE.md

Standing instructions for working in this repo. Follow these every session.

## Development loop

Use this loop for any non-trivial change. Don't skip steps; don't claim done without the last two.

1. **Brainstorm** — clarify intent & design before writing code (`brainstorming` skill).
2. **Plan** — enter plan mode for anything touching multiple files; get approval before editing (`writing-plans`).
3. **TDD implement** — write the failing test first, then the code (`test-driven-development`).
4. **`/code-review`** — review the diff for bugs and cleanups.
5. **`/verify`** — run the app / tests and confirm the change actually works.
6. **Finish branch** — merge or open a PR cleanly (`finishing-a-development-branch`).

Skip straight to implementation only for trivial, single-file mechanical edits.

## Two surfaces, two toolchains

This repo holds a Flutter app (root) and a React web admin (`web_admin/`). Run checks against whichever surface you changed.

### Flutter app (root: `lib/`, `test/`)
- Test: `flutter test`
- Lint/analyze: `flutter analyze`
- Tests mirror `lib/` structure: `config/ core/ data/ domain/ presentation/`.

### Web admin (`web_admin/` — React + Vite + TypeScript + Vitest)
- Typecheck: `npm run typecheck`
- Test: `npm run test`
- Build: `npm run build`
- Dev server: `npm run dev`
- Run these from inside `web_admin/`.

## Verification before "done"

Never assert a change works without running the relevant `flutter test` / `flutter analyze`
or `npm run typecheck` / `npm run test` and confirming the output. If tests fail or a step was
skipped, say so plainly with the output (`verification-before-completion`).

## Git

- Branch before committing; don't commit/push unless asked.
- Shared Firestore writes (`receivings`, stock, variations) and `firestore.rules` are
  production-affecting — confirm before deploying rules or touching shared collections.
