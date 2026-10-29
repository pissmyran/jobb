# Operations

## Checks before pushing

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## Local development

1. Copy `.dev.vars.example` to `.dev.vars` and fill in the values.
2. Run `pnpm dev`. It starts Wrangler with `wrangler.jsonc` at the repo root.

## Deployment

Production is deployed from a rendered copy with your own values, either from your computer or with Workers Builds when a PR is merged to `main`; see the [home page](index.md). CI on GitHub runs tests, the Docker build and CodeQL. There is no preview environment.

## Migrations

Workers Builds does not run the D1 migrations, so they are run by hand from a rendered copy:

```bash
node tools/render.mjs <your-file.env> build
npx wrangler d1 migrations apply DB --remote --cwd build
```

- **A migration that adds** tables or columns runs before the new Worker is deployed.
- **A migration that removes** tables or columns runs after the new Worker is out.

## Checklist after deployment

1. **Sign-in:** open the dashboard in a private window and sign in through Cloudflare Access.
2. **Readiness:** `GET /api/ready` must answer `200` with `database`, `dashboardAuth` and `runtimeConfiguration` set to `true`.
3. **Bindings:** the Worker must have D1 `DB`, R2 `EVIDENCE`, Browser Rendering `BROWSER`, Email `EMAIL`, Workflow `jobb-automation` and Secrets Store `JOBB_CONFIG_KEY`.
4. **StudentConsulting:** check under **Körningar** (runs) that the latest run signed in and reached *Matcha jobb*. A saved password is no proof that the account works.

## D1

- The database must be created with `jurisdiction=eu`. It cannot be changed afterwards, so a switch is done as an export and import into a new EU database before the binding is changed.
- Read replicas must stay off as long as the code does not use the D1 Sessions API.

## Before a manual rerun

1. The month's run `scheduled:YYYY-MM` and its status.
2. The month's slots in the monthly limit.
3. Applications that are `uncertain`.
4. The latest errors and evidence from StudentConsulting.
5. That a new run cannot go above ten.

## Stopping and deleting runs

A run that is `running` can be stopped in the run's details. The Workflow instance is ended first, and the run is saved as `failed` with `RUN_STOPPED_BY_USER`. A finished run can only be deleted if it has no applications; its Workflow instance, sends and integration checks are then deleted too. Runs with applications are always kept.

## Abandoned runs

A run counts as abandoned when D1 shows `running`, no Workflow instance is linked, there are no applications and `updated_at` is older than five minutes. It is shown as abandoned in the dashboard and set to `failed` before the next start.

During an incident, check in this order:

1. The Workflow instance's status and errors in Cloudflare.
2. `automation_runs.status`, `workflow_instance_id`, `last_error` and `updated_at` in D1.
3. Whether the run has applications or attempts, or may have sent something to StudentConsulting.
4. The slots in the monthly limit and any `uncertain` before a new attempt.

A run that may have sent something to StudentConsulting must never be treated as abandoned just because the Workflow link is missing.

## Errors at StudentConsulting

- Leave the run's state in D1 as it is.
- Mark an unclear application as `uncertain`.
- Do not retry blindly if StudentConsulting may have received the application.
- Check the evidence and StudentConsulting's own history before anything is sent again.

## Sign-in errors

1. Check the Access application for the domain and its policy in Zero Trust.
2. Check that `CF_ACCESS_AUD` is the application's AUD tag and `CF_ACCESS_TEAM_DOMAIN` is `<team>.cloudflareaccess.com`.
3. Check that `/api/ready` shows `dashboardAuth: true`.

Never add Basic Auth or another sign-in path as a fallback.
