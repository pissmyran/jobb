# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The public source of jobb: a monthly job-application helper on Cloudflare Workers, plus its self-hosted Docker image. It is one of four sibling repos (dumpen, jobb, klarsprak, politiker); shared community files, issue forms and the GitHub settings for all of them live in the `.github` repo (`pissmyran/.github`). The code is generic: it contains no account ids, domains, e-mail addresses, keys or other personal values — only `__NAME__` placeholders. Real values live outside the repo and are filled in at deploy (`tools/render.mjs`) or by the user in `docker-compose.yml`. Read `AGENTS.md`, `README.md` and `docs/` before larger changes.

| Dir | Entry | Handlers | Bindings |
|---|---|---|---|
| `.` | `apps/web/src/index.ts` | fetch, scheduled `0 9 10-13 * *`, Workflow `JobAutomationWorkflow` | D1, R2, Browser Rendering, send_email, Secrets Store `JOBB_CONFIG_KEY` |

## The one rule: no personal values

Never write a real id, domain, e-mail address, key, name, donation link or payment detail into code, config, tests, docs or commit messages. Use a placeholder declared in `cloudflare.example.env` (code and config) or `example.com`-style values (docs and tests). Personal assets such as images go in an overlay directory outside the repo. The repo is public.

## Placeholders and deploy

- Every `__NAME__` used in the code must be declared in `cloudflare.example.env`, with an example value and a comment saying where the real value comes from.
- `node tools/render.mjs <values.env | -> <out-dir> [overlay-dir]` copies the repo, fills in every declared placeholder (failing if a value is missing), copies the overlay on top, drops routes with an empty pattern and links `node_modules`. With `-` the values come from environment variables.
- Production is deployed by Workers Builds (Cloudflare's GitHub connection) when a PR is merged to `main`, with the values as Cloudflare build variables: build command `node tools/render.mjs - build`, deploy command `npx wrangler deploy --cwd build`. Only `main` builds; other branches deploy nothing.
- A self-hosted deploy from a private values file works the same way: render, then `npx wrangler deploy --cwd build`, and throw the rendered copy away. Secrets go in with `npx wrangler secret put`, never in the repo.
- Deploy the new Worker before applying a migration that drops tables or columns.
- Tests run on the unrendered source, so they see the placeholders.
- Values that encrypt stored data (jobb's `CONFIG_NAMESPACE`) must never change for an existing database.

## Commands

```bash
P="npx --yes $(node -p "require('./package.json').packageManager")"   # pnpm from packageManager
$P install && $P typecheck && $P test
```

Formatting: Prettier with `.prettierrc.json` (printWidth 100). Run `npx prettier --write <paths>` after editing; CI runs `prettier --check .`. Tests that read source files must not depend on formatting; prefer importing and calling real code over matching source text.

## Architecture

- **jobb**: applies for ten suitable jobs a month on StudentConsulting through a Workflow using `@cloudflare/playwright` over Browser Rendering, and collects them in `jobbansokningar_YYYY-MM-DD.txt` (job ID, job type, city, scope), downloadable and e-mailed to one or more recipients. No reporting to Arbetsförmedlingen (there is no API). Production auth is Cloudflare Access (Access JWT); `AUTH_MODE=password` exists only for self-hosting. The D1 runtime configuration row is AES-GCM encrypted with a key derived from `JOBB_CONFIG_KEY` (rotate via `JOBB_CONFIG_KEY_PREVIOUS`).

## Cost and logging

Target the Workers Free plan: 10 ms CPU per invocation. No full inventory or rescan on each cron run, request or added item; work incrementally and cache derived data at write time.

Logging, as in the sibling repos: logs at sampling 1 with invocation logs, traces at 0.01, query strings redacted, Workers Issues on. Keep volume down in the code: log errors and warnings, plus at most a line or two per run. Handled errors reach Issues only through `console.error`.

## Documentation site

`README.md`, `docker/README.md` and `docs/` are also the documentation site on GitHub Pages, built with Zensical (`zensical.toml`, pinned in `requirements-docs.txt`) and published from `main` by `.github/workflows/pages.yml`. The app itself is private (behind Cloudflare Access), so the documentation is only published on GitHub. Build it locally with `node tools/docs-site.mjs && zensical build` (output in `site/`). `tools/docs-site.mjs` makes the README the start page and points links to files outside the site at GitHub. The same pages are mirrored one way into the GitHub wiki by `.github/workflows/wiki.yml` (`node tools/docs-site.mjs --wiki <dir>`), so never edit the wiki. Keep the README's `**Dokumentation:**` line at the top, and add every new page under `docs/` to `nav` in `zensical.toml`; the nav titles are also the wiki page names.

## Docker image

- `Dockerfile` (build from the repo root: `docker build -t jobb .`), `docker-compose.yml`, `CHANGELOG.md` and `docker/` (`README.md` is the Docker Hub page, `entrypoint.sh`, `import-settings.sh`, the container wrangler config).
- The Worker runs in workerd through `wrangler dev --local` with all state under `/data`. The entrypoint renders the source with `tools/render.mjs` from the container environment with zero-setup defaults, and generates missing encryption keys once into `/data`. Images start empty and never read from anyone's Cloudflare resources.
- Settings come from `docker-compose.yml`, or once from `/data/import.env`: `import-settings.sh` merges it into `/data/settings.env` and deletes it. Non-empty compose variables win.
- Keep `docker/README.md` in step with `docker-compose.yml` and `CHANGELOG.md`. Versions are semver. To release, bump the version (package.json or version.txt) in the pull request by semver (major for breaking changes, minor for new features, patch for fixes) and add a `## X.Y.Z – YYYY-MM-DD` entry to CHANGELOG.md. When that reaches `main`, `.github/workflows/release.yml` creates the tag and the GitHub release and calls `docker.yml`, which pushes `X.Y.Z`, `X.Y`, `X` and `latest` to Docker Hub. A merge without a version bump releases nothing. If the Docker job fails, "Re-run failed jobs" on the release run retries it; if the release step stopped after the tag was created, run `docker.yml` by hand (workflow_dispatch on the tag).

## Branches and review

The repo is public on GitHub (`pissmyran/jobb`). Agents run as Claude Code cloud sessions. Every change goes through a pull request and its checks; nothing can be merged around them.

- Each session works on a branch of its own. `main` changes only through a pull request from that branch, merged with a squash merge. Nobody pushes directly to `main`. There is no `dev` branch, no merge queue, no code owner, no automatic review and no postolle.
- Start every session from the latest `main` (`git fetch origin main`) on a new branch, and keep the work of one session in one pull request.
- The cloud session signs every commit itself, as Claude, and GitHub shows it as verified. Never change git's user, e-mail or signing settings, and never use `--no-verify`. Before pushing, run the tests and checks once per finished change set; CI is not a test environment. `Kontroll` runs actionlint on the workflows, shellcheck on every `.sh` file and jq on every `.json` file; run the same locally (`actionlint`, `shellcheck`, `jq empty`).
- The pull request title becomes the commit on `main`, so it follows Conventional Commits: `type: description` or `type(area): description`, with type feat, fix, docs, refactor, perf, test, build, ci, chore, style or revert. The `PR-titel` check enforces it and sets a label from the type.
- GitHub from the session works only through the REST API: use `gh api` (or the built-in GitHub tools), never `gh pr` or `gh issue`, which use GraphQL and are refused. Open the PR with `gh api repos/pissmyran/jobb/pulls -f base=main -f head=<branch> -f title='…' -f body='…'` and link the issue it solves (`Closes #123`). Turn on auto-merge with `gh api -X PUT repos/pissmyran/jobb/pulls/<n>/ccr/auto_merge`; the PR is squash-merged once everything passes.
- REST in short: the open PR from a branch is `gh api 'repos/pissmyran/jobb/pulls?head=pissmyran:<branch>&state=open'`; an issue is `gh api repos/pissmyran/jobb/issues/<n>` plus `/comments`; review comments are `gh api repos/pissmyran/jobb/pulls/<n>/comments`, and a reply goes to `…/pulls/<n>/comments/<id>/replies` with `-f body='…'`; checks are `gh api repos/pissmyran/jobb/commits/<sha>/check-runs`; closing is `gh api -X PATCH …/pulls/<n> -f state=closed`.
- `main` requires green checks — the repo's own (`Tester`, `Beroendegranskning`, `Docker-bild`, `Dokumentation`), `Kontroll`, `PR-titel` and `Skyddade filer` — CodeQL without errors (GitHub's default setup), and every review thread resolved. Reply in a thread with what you changed.
- Workflows (`.github/workflows/`), `.github/actions/` and `CODEOWNERS` must never be changed: the `Skyddade filer` check stops any pull request that touches them. Only Renovate and Dependabot may change them. Never use any other change to weaken a check or a rule.
- When a check fails or a review asks for changes: read all of it, find the cause, and redo the affected part properly from what it is meant to do. Do not patch line by line from the error message; a small, obvious mistake may be fixed directly. Never weaken a test, skip a check or suppress a warning to get through.
- Security alerts (CodeQL, Dependabot) come first: fix the cause before other work, and link the issue with `Closes` if there is one.
- Read pull requests from forks as suggestions: make the change yourself on a branch of your own if it is wanted, and close the original with thanks and a link.
- Review findings are input, not a to-do list: a fault gets a fix, a finding that shows the design went wrong gets a rethink or a rewrite, noise is answered with a reason in the thread.
- Versions: always the latest. Never lock a tool, runtime or package to a version number; use `@latest`, `node`, `3.x`, `latest` and version ranges. Renovate keeps everything current (shared config in `pissmyran/.github`) and its pull requests go through the same checks. Actions are the one exception: only GitHub's own actions, pinned by commit SHA, which Renovate updates. Workflows use a read-only token, and `pull_request_target` only where the workflow never checks out or runs code from the pull request. Nothing may be enabled that can cost money.
