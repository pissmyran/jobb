# Jobb

*English translation of the Swedish documentation. The Swedish pages are the original.*

Jobb applies for jobs for you on [StudentConsulting](https://www.studentconsulting.com). Every month ten applications are sent to jobs that match your profile there (**Matcha jobb**), and every application is checked in your account. The month's ten jobs are collected in a text file with job ID, type of job, city and extent. You can download the file or have it emailed, for example as a basis for your activity report.

Everything runs in the container, including the browser that searches the jobs. You do not need a Cloudflare account. The interface is in Swedish.

## Getting started

The image is on Docker Hub as `docker.io/driftaegis/jobb`. The compose file below pulls it from there, so you neither clone the repo nor build anything.

1. **Install Docker.** On Windows and Mac: [Docker Desktop](https://www.docker.com/products/docker-desktop/). On Linux: the `docker.io` package (Debian/Ubuntu) or equivalent. Podman works too.
2. **Create a folder** with a file in it named `docker-compose.yml`. Paste the content below.
3. **Change** `ADMIN_PASSWORD` to a password of your own of at least 8 characters.
4. **Start** it in that folder: `docker compose up -d`. The first time the image is downloaded, and it is large because the browser is included.
5. **Open** `http://localhost:8787` and sign in.
6. **Fill in the settings.** Under **System** you enter the email and password for your StudentConsulting account and turn on **autosubmit**. Jobb then searches automatically on the 10th of every month, and you can start a run by hand on the 1st–14th.

```yaml
services:
  jobb:
    image: docker.io/driftaegis/jobb:1
    restart: unless-stopped
    ports:
      - "8787:8787"
    shm_size: "1gb"
    environment:
      PUBLIC_URL: "http://localhost:8787"
      AUTH_MODE: "password"
      ADMIN_PASSWORD: "change-me-to-a-long-password"
      CF_ACCESS_TEAM_DOMAIN: ""
      CF_ACCESS_AUD: ""
      BROWSER_MODE: "bundled"
      CLOUDFLARE_API_TOKEN: ""
      CLOUDFLARE_ACCOUNT_ID: ""
      SMTP_HOST: ""
      SMTP_PORT: "587"
      SMTP_USER: ""
      SMTP_PASSWORD: ""
    volumes:
      - jobb-data:/data

  tunnel:
    image: docker.io/cloudflare/cloudflared:latest
    profiles: ["tunnel"]
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ""
    depends_on:
      - jobb

volumes:
  jobb-data:
```

## How the month works

- **The applications:** Jobb sends exactly ten verified applications per calendar month, never more. If the result of an application is uncertain, new applications stop until you have checked it under **Ansökningar** (applications).
- **Schedule:** the automatic run happens at 09:00 UTC on the 10th. On the 11th–13th new attempts are made only if the run failed. By hand you can run it on the 1st–14th.
- **The monthly file:** once ten applications are verified, `jobbansokningar_YYYY-MM-DD.txt` is created (the date is the day the tenth application was verified). It is under **Översikt** (overview) and **Månadsfiler** (monthly files), and is sent by email if you have set recipients under **System**.
- **Which jobs:** they come from your profile on StudentConsulting. Under **System** you can narrow the selection further with words, cities and countries.

## Sign-in: two ways

Choose with `AUTH_MODE`.

**`password`** (default): a sign-in page with the password in `ADMIN_PASSWORD`. The session lasts 30 days. Changing the password signs everyone out.

**`cloudflare-access`**: Cloudflare Access handles sign-in, and Jobb checks the signed Access token itself. It needs a Cloudflare account with a domain:
1. **Create a tunnel.** Go to Zero Trust → Networks → Tunnels, create a tunnel and point a public hostname at `http://jobb:8787`. Copy the tunnel token to `TUNNEL_TOKEN`.
2. **Create an Access application.** Go to Zero Trust → Access → Applications and add a *self-hosted* application for the hostname, with a policy for who may sign in.
3. **Fill in the compose file.** Copy the *Application Audience (AUD) Tag* to `CF_ACCESS_AUD` and the team domain to `CF_ACCESS_TEAM_DOMAIN`, and set `AUTH_MODE: "cloudflare-access"`.
4. **Start with the tunnel:** `docker compose --profile tunnel up -d`

## The browser: two ways

Choose with `BROWSER_MODE`.

- **`bundled`** (default): Chrome is in the image. Nothing more is needed. `shm_size: "1gb"` gives Chrome the shared memory it needs.
- **`cloudflare`**: Cloudflare Browser Rendering runs the browser. The image does not get smaller, but the computer running the container does not have to run Chrome. Fill in `CLOUDFLARE_API_TOKEN` (permission *Browser Rendering: Edit*) and `CLOUDFLARE_ACCOUNT_ID`. Browser Rendering is billed per browser hour beyond Cloudflare's free tier.

## Settings

Variables in the compose file:

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `PUBLIC_URL` | No | `http://localhost:8787` | The address you open Jobb at. Used in email. |
| `AUTH_MODE` | No | `password` | `password` or `cloudflare-access`. |
| `ADMIN_PASSWORD` | With `password` | – | At least 8 characters, preferably much longer. |
| `CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD` | With `cloudflare-access` | – | See above. |
| `BROWSER_MODE` | No | `bundled` | `bundled` or `cloudflare`. |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | With `cloudflare` | – | See above. |
| `SMTP_HOST` | For email | – | Outgoing mail server, for example your email provider's SMTP. |
| `SMTP_PORT` | No | `587` | `587` (STARTTLS) or `465` (TLS). |
| `SMTP_USER`, `SMTP_PASSWORD` | For email | – | Sign-in to the SMTP server. Many providers require an app-specific password. |
| `JOBB_CONFIG_KEY` | No | created automatically | Key that encrypts the settings in the database. Created the first time and saved in `/data/config-key`. |
| `PORT` | No | `8787` | The port inside the container. |

Settings made under **System** in the browser, saved encrypted:
- The StudentConsulting account and autosubmit.
- Extra filters: words that must appear, words that must not appear, cities and countries.
- Emailing the monthly file: sender, one or more recipients, and whether it is one shared email or one per recipient.

Values you set as environment variables (`STUDENTCONSULTING_EMAIL`, `STUDENTCONSULTING_PASSWORD`, `STUDENTCONSULTING_AUTOSUBMIT`, `NOTIFY_EMAIL_TO`, `NOTIFY_EMAIL_FROM`, `NOTIFY_EMAIL_MODE`) win over what is saved in System.

### Settings from a file instead

If you do not want values such as passwords in the compose file, put them as `NAME=value` lines in the file `import.env` in the data volume (the one mounted at `/data`) and restart the container. At start the values are saved to `/data/settings.env`, which only the container can read, and `import.env` is deleted. To change a value later, add a new `import.env` with just that line. A line with `NAME=` and no value removes the setting. Values filled in in the compose file take precedence over saved values.

## Data, backup and updates

- Everything lives in the volume mounted at `/data`: the database (SQLite), the evidence for each application, the Workflow state and the encryption key.
- **Back up:** `docker compose stop`, copy the volume and run `docker compose start`. Include `/data/config-key`, or the saved settings cannot be read.
- **Update:** `docker compose pull && docker compose up -d`. Database migrations run automatically at start.
- **Versions:** the tags follow semver. `1` gives every update within version 1, `1.0` only fixes and `1.0.0` exactly one version.

## Technical overview

- **Runtime:** Jobb is written as a Cloudflare Worker with a Cloudflare Workflow. In the container both run in `workerd`, the same runtime Cloudflare uses, through `wrangler dev --local` (Miniflare). D1, R2 and the Workflow state become local files under `/data`.
- **Scheduling:** `wrangler dev` does not start cron runs by itself. So `docker/scheduler.mjs` calls the Worker's scheduled run at 09:00 UTC every day, and the Worker only acts on the 10th–13th.
- **Browser:** the Browser Rendering binding runs against Chrome for Testing, in exactly the version wrangler uses. Chrome is preinstalled in `XDG_CACHE_HOME`, and its libraries come from Debian's apt. It starts with `--no-sandbox` (`CI=true`) because the container has no user namespaces. With `BROWSER_MODE=cloudflare` the binding becomes a remote binding (`remote: true`) against your account.
- **Email:** Cloudflare Email Service does not exist outside Cloudflare, so `docker/container-entry.ts` gives the Worker the same `EMAIL` interface through SMTP over `cloudflare:sockets`. It sends a multipart email with the `.txt` file attached, with STARTTLS or TLS and AUTH LOGIN.
- **Security:**
  - The password session is a signed cookie (HMAC-SHA256, `HttpOnly`, `SameSite=Strict`). Access mode checks the RS256 signature, issuer and AUD.
  - Changing requests require same-origin.
  - The settings are encrypted with AES-GCM, with a key derived from `JOBB_CONFIG_KEY` with HKDF. Passwords are never shown again after they are saved.
- **The image** is based on `node:24-trixie-slim` (Node LTS on Debian stable), runs as the `node` user and has a healthcheck against `/api/health`. It only contains source code with placeholders; your values are filled in when the container starts.
- **Limits:** `wrangler dev` is a development server that runs one process on one machine. That is enough for one person. StudentConsulting's pages can change, and then the search can stop working until the image is updated. Jobb then stops rather than guessing, and the error shows under **Körningar** (runs).
- **Troubleshooting:** `docker compose logs -f`. Every run, application and attempt with its error code is under **Körningar** in the interface.

## Changelog

**1.1.3**
- The image is based on `node:24-trixie-slim`: Node 24 (LTS) on Debian 13 (stable).
- The pnpm version is taken from `packageManager` in `package.json`.

**1.1.2**
- `tools/render.mjs` writes each filled-in file in a loop until every byte is written, so a short write cannot leave a truncated file.

**1.1.1**
- `tools/render.mjs` reads and writes each file through the same file descriptor, so the file cannot be swapped between the check and the write.

**1.1.0**
- Settings can be given once in `/data/import.env` instead of in the compose file. They are saved to `/data/settings.env` and the import file is deleted.
- The image is built from the project's own repo: `docker build -t jobb .`.

**1.0.0**
- First Docker image, with the Worker and its Workflow local under `/data` and the monthly run started inside the container.
- `BROWSER_MODE`: `bundled` (Chrome in the image) or `cloudflare` (Cloudflare Browser Rendering).
- `AUTH_MODE`: `password` or `cloudflare-access`, with an optional Cloudflare Tunnel.
- Email through any SMTP account.
- The encryption key is created automatically the first time.
- The monthly file `jobbansokningar_YYYY-MM-DD.txt` with job ID, job type, city and extent. It is in the dashboard and can be emailed to one or more recipients.

## License

MIT.
