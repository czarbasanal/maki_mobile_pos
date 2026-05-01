# MAKI POS Web Admin (React)

React + TypeScript + Tailwind rewrite of the Flutter web admin. Migration is
iterative and route-by-route — see `/Users/czar/.claude/plans/migrate-web-admin-from-breezy-lemon.md`
for the full plan.

## Local development

```bash
cd web_admin
cp .env.example .env.local       # fill in Firebase web config from lib/firebase_options.dart
npm install
npm run dev                       # http://localhost:5173/admin/
```

(`pnpm install` / `pnpm dev` and `yarn` / `yarn dev` work too — the scripts in
package.json are package-manager agnostic.)

## Build & deploy (path-based coexistence)

```bash
# 1. Build Flutter web (existing path)
flutter build web

# 2. Build the React admin into build/web/admin/
cd web_admin && npm run build && cd ..

# 3. Single Firebase Hosting deploy serves both
firebase deploy --only hosting
```

`firebase.json` rewrites send `/admin/**` to the React `index.html` and
everything else to the Flutter shell. As routes migrate, additional rewrites
will be added above the Flutter catch-all (and matching guards in
[lib/config/router/web_router.dart](../lib/config/router/web_router.dart) will
404 the migrated paths).

## Layout

```
src/
  domain/          Pure TypeScript entities + repository interfaces (mirrors lib/domain)
  application/     Use cases (one operation per file)
  data/            Firestore converters + repository implementations (mirrors lib/data)
  infrastructure/  Firebase SDK init, TanStack Query client, DI container
  core/            Theme tokens, utils
  presentation/    Router, layouts, components, hooks, Zustand stores, feature pages
```

## Stack

- React 18, TypeScript 5
- Vite 6
- TailwindCSS 3
- React Router v6
- TanStack Query v5 + Zustand
- Firebase JS SDK v11 (Auth + Firestore + Storage)
- React Hook Form + Zod (forms)
- TanStack Table (data tables)
- lucide-react (icons)
- Vitest + React Testing Library (tests)
