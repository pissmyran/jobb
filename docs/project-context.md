# Jobb project context

Det här dokumentet är den app-specifika, versionsstyrda tekniska kontexten för det tidigare monorepot / `apps/jobb`.

**Senast verifierad mot repositoryt:** 2026-10-02

## Auktoritet och läsordning

Vid konflikt för repo-specifik teknik gäller följande ordning:

1. Filer på aktuell `main` i det tidigare monorepot, under `apps/jobb`.
2. Versionerade D1-migrationer och runtimekonfiguration i repositoryt.
3. Publika upstream-kontrakt för de externa API:er och tjänster implementationen använder.
4. Det här dokumentet.
5. Äldre pull requests, issues och historik.

`docs/organization/` innehåller delad kontext för det tidigare monorepot. Jobbs app-local current-state ägs av `apps/jobb`, medan Cloudflare-live-state verifieras hos respektive provider. Historik hör hemma i Git.

## Syfte och säkerhetsgräns

Jobb söker jobb automatiskt på StudentConsulting och samlar månadens ansökningar i en `.txt` med jobb-ID, jobbtyp, stad och omfattning. Arbetsförmedlingen har inget API för aktivitetsrapporten, så Jobb rapporterar inte dit.

Systemets hårda mål är **10 verifierade lämpliga ansökningar per kalendermånad**. Det är ett tak i automationsflödet, inte bara en dashboard-mätare.

Viktiga säkerhetsgränser:

- StudentConsulting-autosubmit är fail-closed och kräver `STUDENTCONSULTING_AUTOSUBMIT=true`. OIDC-flödet returnerar till den verifierade profilentryn `https://www.studentconsulting.com/sv/profil/`; discovery och verifiering återbesöker samma entry i stället för publika `/sv/`. Om `/signin` återanvänder en redan autentiserad Browser Run-session och landar direkt i profilområdet utan synliga login-kontroller accepteras sessionen utan ny credential-read eller formulärsubmit; auth godtas bara på exakt StudentConsulting-origin under `/sv/profil/`. Jobbmatchningsnavigation identifieras semantiskt via etablerade **Matcha jobb**-varianter samt explicita former av `Jobbmatchning(ar)` och `Matchning(ar) mot jobb`; orelaterade publika etiketter accepteras inte. En semantisk matchningsanchor måste ge exakt en betrodd route under `/sv/profil/...` eller äldre observerade `/sv/min-profil/...`. Ett benign root-placeholder i `href` får kombineras med exakt en betrodd `data-href` eller `data-url`. Saknas sådan data-route får exakt en synlig semantisk placeholder-anchor klickas. Om URL:en ligger kvar på profilentryn reskannas navigationen en gång efter en nytillkommen betrodd semantisk route/kontroll, utan rekursivt omklick av samma placeholder. Resultat-routen måste validera till det betrodda profilområdet. Externa, credential-bärande, utanför-profil-redirects eller ambivalenta alternativ failar stängt. Om sådan ankarlänk saknas får en enda entydig synlig button/role-link/data-navigation-kontroll aktiveras, men destinations-URL:en måste efter klick passera samma origin-/profilvalidering. Saknad/otillåten/ambivalent matchningsnavigation stoppar körningen och ingen hårdkodad profilfallback används. Vid saknad träff får diagnostik endast exponera högst 20 same-origin `/sv/profil/...`- eller äldre `/sv/min-profil/...`-paths samt strukturräknare för totala/synliga anchors och kontroller, semantiska matchningar och `data-href`/`data-url`/`onclick`; aldrig etiketter, profiltext, queryvärden, attributpayloads eller inputvärden. Synliga login-kontroller kontrolleras efter auth, profilöppning och varje listing-navigation. Okänd vald matched-page-struktur rapporterar endast sanerade elementräknare. Land enrichas från StudentConsultings publika jobb-API med explicita landsfilter för Sverige/Norge/Danmark när detaljsidan saknar `Land`; olöst eller ambivalent land stoppar kandidaten före autosubmit.
- En ansökan räknas inte som verifierad förrän exakt StudentConsulting Jobb-ID bevisas i autentiserat state. Först läses StudentConsultings same-origin job-openings API inne i Browser Run och exakt raden måste ha `is_applied=true`; annars används den autentiserade `Ansökningar`-vyn och exakt Jobb-ID måste finnas som text eller i en betrodd StudentConsulting job-detail-URL. `Ansökningar`-navigation använder exakt origin/profilområde och failar stängt vid extern, credential-bärande eller ambivalent navigation; reconciliation skickar aldrig om en uncertain ansökan.
- D1 har exakt tio interna quota-reservationer per månad. Ett definitivt pre-submit-fel får släppa sin reservation och kan återköas atomiskt endast av samma automation run när application-raden fortfarande är `failed` med `applied_at IS NULL` och `verified_at IS NULL`; nästa försök får högre `attempt_no` och application-historiken flyttas inte mellan runs. `queued`, `applying`, `submitted`, `verified`, `needs_user_action` eller någon rad som kan ha skickats återköas inte. Ett osäkert submit-resultat behåller reservationen som `uncertain`; systemet kompenserar inte med en potentiell elfte ansökan. Dashboardens tio synliga månadsplatser är däremot mål-/resultatplatser och fylls endast av `verified` ansökningar; `needs_user_action` visas separat som en säkerhetsspärr och räknas inte som godkänd ansökan.
- Credentials, Browser Run-sessioner och hemligheter ska inte exponeras i publika dokument, dashboarddata eller loggar.

## Runtime-arkitektur

Primär runtime är Cloudflare Worker `jobb` med entrypoint `apps/web/src/index.ts`.

Appens `apps/jobb/wrangler.jsonc` är deployment-konfigurationen och binder:

- Browser Run som `BROWSER`.
- D1-databasen (`D1_DATABASE_NAME`) som `DB`.
- R2-bucketen `jobb-evidence` som `EVIDENCE`.
- Cloudflare Email som `EMAIL`.
- Workflow `jobb-automation`, klass `JobAutomationWorkflow`, som `JOB_AUTOMATION`.
- Cron `0 9 10-13 * *`.
- Custom domain `<din-host>`.

Workspace använder pnpm 10.17.1. Root-skripten kör repoövergripande typecheck/test och produktionens deploykommando applicerar D1-migrationer före Wrangler deploy.

## Körningsmodell

### Manuell körning

Den skyddade dashboarden kan starta samma pipeline manuellt under den 1:a–14:e varje månad i `Europe/Stockholm`.

Manuell start kräver:

1. Cloudflare Access-dashboardautentisering,
2. exakt same-origin mutation guard,
3. konfigurerat StudentConsulting-konto med autosubmit aktiverat,
4. öppet applikationsfönster.

Starten gör därefter en atomisk D1-claim: högst en `running` automation får finnas åt gången över manuella och schemalagda starter. Run-raden skapas eller, för en failed schemalagd retry, återställs till ett rent `running`-state innan Workflow startas. Workflow-ID länkas både direkt efter create och som första Workflow-step. Startfel och Workflow-undantag skrivs tillbaka som `failed`; gamla `running`-rader utan Workflow-länk eller ansökningsaktivitet klassas/reconcileras som orphaned efter fem minuter.

### Automatisk säkerhetskörning

Cron kör en gång per dag den **10:e–13:e** vid `09:00 UTC`.

- Den 10:e är normal autonom körning.
- Den 11:e–13:e används endast som retry när månadens stabila `scheduled:YYYY-MM` fortfarande är `failed`.
- `completed` eller `running` startas inte om.
- Ingen autonom jobbsökning körs den 14:e eller den 15:e–månadens slut.

## Data och state

Produktionsbindingen `DB` ska peka på en D1-databas som skapats med Cloudflare-jurisdiction `eu`. Jurisdiction är creation-time providerkonfiguration och ska verifieras i Cloudflare när databasen ersätts; repositoryts UUID/name-binding är inte i sig bevis på data locality.

D1-migrationerna är canonical schemahistorik:

- `0001_initial.sql` — jobb, ansökningar, attempts och evidence (samt `reports`, borttagen i 0009).
- `0002_automation.sql` — automation runs och notifieringshistorik.
- `0003_integration_probes.sql` — sanitiserade metadata för autentiserade integrationsprobes.
- `0004_monthly_application_quota.sql` — exakt tio quota-slots per månad.
- `0005_activity_report_submission.sql` — state för AF-rapportaktiviteter (borttagen i 0009).
- `0006_runtime_configuration.sql` — krypterad dashboard-hanterad runtimekonfiguration.
- `0007_monthly_activity_exports.sql` — månadsfilen (.txt) med dagen då den blev klar.
- `0008_runtime_configuration_access_identity.sql` — Access-identitet för konfigurationsändringar.
- `0009_drop_af_reporting.sql` — tar bort AF-rapporteringens tabeller och bygger om `notifications` för e-postutskick av månadsfilen.

Centrala stateflöden:

- application: `queued → applying → submitted → verified`, med `failed` och `needs_user_action` som explicita avvikelser.
- application attempt: `started → submitted|verified|failed|unknown`.
- quota slot: `free → reserved → submitted|verified|uncertain`.
- automation run: atomisk claim till `running → completed|failed`; en failed schemalagd retry nollställer tidigare completion/error/workflow-fält innan nytt Workflow startas. Dashboarden visar äldre oanslutna `running`-rader som `orphaned` i stället för som verkligt aktiva.

## Evidens

Verifierad StudentConsulting-evidens skrivs som JSON till privata R2-bucketen `jobb-evidence`. D1-tabellen `evidence` lagrar metadata och R2 object key.

Schemafältet `evidence.sha256` finns men fylls **inte** av nuvarande lagringsväg. Det ska därför inte beskrivas som ett aktivt integritetsskydd förrän hashing faktiskt implementerats och verifierats.

Dashboarden visar evidence-metadata men är inte en generell R2 object-browser.

## StudentConsulting

StudentConsulting-integrationen använder Browser Run för autentisering, discovery, formulärkontroll, submission och verifiering. Discovery läser navigationsvärden från `href`, `data-href`, `data-url` och inline `onclick` på den verifierade Matcha-jobb-vyn. Absoluta URL:er behåller sin ursprungliga authority vid validering; endast betrodda StudentConsulting-rutter av formen `/sv/lediga-jobb/.../<Jobb-ID>` får bli kandidater.

Autonom submission kräver:

- runtime credentials,
- `STUDENTCONSULTING_AUTOSUBMIT=true`,
- att kandidaten kommer från den autentiserade **Matcha jobb**-vyn,
- att jobbkandidaten passerar eventuella extra include/exclude/location/country-filter,
- ett säkert och entydigt formulärläge,
- en quota-slot innan submit-side effect.

Ett definitivt misslyckande kan frigöra en reserverad slot. Ett osäkert resultat behåller sloten för att förhindra dubbel/elfte ansökan.

## Månadsfil och e-post

När månaden har tio verifierade ansökningar sparas en `.txt` i D1 (`activity_report_exports`). Varje jobb får fyra rader: **Jobb-ID**, **Jobbtyp** (specifikt yrke, eller yrkesordet i rubriken när StudentConsulting bara anger en kategori som "Logistik / Transport"), **Stad** och **Omfattning** (från annonsen, annars heltid/deltid/extrajobb i rubriken). Filen heter `jobbansokningar_ÅÅÅÅ-MM-DD.txt` efter dagen då den tionde ansökan verifierades. Filer i det äldre formatet byggs om en gång vid första nedladdning eller utskick.

En ny fil mejlas automatiskt till `NOTIFY_EMAIL_TO` (en eller flera adresser). `NOTIFY_EMAIL_MODE=group` skickar ett gemensamt mail, `separate` ett mail per mottagare. Filen bifogas och står även i brödtexten. Varje utskick loggas i `notifications`; ett misslyckat utskick fäller aldrig körningen.

Historiska luckor får repareras read-only från StudentConsultings autentiserade `Ansökningar`-historik. Endast poster som StudentConsulting själv returnerar för den uttryckligen valda månaden får backfillas; reparationsflödet får aldrig skicka eller bakdatera en ny ansökan.

## Dashboard och API

Dashboarden på `/` är operativt kontrollplan. Den skyddas av Cloudflare Access och kräver komplett konfiguration för `CF_ACCESS_TEAM_DOMAIN` och `CF_ACCESS_AUD`; ofullständig konfiguration failar stängt.

Dashboarden erbjuder `legacy`, `forest` (med etiketten från `SITE_FAMILY`) och `blackout` med Legacy som fallback. Legacy bygger på Portalens faktiska pre-v2 portalen-uttryck med cyan/blå/magenta glow och diskret rutnät; de cyan/gröna operativa accenterna förblir Jobb-specifika. Dashboarden persisterar samma presentationspreferens som övriga monorepoappar; cookien är aldrig auth-, CSRF- eller sessionsstate.

Top-level-vyer:

- **Översikt** — månadsmål, blockers, månadsfilerna med knapparna **Ladda ner .txt** och **Skicka med e-post**, och tio synliga resultatplatser som endast fylls av verifierade ansökningar; osäkra interna reservationer visas separat.
- **Ansökningar** — filtrerbar ansökningshistorik, fel, run-koppling och evidence-count. På mobil visas kort i stället för den breda tabellen. `needs_user_action` kan kontrolleras mot StudentConsulting igen eller uttryckligen markeras som ej inskickad.
- **Körningar** — run history och read-only drill-down till applications, attempts, evidence, notifications och probe-state. På mobil visas både körningar och attempts som kort i stället för breda tabeller.
- **Månadsfiler** — alla månadsfiler och en månadskalender där dagar med verifierade jobbsökningar och dagen då filen blev klar markeras. Klick på den dagen visar nedladdnings- och e-postknapparna.
- **System** — konfigurationsstatus, skyddad konfigurationseditor (inklusive mottagare och utskicksläge för månadsfilen) och utskickshistorik. Skrivkänsliga hemligheter visas aldrig igen efter sparning.

Primära endpoints:

- `GET /login` — leder till `/` (inloggning sker i Cloudflare Access framför Workern).
- `POST /auth/logout` — skickar vidare till `/cdn-cgi/access/logout`; kräver autentiserad same-origin request.
- `GET /api/health` — minimal liveness.
- `GET /api/ready` — minimal readiness; läser `SELECT 1` från D1 och verifierar att dashboard-auth är faktiskt användbar. Access-konfigurationen kontrolleras och Secrets Store-bindingen `JOBB_CONFIG_KEY` läses, men inga credential-värden returneras och inga externa provideranrop görs.
- `GET /api/dashboard` — canonical dashboard read model utan hemliga credential-värden.
- `POST /api/configuration` — same-origin, autentiserad write av dashboard-hanterad krypterad runtimekonfiguration.
- `POST /api/applications/:id/recheck` — same-origin, autentiserad provider-omkontroll av en `needs_user_action`-ansökan; kan bara verifiera när StudentConsulting bekräftar exakt Jobb-ID.
- `POST /api/applications/:id/not-submitted` — same-origin, autentiserad explicit användarbekräftelse att en osäker ansökan inte skickades; frisläpper den interna säkerhetsreservationen men ger aldrig verifieringscredit.
- `GET /api/runs/:id` — read-only run-detail.
- `POST /api/runs/manual` — manuell Workflow-start.
- `POST /api/runs/:id/stop` — terminerar en aktiv Workflow-instans och finaliserar runnen som manuellt stoppad.
- `DELETE /api/runs/:id` — raderar terminal run utan ansökningshistorik samt run-bundna probes/notifications och Workflow-state.
- `GET /api/reports/:month/export.txt` — månadsfilen som `jobbansokningar_ÅÅÅÅ-MM-DD.txt`.
- `POST /api/reports/:month/email` — same-origin, autentiserat utskick av månadsfilen till de konfigurerade mottagarna.

Alla skyddade mutationer kräver exakt same-origin `Origin`; inkompatibel `Sec-Fetch-Site` avvisas också när headern finns. Detta är ett extra CSRF-skydd ovanpå dashboard-auth. Manuell run, stop och delete kräver samma Access-auth och same-origin-skydd.

Dashboard-CSP tillåter endast egna scripts/styles/connect-källor; `unsafe-inline` används inte och ingen extern Turnstile-scriptkälla behövs.

Browser-felsidor använder separat same-origin CSS på `/assets/auth.css`, strikt CSP utan inline-script och en gemensam felvy med sanitiserad felkod och korrelations-ID.

## Runtime configuration

Hemliga värden får aldrig committas. Produktionsvärden kan komma från Cloudflare/runtime eller, för de fält som dashboarden hanterar, från den krypterade D1-raden `runtime_configuration`. Deployment-värden har alltid företräde framför dashboard-värden.

Credential-/security-namn:

- `JOBB_CONFIG_KEY` — nyckel för den krypterade runtime-konfigurationen; produktion läser värdet via Cloudflare Secrets Store-binding medan lokal utveckling kan använda en vanlig runtime-sträng
- `JOBB_CONFIG_KEY_PREVIOUS` — endast under nyckelbyte; föregående nyckel så att befintlig ciphertext kan krypteras om
- `STUDENTCONSULTING_EMAIL`
- `STUDENTCONSULTING_PASSWORD`

Icke-hemliga eller policyrelaterade runtime-värden:

- `CF_ACCESS_TEAM_DOMAIN` — Cloudflare Access team domain (`<team>.cloudflareaccess.com`)
- `CF_ACCESS_AUD` — Application Audience-tagg för Access-appen för `<din-host>`
- `STUDENTCONSULTING_AUTOSUBMIT`
- `JOB_INCLUDE_TERMS` — valfritt extra positivt filter ovanpå **Matcha jobb**
- `JOB_EXCLUDE_TERMS`
- `JOB_ALLOWED_LOCATIONS`
- `JOB_ALLOWED_COUNTRIES`
- `NOTIFY_EMAIL_TO` — en eller flera mottagare av månadsfilen
- `NOTIFY_EMAIL_FROM`
- `NOTIFY_EMAIL_MODE` — `group` eller `separate`
- `PUBLIC_BASE_URL`

Utskick använder Email-bindingen `EMAIL`.

Den autentiserade System-vyn kan spara StudentConsulting-konto, autosubmit, valfria extra lämplighetsfilter och e-postutskick av månadsfilen. Manuell körning skyddas av Cloudflare Access och exact same-origin mutation guard; Jobb bäddar inte in eller kräver Turnstile. Det dashboard-hanterade dokumentet krypteras med AES-GCM innan D1-write; krypteringsnyckeln härleds med separat HKDF-context från `JOBB_CONFIG_KEY`. StudentConsulting-lösenordet returneras aldrig efter sparning. Vid nyckelbyte binds den gamla nyckeln som `JOBB_CONFIG_KEY_PREVIOUS`; första läsningen krypterar om raden med den nya nyckeln, så inget behöver matas in igen.

## Auth, request-säkerhet och privacy

Cloudflare Access är Jobbs identity authority. Access sköter inloggning och policy framför `<din-host>`; Workern verifierar på varje request att `Cf-Access-Jwt-Assertion` är en RS256-signerad JWT från teamets certs med rätt issuer, audience (`CF_ACCESS_AUD`) och giltighetstid. Jobb har ingen egen session, cookie eller login-provider.

Access är fail-closed och enda dashboard-authvägen: saknad eller halvkonfigurerad `CF_ACCESS_TEAM_DOMAIN`/`CF_ACCESS_AUD` ger fel i auth/readiness, och en request utan giltig assertion avvisas även om Access skulle ha förbigåtts. Legacy Basic Auth accepteras inte av koden.

Manuell körning kräver en verifierad Cloudflare Access-identitet och exact same-origin mutation guard. Körningsdetaljer erbjuder stop för aktiva Workflow-instanser och delete för terminala testkörningar utan ansökningshistorik; körningar med ansökningshistorik kan inte raderas via dashboarden.

Dashboardens mutationsendpoints har same-origin-kontroll. UI-responsen sätter CSP, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `frame-ancestors 'none'` och `Cache-Control: no-store`.

Wrangler sätter `observability.redact_query_string=true`. Det är ett krav eftersom OAuth-callbacken bär kortlivade `code`/`state` i query-strängen och de inte ska persisteras i Worker-logs/traces.

## Verifiering och deployment

Appens versionerade verifieringsväg är:

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

`apps/jobb/package.json` definierar produktionskommandot:

```bash
pnpm deploy:cloudflare
```

Kommandot applicerar remote D1-migrationer och deployar därefter Workern med `apps/jobb/wrangler.jsonc`.

Vilket externt CI/CD-system som eventuellt kör kommandona är inte app-local current-state och dokumenteras inte här.

## Ändringskontrakt

Uppdatera detta dokument när någon av följande ändras:

- körningsfönster, cron eller månadsquota,
- provider- eller exportflöde,
- D1/R2 state eller migrations,
- dashboard/API-surface,
- auth, same-origin-regler eller CSP,
- Cloudflare bindings/resources/deploymentmodell,
- repositoryts test-/deployscripts och versionerade runtimekonfiguration,
- evidensmodell eller integrity semantics,
- observability/privacy-state som påverkar vad som kan hamna i loggar.

Materiella ändringar i security boundary, permissions eller deploymentarkitektur ska förankras innan implementation. Extern governance/live-state verifieras i sitt auktoritativa system och ska inte dupliceras som permanent repo-current-state.
