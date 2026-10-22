# Automation

Manuella och schemalagda körningar använder samma pipeline och samma regler.

## Översikten

Översikten på `/` har fem vyer:

- **Översikt:** månadsmålet, tio resultatplatser som bara fylls av verifierade ansökningar, månadsfilerna med **Ladda ner .txt** och **Skicka med e-post**, och det som behöver åtgärdas. Reserverade men osäkra platser visas för sig som spärrar, inte som klara ansökningar.
- **Ansökningar:** alla ansökningar med filter, koppling till körning, senaste fel och antal bevis. En ansökan med `needs_user_action` kan kontrolleras mot StudentConsulting igen (**Kontrollera igen**) eller markeras som ej inskickad (**Markera ej inskickad**). Bara StudentConsultings egen bekräftelse kan göra en ansökan verifierad.
- **Körningar:** historiken med detaljer om ansökningar, försök, bevis, utskick och integrationskontroller. En aktiv körning kan stoppas, och en avslutad körning utan ansökningar kan raderas.
- **Månadsfiler:** alla månadsfiler och en kalender där dagar med verifierade ansökningar och dagen då filen blev klar är markerade.
- **System:** inställningarnas status, formuläret för inställningar och utskickshistoriken. Sparade hemligheter visas aldrig igen.

På mobil visas tabellerna som kort.

## Manuell körning

**Kör nu** fungerar den 1:a–14:e varje månad (`Europe/Stockholm`). Utanför det fönstret är knappen avstängd och API:t avvisar starten. En manuell start kräver inloggning, samma ursprung, ett sparat StudentConsulting-konto och att `STUDENTCONSULTING_AUTOSUBMIT` är på.

Starten tar körningen i D1 i ett enda steg, och bara om ingen annan körning står som `running`. Två flikar eller en flik och schemat kan därför aldrig starta två körningar samtidigt. Workflow-instansens id sparas direkt, och fel i Workflowen skrivs tillbaka som `failed`.

## Schemalagd körning

Cron startar Workern kl. 09:00 UTC den 10:e–13:e, det vill säga kl. 10 eller 11 svensk tid.

- **Den 10:e** görs månadens vanliga körning, `scheduled:ÅÅÅÅ-MM`.
- **Den 11:e–13:e** görs ett nytt försök bara om den körningen fortfarande är `failed`. En körning som är klar eller pågår startas inte om.
- **Den 14:e och resten av månaden** görs inga automatiska sökningar.

En körning räknar först hur många ansökningar som redan är verifierade i månaden, söker sedan bara till passande jobb, och skapar och mejlar månadsfilen när tio är verifierade.

## Månadsgränsen

`0004_monthly_application_quota.sql` skapar tio platser per månad, och en plats reserveras **innan** ansökan skickas.

- **Säkert fel innan något skickades:** platsen släpps. Samma körning får försöka igen med samma ansökan, men bara om den fortfarande är `failed` och saknar både `applied_at` och `verified_at`. Försöket får nästa nummer, och historiken stannar på körningen.
- **Inskickad:** platsen behålls.
- **Verifierad:** platsen markeras som verifierad.
- **Oklart resultat:** platsen behålls som `uncertain`. Ingen ersättare skickas, eftersom den kunde bli nummer elva.

Jobb skickar alltså aldrig medvetet fler än tio ansökningar i en kalendermånad. Ett oklart resultat syns i översikten och blockerar fler ansökningar tills det är utrett, med **Kontrollera igen** eller **Markera ej inskickad**. Det senare släpper spärren men räknas aldrig som en lyckad ansökan.

## Felkoder

Varje försök sparar en felkod och StudentConsultings meddelande:

| Kod | Betydelse |
| --- | --- |
| `APPLICATION_FAILED` | StudentConsulting avvisade ansökan, eller den misslyckades. |
| `APPLICATION_UNKNOWN` | Det gick inte att avgöra säkert om ansökan skickades. |
| `APPLICATION_REQUIRES_INPUT` | Ansökan har ett obligatoriskt fält som Jobb inte kan fylla i. Försöks igen en gång per körning. |
| `VERIFICATION_FAILED` | Ansökan rapporterades som skickad, men jobb-ID:t fanns inte bland ansökningarna. |
| `UNEXPECTED_APPLICATION_ERROR` | Webbläsaren eller koden gav ett oväntat fel. |
| `RUN_STOPPED_BY_USER` | Körningen stoppades i översikten. |

Säkra fel innan något skickades kan försökas igen i senare körningar, även om jobbet inte längre finns i *Matcha jobb*.

## Inställningar

Alla inställningar kan sättas som variabler på Workern eller sparas under **System**. Variabler på Workern går före.

| Namn | Betydelse |
| --- | --- |
| `STUDENTCONSULTING_EMAIL`, `STUDENTCONSULTING_PASSWORD` | Kontot hos StudentConsulting. |
| `STUDENTCONSULTING_AUTOSUBMIT` | `true` slår på att ansökningar skickas. Av som standard. |
| `JOB_INCLUDE_TERMS` | Valfritt: bara jobb som innehåller något av orden, t.ex. `supporttekniker,helpdesk`. |
| `JOB_EXCLUDE_TERMS` | Valfritt: hoppa över jobb som innehåller något av orden, t.ex. `chef,senior`. |
| `JOB_ALLOWED_LOCATIONS` | Valfritt: bara de här orterna, t.ex. `Stockholm,Uppsala`. |
| `JOB_ALLOWED_COUNTRIES` | Valfritt: bara de här länderna, t.ex. `SE,NO,DK`. |
| `NOTIFY_EMAIL_TO` | En eller flera mottagare av månadsfilen, kommaseparerade. |
| `NOTIFY_EMAIL_FROM` | Avsändaradressen. |
| `NOTIFY_EMAIL_MODE` | `group` (ett gemensamt mejl) eller `separate` (ett mejl per mottagare). |

`CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD` och `PUBLIC_BASE_URL` sätts vid driftsättningen. `JOBB_CONFIG_KEY` ligger i Secrets Store, och `JOBB_CONFIG_KEY_PREVIOUS` behövs bara under ett nyckelbyte.

## Månadsfilen och e-post

Så fort månaden har tio verifierade ansökningar sparas en textfil i D1-tabellen `activity_report_exports`. Varje jobb får fyra rader:

- **Jobb-ID**
- **Jobbtyp:** yrket, eller yrkesordet i rubriken när StudentConsulting bara anger en kategori som "Logistik / Transport"
- **Stad**
- **Omfattning:** från annonsen, annars heltid, deltid eller extrajobb ur rubriken

Filen heter `jobbansokningar_ÅÅÅÅ-MM-DD.txt` efter dagen då den tionde ansökan verifierades. Den hämtas från `GET /api/reports/:month/export.txt` och skickas med `POST /api/reports/:month/email`.

En ny fil mejlas automatiskt om mottagare är inställda. Filen bifogas och står även i brödtexten. Varje utskick loggas i `notifications` (`kind = export_email`), och ett misslyckat utskick fäller aldrig körningen.

## Historiska luckor

En separat väg i Workflowen kan läsa den inloggade historiken hos StudentConsulting och lägga in ansökningar som saknas för en uttryckligen vald månad. Den lägger bara in sådant som StudentConsulting själv visar och skickar aldrig någon ny ansökan. Har månaden då tio ansökningar skapas månadsfilen.

## API

| Anrop | Gör |
| --- | --- |
| `GET /api/health` | Svarar om Workern lever. |
| `GET /api/ready` | Kontrollerar D1, att inloggningen är inställd och att `JOBB_CONFIG_KEY` går att läsa. Anropar inte StudentConsulting och visar inga hemligheter. |
| `GET /api/dashboard` | Allt översikten visar, utan hemligheter. |
| `POST /api/configuration` | Sparar inställningarna krypterade. |
| `POST /api/runs/manual` | Startar en manuell körning. |
| `GET /api/runs/:id` | Detaljer om en körning. |
| `POST /api/runs/:id/stop` | Stoppar en aktiv körning. |
| `DELETE /api/runs/:id` | Raderar en avslutad körning utan ansökningar. |
| `POST /api/applications/:id/recheck` | Kontrollerar en ansökan mot StudentConsulting igen. |
| `POST /api/applications/:id/not-submitted` | Bekräftar att en osäker ansökan inte skickades. |
| `GET /api/reports/:month/export.txt` | Månadsfilen. |
| `POST /api/reports/:month/email` | Mejlar månadsfilen. |
| `POST /auth/logout` | Loggar ut via Cloudflare Access. |

Alla anrop utom `/api/health` och `/api/ready` kräver inloggning, och alla ändrande anrop kräver samma ursprung.
