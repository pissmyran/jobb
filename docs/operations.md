# Drift och verifiering

**Senast verifierad mot repositoryt:** 2026-10-01

## Lokal verifiering

Från `apps/jobb` i monorepot:

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

Appens rootskript kör motsvarande workspacekontroller för projekten under `apps/*` och `packages/*`.

## Lokal utveckling

```bash
pnpm dev
```

Det kör `@jobb/web`-paketets Wrangler-baserade devscript.

## Deployment

Produktion driftsätts från en renderad kopia med dina egna värden, se avsnittet om Cloudflare i `README.md`: kör typecheck och tester, rendera med `tools/render.mjs`, kör remote D1-migrationerna mot den renderade `wrangler.jsonc` och deploya kopian. CI på GitHub kör tester, Docker-bygge och CodeQL vid varje push till `main`. Det finns ingen förhandsmiljö.

## D1 data locality

Produktionsbindingen `DB` ska använda en D1-databas skapad med `jurisdiction=eu`. Cloudflare tillåter inte att jurisdiction läggs till eller ändras efter att databasen skapats, så ett framtida byte ska göras som en kontrollerad export/import till en ny EU-databas före binding-cutover.

Read replication ska vara avstängd tills Jobbs D1-requestväg använder D1 Sessions API. Att aktivera repliker utan Sessions API flyttar inte querytrafik från primären.

## Readiness

`GET /api/health` är minimal liveness.

`GET /api/ready` verifierar D1, att dashboard-authkonfigurationen är användbar och att `0006_runtime_configuration.sql` både finns i schemat och är registrerad i D1:s migrationshistorik. Readiness får inte exponera credential-värden.

## Månadskörning

Kontrollera före manuell omkörning:

1. aktuell månads stable run,
2. quota slots,
3. applications med `uncertain` state,
4. senaste providerfel/evidence,
5. att en ny körning inte kan överskrida månadsgränsen.


## Stoppa och radera körningar

I den autentiserade dashboardens körningsdetaljer kan en aktiv `running`-körning stoppas. Om en Cloudflare Workflow-instance finns termineras den först och D1-raden finaliseras som `failed` med `RUN_STOPPED_BY_USER`. En terminal körning kan raderas endast när den saknar ansökningshistorik; då raderas eventuell Workflow-instance samt run-bundna notifications/probes och därefter run-raden. Körningar som har applications bevaras för spårbarhet och får inte raderas från dashboarden.

## Workflow/orphan-incident

En automation räknas som **orphaned** när D1 fortfarande visar `running`, `workflow_instance_id` saknas, ingen application är kopplad till runnen och `updated_at` är äldre än fem minuter. Dashboarden visar sådana rader som **Övergivna körningar** i stället för som aktiva.

Före varje manuell eller schemalagd start reconcilerar Workern orphaned rader till `failed`. Den atomiska run-claimen tillåter därefter högst en `running` automation åt gången. En failed `scheduled:YYYY-MM`-retry återställs till rent `running`-state innan nytt Workflow startas.

Vid incident, kontrollera i denna ordning:

1. Cloudflare Workflow-instansens status och fel,
2. D1 `automation_runs.status`, `workflow_instance_id`, `last_error`, `updated_at`,
3. om runnen har applications/attempts eller provider-side effects,
4. quota slots och eventuell `uncertain` state innan retry.

Korrigera inte en run med observerade provider-side effects som orphaned enbart för att Workflow-länken saknas. Om direkt D1-write saknar behörighet ska state återställas genom den versionerade reconciliation/startvägen efter deployment, inte genom att byta Cloudflare-identitet eller kringgå behörighetsmodellen.

## Browser/providerincident

Vid browser/providerfel:

- bevara run/application state i D1,
- klassificera oklar submission som `uncertain`,
- undvik blind retry om providern kan ha accepterat submission,
- kontrollera evidence och providerstate innan ny submission tillåts.

## Cloudflare Access

Vid loginfel verifiera:

- Access-appen för `<din-host>` och dess policy i Zero Trust-dashboarden,
- att `CF_ACCESS_AUD` är appens Application Audience-tagg och `CF_ACCESS_TEAM_DOMAIN` är `<team>.cloudflareaccess.com`,
- att `/api/ready` rapporterar `dashboardAuth: true` (Access konfigurerad och `JOBB_CONFIG_KEY` läsbar).

Lägg inte till Basic Auth eller parallell authväg som fallback.

## Evidence och privacy

R2-evidence ska vara begränsad till det som behövs för auditability.

## Observability

`apps/jobb/wrangler.jsonc` definierar:

- persistent observability,
- log sampling `1` (alla loggar; koden loggar bara fel och enstaka rader per körning),
- trace sampling `0.01`,
- `redact_query_string=true`.

OAuth callback-parametrar kan förekomma i query string; redaction ska därför behållas. Credentials, sessionsmaterial och privata providerpayloads får inte läggas i logs.

## Dokumentationsunderhåll

Uppdatera denna fil när appens test-/deployscripts, runtimebindings, migrationsordning eller incidentmodell ändras. Extern live-state ska verifieras i sitt auktoritativa system och inte kopieras in som permanent app-current-state.
