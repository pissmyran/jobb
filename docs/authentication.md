# Authentication and credentials

## Dashboard / Cloudflare Access

Dashboarden skyddas av Cloudflare Access (team `<team>.cloudflareaccess.com`). Access står framför `<din-host>` och sköter inloggning och policy; Workern har ingen egen login-provider, session eller cookie.

Workern verifierar ändå varje request: `Cf-Access-Jwt-Assertion` måste vara en RS256-signerad JWT från teamets `/cdn-cgi/access/certs` med rätt `iss`, `aud` (= `CF_ACCESS_AUD`), giltig `exp`/`nbf` och en e-postadress. Saknad eller ogiltig assertion ger 401/403, så en request som går förbi Access släpps aldrig in. `POST /auth/logout` skickar vidare till `/cdn-cgi/access/logout`; `/login` leder till `/` för gamla bokmärken.

Runtimekontrakt:

- `CF_ACCESS_TEAM_DOMAIN` — icke-hemligt, `<team>.cloudflareaccess.com`.
- `CF_ACCESS_AUD` — icke-hemlig Application Audience-tagg för Access-appen för `<din-host>`.

Vem som får logga in styrs av Access-policyn i Zero Trust-dashboarden, inte av Worker-konfiguration. Basic Auth och parallella login-vägar ska inte införas.

## StudentConsulting

StudentConsulting credentials are runtime secrets, never repository configuration.

Runtime names:

- `STUDENTCONSULTING_EMAIL`
- `STUDENTCONSULTING_PASSWORD`

Production supports two sources. Explicit Cloudflare runtime values are authoritative. When those values are absent, an authenticated user may save the credentials in System; the managed configuration is AES-GCM encrypted before it is persisted in D1. Local development may use `.dev.vars`, which must remain gitignored.

The application code receives effective credentials through an adapter-level `CredentialsProvider`. Plaintext credentials must never be logged, written to R2/evidence, returned through API responses, or included in screenshots. The only permitted D1 persistence is the encrypted `runtime_configuration` ciphertext; its key is HKDF-derived from the Secrets Store secret `JOBB_CONFIG_KEY` with a separate context.

Key rotation keeps the stored data: bind the new secret as `JOBB_CONFIG_KEY` and the old one as `JOBB_CONFIG_KEY_PREVIOUS`. The first read that only the previous key can decrypt re-encrypts the row under the current key (without changing `updated_at`/`updated_by`); after that the previous binding can be removed. The configuration row that was encrypted with the former GitHub OAuth client secret could not be migrated because that secret was deleted; it is reported as unreadable and is replaced on the next save in System. External CI/CD credentials are not part of the application auth contract.

## Public-repository rule

Only secret *names*, interfaces, examples with dummy values, and setup instructions belong in Git. Real credentials never do.
