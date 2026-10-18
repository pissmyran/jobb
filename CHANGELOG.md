# Changelog

Versions follow [semver](https://semver.org). The Docker image is tagged `X.Y.Z`, `X.Y`, `X` and `latest`.

## 1.1.0 – 2026-10-18

- Settings can be given once in `/data/import.env` instead of in `docker-compose.yml`: they are saved to `/data/settings.env`, readable only by the container, and the import file is deleted. `NAME=` removes a setting; non-empty compose variables still win.
- The project now lives in its own repository, so the image builds from the repo root with `docker build -t jobb .`.

## 1.0.0 – 2026-10-17

- First Docker image: the Worker and its Workflow run in workerd via `wrangler dev --local`, with D1, R2 and workflow state under `/data`. Migrations run on start, and the monthly schedule (09:00 UTC on the 10th–13th) is triggered inside the container.
- `BROWSER_MODE`: `bundled` (Chrome inside the image) or `cloudflare` (Cloudflare Browser Rendering).
- `AUTH_MODE`: `password` (built-in login page and session cookie) or `cloudflare-access` (Access JWT). Optional Cloudflare Tunnel service in `docker-compose.yml`.
- E-mail over any SMTP account (`SMTP_*`) when Cloudflare Email Service is not available.
- The configuration encryption key is generated once and kept in `/data` when `JOBB_CONFIG_KEY` is not set.
- No reporting to Arbetsförmedlingen (there is no API). The month's ten applications are collected in `jobbansokningar_YYYY-MM-DD.txt` with job ID, job type, city and scope, downloadable from the overview and e-mailed to one or more recipients.
