# Sign-in and keys

## The dashboard: Cloudflare Access

Cloudflare Access sits in front of the Worker's domain and handles sign-in. Who may sign in is decided by the Access policy in Zero Trust, not by Jobb.

The Worker still checks every request: `Cf-Access-Jwt-Assertion` must be an RS256-signed JWT from the team's `/cdn-cgi/access/certs`, with the right `iss`, `aud` (= `CF_ACCESS_AUD`), valid `exp` and `nbf` and an email address. A request that gets past Access is therefore still not let in.

- `CF_ACCESS_TEAM_DOMAIN` is the team domain, `<team>.cloudflareaccess.com`.
- `CF_ACCESS_AUD` is the Access application's *Application Audience (AUD) Tag*.

If either is missing or incomplete, every request is rejected and `/api/ready` reports an error. `POST /auth/logout` forwards to `/cdn-cgi/access/logout`, and `/login` leads to `/`.

## Password mode (self-hosted)

With `AUTH_MODE=password` the dashboard is instead protected by `ADMIN_PASSWORD` (at least 8 characters) and an HMAC-signed session cookie that lasts 30 days. Changing the password signs everyone out. The mode is meant for Docker and other self-hosted installs and is never set in production behind Access.

## The StudentConsulting account

`STUDENTCONSULTING_EMAIL` and `STUDENTCONSULTING_PASSWORD` are either set as secrets on the Worker or saved under **System**. Secrets on the Worker win. Locally they can live in `.dev.vars`, which is never committed.

The code gets the account through a `CredentialsProvider`. The password is never logged, never written to R2, never returned in API responses and never visible in screenshots. The only thing saved in D1 is the encrypted settings document.

## The key and key rotation

The settings document is encrypted with AES-GCM, with a key derived with HKDF from `JOBB_CONFIG_KEY` in Secrets Store.

To rotate the key without losing the settings:

1. Add the new key as `JOBB_CONFIG_KEY` and the old one as `JOBB_CONFIG_KEY_PREVIOUS`.
2. Open the dashboard. The first read re-encrypts the document with the new key, without changing who or when it was last changed.
3. Remove `JOBB_CONFIG_KEY_PREVIOUS`.

A document that neither key can read is reported as unreadable and replaced the next time something is saved under **System**.

## In the repo

Only the names of secrets, interfaces, examples with made-up values and instructions belong in Git. Real values never do.
