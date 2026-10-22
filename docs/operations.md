# Drift

## Kontroller före push

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## Lokal utveckling

1. Kopiera `.dev.vars.example` till `.dev.vars` och fyll i värdena.
2. Kör `pnpm dev`. Den startar Wrangler med `wrangler.jsonc` i repots rot.

## Driftsättning

Produktionen driftsätts från en renderad kopia med dina egna värden, antingen från din dator eller med Workers Builds när en PR mergas till `main`; se `README.md`. CI på GitHub kör tester, Docker-bygge och CodeQL. Det finns ingen förhandsmiljö.

## Migreringar

Workers Builds kör inte D1-migreringarna, så de körs för hand från en renderad kopia:

```bash
node tools/render.mjs <din-fil.env> build
npx wrangler d1 migrations apply DB --remote --cwd build
```

- **En migrering som lägger till** tabeller eller kolumner körs före deployen av den nya Workern.
- **En migrering som tar bort** tabeller eller kolumner körs efter att den nya Workern är ute.

## Kontrollista efter driftsättning

1. **Inloggning:** öppna översikten i ett privat fönster och logga in via Cloudflare Access.
2. **Beredskap:** `GET /api/ready` ska svara `200` med `database`, `dashboardAuth` och `runtimeConfiguration` satta till `true`.
3. **Bindningar:** Workern ska ha D1 `DB`, R2 `EVIDENCE`, Browser Rendering `BROWSER`, Email `EMAIL`, Workflow `jobb-automation` och Secrets Store `JOBB_CONFIG_KEY`.
4. **StudentConsulting:** kontrollera under **Körningar** att den senaste körningen loggade in och nådde *Matcha jobb*. Ett sparat lösenord räcker inte som bevis på att kontot fungerar.

## D1

- Databasen ska vara skapad med `jurisdiction=eu`. Det går inte att ändra efteråt, så ett byte görs som export och import till en ny EU-databas innan bindningen byts.
- Läsrepliker ska vara avstängda så länge koden inte använder D1 Sessions API.

## Före en manuell omkörning

1. Månadens körning `scheduled:ÅÅÅÅ-MM` och dess status.
2. Månadens platser i månadsgränsen.
3. Ansökningar som är `uncertain`.
4. Senaste fel och bevis från StudentConsulting.
5. Att en ny körning inte kan gå över tio.

## Stoppa och radera körningar

En körning som står som `running` kan stoppas i körningens detaljer. Workflow-instansen avslutas först, och körningen sparas som `failed` med `RUN_STOPPED_BY_USER`. En avslutad körning kan raderas bara om den saknar ansökningar; då raderas också dess Workflow-instans, utskick och integrationskontroller. Körningar med ansökningar sparas alltid.

## Övergivna körningar

En körning räknas som övergiven när D1 visar `running`, ingen Workflow-instans är kopplad, inga ansökningar finns och `updated_at` är äldre än fem minuter. Den visas som övergiven i översikten och sätts till `failed` innan nästa start.

Vid en incident, kontrollera i den här ordningen:

1. Workflow-instansens status och fel i Cloudflare.
2. `automation_runs.status`, `workflow_instance_id`, `last_error` och `updated_at` i D1.
3. Om körningen har ansökningar, försök eller kan ha skickat något till StudentConsulting.
4. Platserna i månadsgränsen och eventuella `uncertain` innan ett nytt försök.

En körning som kan ha skickat något till StudentConsulting får aldrig behandlas som övergiven bara för att Workflow-kopplingen saknas.

## Fel hos StudentConsulting

- Låt körningens state i D1 stå kvar.
- Markera en oklar ansökan som `uncertain`.
- Försök inte igen blint om StudentConsulting kan ha tagit emot ansökan.
- Kontrollera bevis och StudentConsultings egen historik innan något skickas igen.

## Inloggningsfel

1. Kontrollera Access-applikationen för domänen och dess policy i Zero Trust.
2. Kontrollera att `CF_ACCESS_AUD` är applikationens AUD-tagg och `CF_ACCESS_TEAM_DOMAIN` är `<team>.cloudflareaccess.com`.
3. Kontrollera att `/api/ready` visar `dashboardAuth: true`.

Lägg aldrig till Basic Auth eller en annan inloggningsväg som reserv.
