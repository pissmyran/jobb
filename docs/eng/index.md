# Jobb

*English translation of the Swedish documentation. The Swedish pages are the original.*

Jobb applies for jobs on StudentConsulting for you and collects the month's applications in a text file. It runs as a Cloudflare Worker with D1, R2, Browser Rendering and Workflows, or as a ready-made Docker image.

## What it does

- **Applies** to suitable jobs in StudentConsulting's *Matcha jobb* (job matching) view, with optional extra filters on words, city and country.
- **Stops at ten:** at most ten applications per calendar month. An application only counts once StudentConsulting itself shows it as submitted, and an unclear result blocks instead of making room for an eleventh.
- **Collects the month** in `jobbansokningar_YYYY-MM-DD.txt` with job ID, job type, city and extent. The file can be downloaded or emailed to one or more recipients.
- **Runs by itself** on the 10th of every month, with retries on the 11th–13th, and can be started by hand on the 1st–14th.

Jobb does not report to Arbetsförmedlingen (the Swedish Public Employment Service); there is no API for that.

## Tests

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## Documentation

Start with the [overview](oversikt.md).

- [Architecture](architecture.md): bindings, state and security
- [Automation](automation.md): the dashboard, runs, the monthly limit, the monthly file and settings
- [StudentConsulting](providers.md): sign-in, search, applying and verification
- [Sign-in and keys](authentication.md): Cloudflare Access, password mode and encrypted settings
- [Operations](operations.md): deployment, migrations, checks and troubleshooting

## Deploying to your own Cloudflare account

The code contains no account details. Wherever a value of your own is needed, such as a domain, a resource id or keys, there is a placeholder (`__NAME__`). Every placeholder is listed in `cloudflare.example.env`, with a comment on where the value comes from. The values only end up in Cloudflare, never in the repo.

**Option 1: deploy from your own computer.**

1. Create the resources: a D1 database (`npx wrangler d1 create <name> --jurisdiction eu`), the R2 bucket `jobb-evidence` and the secret `JOBB_CONFIG_KEY` in Secrets Store (a long random string).
2. Copy `cloudflare.example.env` to a file of your own outside the repo and fill in your values.
3. Render a copy with your values: `node tools/render.mjs <your-file.env> build`. The tool stops if a value is missing.
4. Run the database migrations: `npx wrangler d1 migrations apply DB --remote --cwd build`.
5. Deploy: `npx wrangler deploy --cwd build`.
6. Delete `build/`. The StudentConsulting account and the other settings are then saved under **System** in the dashboard.

**Option 2: Workers Builds with the GitHub connection.** Add the values as *build variables* in Cloudflare (Workers → your Worker → Settings → Build), set the build command to `node tools/render.mjs - build` and the deploy command to `npx wrangler deploy --cwd build`. Build only the production branch. Workers Builds does not run the migrations; see [Operations](operations.md).

## Running with Docker

Jobb is available as a ready-made image on Docker Hub, `docker.io/driftaegis/jobb`. You do not need to build anything: `docker-compose.yml` names the image like this, and `docker compose up -d` pulls it.

In `docker-compose.yml`:

```yaml
    image: docker.io/driftaegis/jobb:1
```

The tag `1` gives every update within version 1; `X.Y` gives only fixes and `X.Y.Z` exactly one version. Every setting is described on the [Docker](docker.md) page, and the changes are listed in [CHANGELOG.md](../../CHANGELOG.md). To build the image yourself from source: `docker build -t jobb .` in the repo root.

## Contributing

CodeRabbit inherits shared settings from `pissmyran/coderabbit`. `.coderabbit.yaml` adds review guidance for jobb, including historical imports, monthly exports, dashboard state and English documentation mirrors.

Questions and ideas go to [Discussions](https://github.com/pissmyran/.github/discussions), bugs and suggestions as issues here. Read [CONTRIBUTING.md](https://github.com/pissmyran/.github/blob/main/CONTRIBUTING.md) before opening a pull request. Report security problems privately through the Security tab.

## License

MIT, see [LICENSE](../../LICENSE).
