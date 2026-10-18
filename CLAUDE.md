# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The public source of jobb: a monthly job-application helper on Cloudflare Workers, plus its self-hosted Docker image. It is one of four sibling repos (dumpen, jobb, klarsprak, politiker); shared community files, issue forms and the GitHub settings for all of them live in the account's `.github` repo. The code is generic: it contains no account ids, domains, e-mail addresses, keys or other personal values — only `__NAME__` placeholders. Real values live outside the repo and are filled in at deploy (`tools/render.mjs`) or by the user in `docker-compose.yml`. Read `AGENTS.md`, `README.md` and `docs/` before larger changes.

| Dir | Entry | Handlers | Bindings |
|---|---|---|---|
| `.` | `apps/web/src/index.ts` | fetch, scheduled `0 9 10-13 * *`, Workflow `JobAutomationWorkflow` | D1, R2, Browser Rendering, send_email, Secrets Store `JOBB_CONFIG_KEY` |

## The one rule: no personal values

Never write a real id, domain, e-mail address, key, name, donation link or payment detail into code, config, tests, docs or commit messages. Use a placeholder declared in `cloudflare.example.env` (code and config) or `example.com`-style values (docs and tests). Personal assets such as images go in an overlay directory outside the repo. The repo is public.

## Placeholders and deploy

- Every `__NAME__` used in the code must be declared in `cloudflare.example.env`, with an example value and a comment saying where the real value comes from.
- `node tools/render.mjs <values.env | -> <out-dir> [overlay-dir]` copies the repo, fills in every declared placeholder (failing if a value is missing), copies the overlay on top, drops routes with an empty pattern and links `node_modules`. With `-` the values come from environment variables.
- Default deploy, from a private values file: render, then `npx wrangler deploy --cwd build`. The rendered copy is thrown away afterwards; Cloudflare keeps the values. Secrets go in with `npx wrangler secret put` or once from a file with `npx wrangler secret bulk <file.json>`, and the file is deleted.
- Workers Builds (GitHub connection) works the same way with the values as Cloudflare build variables: build command `node tools/render.mjs - build`, deploy command `npx wrangler deploy --cwd build`. Only the production branch builds; non-production branch builds stay off.
- Deploy the new Worker before applying a migration that drops tables or columns.
- Tests run on the unrendered source, so they see the placeholders.
- Values that encrypt stored data (jobb's `CONFIG_NAMESPACE`) must never change for an existing database.

## Commands

```bash
npx pnpm@10.17.1 install && npx pnpm@10.17.1 typecheck && npx pnpm@10.17.1 test
```

Formatting: Prettier with `.prettierrc.json` (printWidth 100). Run `npx prettier --write <paths>` after editing; CI runs `prettier --check .`. Tests that read source files must not depend on formatting; prefer importing and calling real code over matching source text.

## Architecture

- **jobb**: applies for ten suitable jobs a month on StudentConsulting through a Workflow using `@cloudflare/playwright` over Browser Rendering, and collects them in `jobbansokningar_YYYY-MM-DD.txt` (job ID, job type, city, scope), downloadable and e-mailed to one or more recipients. No reporting to Arbetsförmedlingen (there is no API). Production auth is Cloudflare Access (Access JWT); `AUTH_MODE=password` exists only for self-hosting. The D1 runtime configuration row is AES-GCM encrypted with a key derived from `JOBB_CONFIG_KEY` (rotate via `JOBB_CONFIG_KEY_PREVIOUS`).

## Cost and logging

Target the Workers Free plan: 10 ms CPU per invocation. No full inventory or rescan on each cron run, request or added item; work incrementally and cache derived data at write time.

Logging, as in the sibling repos: logs at sampling 1 with invocation logs, traces at 0.01, query strings redacted, Workers Issues on. Keep volume down in the code: log errors and warnings, plus at most a line or two per run. Handled errors reach Issues only through `console.error`.

## Docker image

- `Dockerfile` (build from the repo root: `docker build -t jobb .`), `docker-compose.yml`, `CHANGELOG.md` and `docker/` (`README.md` is the Docker Hub page, `entrypoint.sh`, `import-settings.sh`, the container wrangler config).
- The Worker runs in workerd through `wrangler dev --local` with all state under `/data`. The entrypoint renders the source with `tools/render.mjs` from the container environment with zero-setup defaults, and generates missing encryption keys once into `/data`. Images start empty and never read from anyone's Cloudflare resources.
- Settings come from `docker-compose.yml`, or once from `/data/import.env`: `import-settings.sh` merges it into `/data/settings.env` and deletes it. Non-empty compose variables win.
- Keep `docker/README.md` in step with `docker-compose.yml` and `CHANGELOG.md`. Versions are semver. To publish, bump the version (package.json or version.txt) and CHANGELOG.md, push, then push a tag `vX.Y.Z`: `.github/workflows/docker.yml` builds the image and pushes `X.Y.Z`, `X.Y`, `X` and `latest` to Docker Hub with the organization's `DOCKERHUB_TOKEN`.

## GitHub

GitHub is the public home, the off-machine backup and the external review layer. Push finished, clean work straight to `main`; there are no pull-request requirements and no work branches. The only rules on `main` are no deletion and no rewritten history. Before pushing, run the tests and the local review: `cr review --uncommitted --agent -c ../coderabbit/.coderabbit.yaml` (CodeRabbit with the organization's central rules in `VineHarbor/coderabbit`; takes 2–15 minutes). That is the code review; leaked secrets are stopped by push protection and vulnerable dependencies show up as Dependabot alerts; CI, CodeQL (default setup, extended suite), secret scanning and Dependabot security alerts then run on GitHub. Read the findings once at the start of a session and act on real ones: a fault gets a fix, a finding that shows the design went wrong gets a rethink, noise is dismissed with a reason. Never sit watching CI. Dependencies are updated locally about once a month; Dependabot only opens security updates. Workflows use only GitHub's own actions, pinned by commit SHA, with a read-only token, and never `pull_request_target`. Nothing may be enabled that can cost money.
