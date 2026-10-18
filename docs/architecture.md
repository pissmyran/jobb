# Arkitektur

**Senast verifierad mot repositoryt:** 2026-09-24

## Runtime

Jobb är en Cloudflare Worker-applikation med appens `wrangler.jsonc` som deploykonfiguration.

Verifierade bindings och runtimeytor:

- entrypoint `apps/web/src/index.ts`,
- D1-binding `DB`,
- R2-binding `EVIDENCE`,
- Browser Run-binding `BROWSER`,
- Workflow-binding `JOB_AUTOMATION`,
- Email-binding `EMAIL`,
- cron `0 9 10-13 * *`,
- custom domain `<din-host>`,
- Cloudflare Access team domain och Application Audience (`CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD`) som icke-hemliga Worker-vars,
- `JOBB_CONFIG_KEY` (och under nyckelbyte `JOBB_CONFIG_KEY_PREVIOUS`) via Secrets Store-binding.

## Översikt

```text
Dashboard / scheduler
        |
        v
<din-host>
Cloudflare Worker
  |      |       |        \
  |      |       |         +--> Email
  |      |       +------------> R2 evidence
  |      +--------------------> D1 canonical state
  +---------------------------> Workflow
                                  |
                                  +--> Browser Run
                                  +--> provider adapters
```

## State ownership

### D1

D1 är canonical state för:

- automation runs,
- quota,
- applications,
- application attempts,
- activity-report state,
- notifierings- och probe-metadata enligt migrationerna,
- dashboard-hanterad runtimekonfiguration som ett AES-GCM-krypterat dokument i `runtime_configuration`.

Deployment/runtime bindings remain authoritative over dashboard-managed values. The D1 row stores ciphertext, IV, schema version and updater metadata; plaintext secrets are never queryable as D1 columns.

### R2

R2 innehåller supporting evidence. Objektinnehåll är inte generell loggning och får inte exponeras som debugoutput eller publik dokumentation.

### Workflow

Cloudflare Workflows orkestrerar längre körningar. Manuell och schemalagd start ska konvergera mot samma persistenta D1-state och samma domäninvarianter.

### Browser Run

Browser Run används för browserbaserade providerflöden och autentiserade handoffs/probes. Browser-sessionen är transport-/integrationsstate, inte canonical application state.

## Quota och fail-closed

Månadsgränsen skyddas av exakt tio quota slots.

Ett osäkert providerresultat får inte behandlas som ett säkert misslyckande om det kan möjliggöra en potentiell elfte submission. `uncertain` är därför ett explicit blockerande state.

## Auth boundary

Cloudflare Access är identity authority; Jobb är det inte själv. Access sköter inloggning och policy framför `<din-host>`, och Workern verifierar den signerade Access-JWT:n på varje request. Jobb har ingen egen session eller cookie.

## Request security

Skyddade mutationer kräver en verifierad Cloudflare Access-identitet, same-origin-kontroll och `Sec-Fetch-Site` när headern finns. Manuell körning har ingen separat Turnstile-utmaning i Jobb.

## Deployment boundary

Appens deploykontrakt är versionerat i `package.json` och `wrangler.jsonc`.

Rootkommandot:

```bash
pnpm deploy:cloudflare
```

applicerar remote D1-migrationer och kör därefter Wrangler deploy med rootkonfigurationen.

Vilket externt CI/CD-system som eventuellt anropar kommandot är inte app-local current-state och dokumenteras därför inte här.

## Dokumentationsgräns

Arkitekturdokumentet beskriver kod, bindings och versionerade kontrakt i repositoryt. Extern organisationsgovernance och deployment-live-state hör hemma i respektive auktoritativa system.
