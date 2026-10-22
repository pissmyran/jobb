# Arkitektur

## Runtime

Workern `jobb` startar i `apps/web/src/index.ts` och konfigureras i `wrangler.jsonc` i repots rot. Den har de här bindningarna:

| Bindning | Typ | Används till |
| --- | --- | --- |
| `DB` | D1 | Allt state: körningar, ansökningar, försök, månadsgräns, månadsfiler, utskick och inställningar |
| `EVIDENCE` | R2 (`jobb-evidence`) | Bevis från verifierade ansökningar och integrationskontroller |
| `BROWSER` | Browser Rendering | Webbläsaren som pratar med StudentConsulting |
| `JOB_AUTOMATION` | Workflow (`JobAutomationWorkflow`) | Själva körningen |
| `EMAIL` | Email | Utskick av månadsfilen |
| `JOBB_CONFIG_KEY` | Secrets Store | Nyckeln som krypterar inställningarna i D1 |
| `ASSETS` | Statiska filer | Översiktens HTML, CSS och JavaScript |

Cron `0 9 10-13 * *` startar den schemalagda körningen, och Workern svarar på en egen domän.

I Docker körs samma Worker från `docker/container-entry.ts` med `docker/wrangler.template.jsonc`. Där skickas e-post med SMTP i stället för `EMAIL`, och webbläsaren är antingen Chrome i imagen eller Cloudflare Browser Rendering.

## State i D1

Migreringarna i `migrations/` är schemats historik och körs i nummerordning.

| Migrering | Innehåll |
| --- | --- |
| `0001_initial.sql` | Jobb, ansökningar, försök och bevis |
| `0002_automation.sql` | Körningar och utskickshistorik |
| `0003_integration_probes.sql` | Metadata om integrationskontroller |
| `0004_monthly_application_quota.sql` | Tio platser per månad |
| `0005_activity_report_submission.sql` | Rapportering till Arbetsförmedlingen (borttagen i 0009) |
| `0006_runtime_configuration.sql` | Krypterade inställningar |
| `0007_monthly_activity_exports.sql` | Månadsfilerna |
| `0008_runtime_configuration_access_identity.sql` | Vem som senast ändrade inställningarna |
| `0009_drop_af_reporting.sql` | Tar bort rapporteringen till Arbetsförmedlingen och bygger om `notifications` för e-postutskick |

Tillstånden:

- **Ansökan:** `queued → applying → submitted → verified`, med `failed` och `needs_user_action` som avvikelser.
- **Försök:** `started → submitted | verified | failed | unknown`.
- **Plats i månadsgränsen:** `free → reserved → submitted | verified | uncertain`.
- **Körning:** `running → completed | failed`. En körning som står som `running` utan Workflow och utan ansökningar i mer än fem minuter visas som övergiven och stängs innan nästa start.

D1-databasen ska vara skapad med `jurisdiction=eu`. Det går inte att ändra i efterhand, så ett byte görs med export och import till en ny databas.

## Inställningar

Inställningarna kommer från två ställen, och Workerns egna variabler och hemligheter går alltid före:

1. Variabler och hemligheter på Workern (eller i containerns miljö).
2. Det krypterade dokumentet i D1-tabellen `runtime_configuration`, som sparas under **System** i översikten.

Dokumentet krypteras med AES-GCM innan det sparas. Nyckeln härleds med HKDF ur `JOBB_CONFIG_KEY`. D1 innehåller bara krypterad text, IV, schemaversion och vem som ändrade; inga värden går att läsa ut som kolumner. Se [Inloggning och nycklar](authentication.md) för nyckelbyte.

## Månadsgränsen

Månadsgränsen är exakt tio platser i D1, och en plats reserveras innan något skickas till StudentConsulting. Ett osäkert resultat behåller sin plats som `uncertain` och blockerar, så att systemet aldrig kan råka skicka en elfte ansökan. Detaljerna finns i [Automation](automation.md).

## Säkerhet

- **Inloggning:** Cloudflare Access framför Workern, och Workern kontrollerar Access-JWT:n på varje anrop. I en egen installation kan `AUTH_MODE=password` användas i stället. Se [Inloggning och nycklar](authentication.md).
- **Ändringar:** alla ändrande anrop kräver exakt samma `Origin` som sidan, och `Sec-Fetch-Site` avvisas om den visar ett annat ursprung.
- **Svar:** översikten skickas med strikt CSP (bara egna skript, stilmallar och anslutningar, ingen `unsafe-inline`), `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `frame-ancestors 'none'` och `Cache-Control: no-store`.
- **Hemligheter:** lösenord, webbläsarsessioner och nycklar loggas aldrig, skickas aldrig tillbaka till webbläsaren och hamnar aldrig i R2.

## Loggning

Enligt `wrangler.jsonc`: alla loggar sparas (sampling 1, med anropsloggar), spårningar till 1 %, frågesträngar maskeras och Workers Issues är på. Koden loggar bara fel och varningar och högst ett par rader per körning.
