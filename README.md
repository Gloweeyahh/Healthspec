# HealthSpec

A developer-facing interoperability and conformance laboratory for health APIs.
HealthSpec lets teams connect a FHIR implementation, run conformance tests
against it, investigate failures down to the underlying resource, compare
runs over time, and generate evidence-backed reports.

Status: **scaffold** — repo structure, Next.js app shell, and the foundation
database schema (profiles / workspaces / membership / invitations) are in
place. Authentication and the workspace UI are next.

## Stack

- Next.js 14 (App Router) + TypeScript + Tailwind CSS
- Supabase (Postgres + Auth + RLS)
- Netlify (deployment)

## Local development

```bash
cd apps/web
npm install
npm run dev
```

Copy `apps/web/.env.example` to `apps/web/.env.local` and fill in your
Supabase project URL and publishable key (Project Settings → API in the
Supabase dashboard).

## Project structure

```
healthspec/
├── apps/
│   └── web/              Next.js application
├── supabase/
│   └── migrations/       SQL migrations (source of truth for the schema)
├── netlify.toml
└── README.md
```
