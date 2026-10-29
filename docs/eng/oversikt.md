# Overview

Jobb is a Cloudflare Worker with a protected dashboard, a Workflow that does the actual job search and a monthly file with the result.

```text
Dashboard / Cron
        |
        v
Cloudflare Worker ──> D1        runs, applications, monthly limit, settings
        |         ──> R2        evidence from verified applications
        |         ──> Email     sending the monthly file
        v
Workflow ──> Browser Rendering ──> StudentConsulting
```

## Where to find what

| Topic | Page |
| --- | --- |
| Bindings, state, security and logging | [Architecture](architecture.md) |
| The dashboard's views, runs, the monthly limit, error codes, the monthly file and settings | [Automation](automation.md) |
| Sign-in, search, applying and verification at StudentConsulting | [StudentConsulting](providers.md) |
| Cloudflare Access, password mode and encrypted settings | [Sign-in and keys](authentication.md) |
| Deployment, migrations, checks and troubleshooting | [Operations](operations.md) |

## Who owns which data

- **D1** is the single source of truth for runs, applications and the monthly limit.
- **R2** only holds supporting evidence; no decision is made from R2.
- **The Workflow** drives the run but stores no state of its own that the dashboard relies on.
- **Browser Rendering** is only the transport to StudentConsulting. The browser logic stays in `packages/studentconsulting` and does not spread into the rest of the code.
- **The dashboard** shows and controls, but is never a source of truth of its own.

## Before you change anything

- **The automation:** read [Automation](automation.md) and check that the monthly limit and the rules about stopping on uncertainty still hold.
- **StudentConsulting:** read [StudentConsulting](providers.md) and [Architecture](architecture.md). Keep errors at StudentConsulting apart from errors in the run's state.
- **Sign-in:** read [Sign-in and keys](authentication.md) before changing routes, sign-in or Access settings.
