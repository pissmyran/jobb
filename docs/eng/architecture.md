# Architecture

## Runtime

The Worker `jobb` starts in `apps/web/src/index.ts` and is configured in `wrangler.jsonc` at the repo root. It has these bindings:

| Binding | Type | Used for |
| --- | --- | --- |
| `DB` | D1 | All state: runs, applications, attempts, monthly limit, monthly files, sending and settings |
| `EVIDENCE` | R2 (`jobb-evidence`) | Evidence from verified applications and integration checks |
| `BROWSER` | Browser Rendering | The browser that talks to StudentConsulting |
| `JOB_AUTOMATION` | Workflow (`JobAutomationWorkflow`) | The run itself |
| `EMAIL` | Email | Sending the monthly file |
| `JOBB_CONFIG_KEY` | Secrets Store | The key that encrypts the settings in D1 |
| `ASSETS` | Static files | The dashboard's HTML, CSS and JavaScript |

Cron `0 9 10-13 * *` starts the scheduled run, and the Worker answers on its own domain.

In Docker the same Worker runs from `docker/container-entry.ts` with `docker/wrangler.template.jsonc`. There, email is sent with SMTP instead of `EMAIL`, and the browser is either Chrome in the image or Cloudflare Browser Rendering.

## State in D1

The migrations in `migrations/` are the schema's history and run in numeric order.

| Migration | Contents |
| --- | --- |
| `0001_initial.sql` | Jobs, applications, attempts and evidence |
| `0002_automation.sql` | Runs and send history |
| `0003_integration_probes.sql` | Metadata about integration checks |
| `0004_monthly_application_quota.sql` | Ten slots per month |
| `0005_activity_report_submission.sql` | Reporting to Arbetsförmedlingen (removed in 0009) |
| `0006_runtime_configuration.sql` | Encrypted settings |
| `0007_monthly_activity_exports.sql` | The monthly files |
| `0008_runtime_configuration_access_identity.sql` | Who last changed the settings |
| `0009_drop_af_reporting.sql` | Removes the reporting to Arbetsförmedlingen and rebuilds `notifications` for email sending |

The states:

- **Application:** `queued → applying → submitted → verified`, with `failed` and `needs_user_action` as exceptions.
- **Attempt:** `started → submitted | verified | failed | unknown`.
- **Slot in the monthly limit:** `free → reserved → submitted | verified | uncertain`.
- **Run:** `running → completed | failed`. A run that has been `running` without a Workflow and without applications for more than five minutes is shown as abandoned and closed before the next start.

The D1 database must be created with `jurisdiction=eu`. It cannot be changed afterwards, so a switch is done by exporting and importing into a new database.

## Settings

The settings come from two places, and the Worker's own variables and secrets always win:

1. Variables and secrets on the Worker (or in the container's environment).
2. The encrypted document in the D1 table `runtime_configuration`, saved under **System** in the dashboard.

The document is encrypted with AES-GCM before it is saved. The key is derived with HKDF from `JOBB_CONFIG_KEY`. D1 only holds ciphertext, IV, schema version and who made the change; no values can be read out as columns. See [Sign-in and keys](authentication.md) for key rotation.

## The monthly limit

The monthly limit is exactly ten slots in D1, and a slot is reserved before anything is sent to StudentConsulting. An uncertain result keeps its slot as `uncertain` and blocks, so the system can never accidentally send an eleventh application. The details are in [Automation](automation.md).

## Security

- **Sign-in:** Cloudflare Access in front of the Worker, and the Worker checks the Access JWT on every request. A self-hosted install can use `AUTH_MODE=password` instead. See [Sign-in and keys](authentication.md).
- **Changes:** every changing request requires exactly the same `Origin` as the page, and `Sec-Fetch-Site` is rejected if it shows a different origin.
- **Responses:** the dashboard is sent with a strict CSP (only its own scripts, stylesheets and connections, no `unsafe-inline`), `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `frame-ancestors 'none'` and `Cache-Control: no-store`.
- **Secrets:** passwords, browser sessions and keys are never logged, never sent back to the browser and never end up in R2.

## Logging

As set in `wrangler.jsonc`: every log is kept (sampling 1, with invocation logs), traces at 1 %, query strings masked and Workers Issues on. The code only logs errors and warnings and at most a couple of lines per run.
