# Jobb

Jobb söker jobb åt dig på [StudentConsulting](https://www.studentconsulting.com). Varje månad skickas tio ansökningar till jobb som matchar din profil där (**Matcha jobb**), och varje ansökan kontrolleras i ditt konto. Månadens tio jobb samlas i en textfil med jobb-ID, typ av jobb, stad och omfattning. Filen kan du ladda ner eller få mejlad, till exempel som underlag för din aktivitetsrapport.

Allt körs i containern, inklusive webbläsaren som söker jobben. Du behöver inget Cloudflare-konto.

## Kom igång

1. **Installera Docker.** På Windows och Mac: [Docker Desktop](https://www.docker.com/products/docker-desktop/). På Linux: paketet `docker.io` (Debian/Ubuntu) eller motsvarande. Podman fungerar också.
2. **Skapa en mapp** och en fil i den som heter `docker-compose.yml`. Klistra in innehållet nedan.
3. **Byt** `ADMIN_PASSWORD` till ett eget lösenord på minst 8 tecken.
4. **Starta** i den mappen: `docker compose up -d`. Första gången laddas imagen ner, och den är stor eftersom webbläsaren ingår.
5. **Öppna** `http://localhost:8787` och logga in.
6. **Fyll i inställningarna.** Under **System** anger du e-post och lösenord för ditt StudentConsulting-konto och slår på **autosubmit**. Därefter söker Jobb automatiskt den 10:e varje månad, och du kan starta en körning för hand under den 1:a–14:e.

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

## Så fungerar månaden

- **Ansökningarna:** Jobb skickar exakt tio verifierade ansökningar per kalendermånad, aldrig fler. Är resultatet för en ansökan osäkert stoppas nya ansökningar tills du har kontrollerat den under **Ansökningar**.
- **Schema:** den automatiska körningen sker 09:00 UTC den 10:e. Den 11:e–13:e görs nya försök bara om körningen misslyckades. För hand kan du köra den 1:a–14:e.
- **Månadsfilen:** när tio ansökningar är verifierade skapas `jobbansokningar_ÅÅÅÅ-MM-DD.txt` (datumet är dagen då den tionde ansökan verifierades). Den finns under **Översikt** och **Månadsfiler**, och skickas med e-post om du har angett mottagare under **System**.
- **Jobbens urval:** de kommer från din profil på StudentConsulting. Under **System** kan du begränsa urvalet ytterligare med ord, orter och länder.

## Inloggning: två sätt

Välj med `AUTH_MODE`.

**`password`** (standard): en inloggningssida med lösenordet i `ADMIN_PASSWORD`. Sessionen gäller i 30 dagar. Om du byter lösenord loggas alla ut.

**`cloudflare-access`**: Cloudflare Access sköter inloggningen, och Jobb kontrollerar den signerade Access-token själv. Det kräver ett Cloudflare-konto med en domän:
1. **Skapa en tunnel.** Gå till Zero Trust → Networks → Tunnels, skapa en tunnel och peka ett publikt värdnamn mot `http://jobb:8787`. Kopiera tunnelns token till `TUNNEL_TOKEN`.
2. **Skapa en Access-applikation.** Gå till Zero Trust → Access → Applications och lägg till en *self-hosted* applikation för värdnamnet, med en policy för vilka som får logga in.
3. **Fyll i compose-filen.** Kopiera *Application Audience (AUD) Tag* till `CF_ACCESS_AUD` och teamdomänen till `CF_ACCESS_TEAM_DOMAIN`, och sätt `AUTH_MODE: "cloudflare-access"`.
4. **Starta med tunneln:** `docker compose --profile tunnel up -d`

## Webbläsaren: två sätt

Välj med `BROWSER_MODE`.

- **`bundled`** (standard): Chrome finns i imagen. Inget mer behövs. `shm_size: "1gb"` ger Chrome det delade minne den behöver.
- **`cloudflare`**: Cloudflare Browser Rendering kör webbläsaren. Imagen blir då inte mindre, men datorn som kör containern slipper köra Chrome. Fyll i `CLOUDFLARE_API_TOKEN` (behörighet *Browser Rendering: Edit*) och `CLOUDFLARE_ACCOUNT_ID`. Browser Rendering debiteras per webbläsartimme utöver Cloudflares gratisnivå.

## Inställningar

Variabler i compose-filen:

| Variabel | Krävs | Standard | Betydelse |
|---|---|---|---|
| `PUBLIC_URL` | Nej | `http://localhost:8787` | Adressen du öppnar Jobb på. Används i e-post. |
| `AUTH_MODE` | Nej | `password` | `password` eller `cloudflare-access`. |
| `ADMIN_PASSWORD` | Med `password` | – | Minst 8 tecken, gärna betydligt längre. |
| `CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD` | Med `cloudflare-access` | – | Se ovan. |
| `BROWSER_MODE` | Nej | `bundled` | `bundled` eller `cloudflare`. |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Med `cloudflare` | – | Se ovan. |
| `SMTP_HOST` | För e-post | – | Utgående e-postserver, t.ex. din e-postleverantörs SMTP. |
| `SMTP_PORT` | Nej | `587` | `587` (STARTTLS) eller `465` (TLS). |
| `SMTP_USER`, `SMTP_PASSWORD` | För e-post | – | Inloggning till SMTP-servern. Många leverantörer kräver ett appspecifikt lösenord. |
| `JOBB_CONFIG_KEY` | Nej | skapas automatiskt | Nyckel som krypterar inställningarna i databasen. Skapas första gången och sparas i `/data/config-key`. |
| `PORT` | Nej | `8787` | Porten inne i containern. |

Inställningar som görs under **System** i webbläsaren, och sparas krypterat:
- StudentConsulting-konto och autosubmit.
- Extra filter: ord som ska finnas med, ord som inte får finnas med, orter och länder.
- E-postutskick av månadsfilen: avsändare, en eller flera mottagare, och om det ska vara ett gemensamt mail eller ett per mottagare.

Värden som du sätter som miljövariabler (`STUDENTCONSULTING_EMAIL`, `STUDENTCONSULTING_PASSWORD`, `STUDENTCONSULTING_AUTOSUBMIT`, `NOTIFY_EMAIL_TO`, `NOTIFY_EMAIL_FROM`, `NOTIFY_EMAIL_MODE`) går före det som sparas i System.

### Inställningar från en fil i stället

Vill du inte ha värden som lösenord i compose-filen lägger du dem som `NAMN=värde`-rader i filen `import.env` i datavolymen (den som monteras på `/data`) och startar om containern. Vid starten sparas värdena i `/data/settings.env`, som bara containern kan läsa, och `import.env` raderas. För att ändra ett värde senare lägger du en ny `import.env` med bara den raden. En rad med `NAMN=` och inget värde tar bort inställningen. Värden som är ifyllda i compose-filen gäller före sparade värden.

## Data, säkerhetskopiering och uppdatering

- Allt ligger i volymen som är monterad på `/data`: databasen (SQLite), bevisen för varje ansökan, Workflow-tillståndet och krypteringsnyckeln.
- **Säkerhetskopiera:** `docker compose stop`, kopiera volymen och kör `docker compose start`. Följ med `/data/config-key`, annars går de sparade inställningarna inte att läsa.
- **Uppdatera:** `docker compose pull && docker compose up -d`. Databasmigreringar körs automatiskt vid start.
- **Versioner:** taggarna följer semver. `1` ger alla uppdateringar inom version 1, `1.0` bara rättningar och `1.0.0` exakt en version.

## Teknisk översikt

- **Runtime:** Jobb är skrivet som en Cloudflare Worker med ett Cloudflare Workflow. I containern körs båda i `workerd`, samma runtime som Cloudflare använder, via `wrangler dev --local` (Miniflare). D1, R2 och Workflow-tillståndet blir lokala filer under `/data`.
- **Schemaläggning:** `wrangler dev` startar inte cron-körningar av sig själv. Därför anropar `docker/scheduler.mjs` workerns schemalagda körning 09:00 UTC varje dag, och workern agerar bara den 10:e–13:e.
- **Webbläsare:** Browser Rendering-bindningen körs mot Chrome for Testing, i exakt den version som wrangler använder. Chrome är förinstallerad i `XDG_CACHE_HOME`, och dess bibliotek kommer från Debians apt. Den startas med `--no-sandbox` (`CI=true`) eftersom containern inte har användarnamnrymder. Med `BROWSER_MODE=cloudflare` blir bindningen en fjärrbindning (`remote: true`) mot ditt konto.
- **E-post:** Cloudflare Email Service finns inte utanför Cloudflare, så `docker/container-entry.ts` ger workern samma `EMAIL`-gränssnitt via SMTP över `cloudflare:sockets`. Den skickar en multipart-mejl med `.txt`-filen som bilaga, med STARTTLS eller TLS och AUTH LOGIN.
- **Säkerhet:**
  - Lösenordssessionen är en signerad cookie (HMAC-SHA256, `HttpOnly`, `SameSite=Strict`). Access-läget kontrollerar RS256-signatur, utfärdare och AUD.
  - Ändrande anrop kräver same-origin.
  - Inställningarna krypteras med AES-GCM, med en nyckel som härleds från `JOBB_CONFIG_KEY` med HKDF. Lösenord visas aldrig igen efter att de har sparats.
- **Imagen** bygger på `node:24-trixie-slim` (Node LTS på Debian stable), kör som användaren `node` och har en healthcheck mot `/api/health`. Den innehåller bara källkod med platshållare; dina värden fylls i när containern startar.
- **Begränsningar:** `wrangler dev` är en utvecklingsserver som kör en process på en maskin. Det räcker för en person. StudentConsultings sidor kan ändras, och då kan sökningen sluta fungera tills imagen uppdateras. Jobb stoppar då hellre än gissar, och felet syns under **Körningar**.
- **Felsökning:** `docker compose logs -f`. Varje körning, ansökan och försök med felkod finns under **Körningar** i gränssnittet.

## Changelog

**1.1.3**
- Imagen bygger på `node:24-trixie-slim`: Node 24 (LTS) på Debian 13 (stable).
- pnpm-versionen tas från `packageManager` i `package.json`.

**1.1.2**
- `tools/render.mjs` skriver varje ifylld fil i en loop tills alla byte är skrivna, så att en kort skrivning inte kan lämna en avkortad fil.

**1.1.1**
- `tools/render.mjs` läser och skriver varje fil genom samma filbeskrivare, så att filen inte kan bytas ut mellan kontroll och skrivning.

**1.1.0**
- Inställningar kan ges en gång i `/data/import.env` i stället för i compose-filen. De sparas i `/data/settings.env` och importfilen raderas.
- Imagen byggs från projektets eget repo: `docker build -t jobb .`.

**1.0.0**
- Första Docker-imagen, med workern och dess Workflow lokalt under `/data` och den månatliga körningen startad inne i containern.
- `BROWSER_MODE`: `bundled` (Chrome i imagen) eller `cloudflare` (Cloudflare Browser Rendering).
- `AUTH_MODE`: `password` eller `cloudflare-access`, med valfri Cloudflare Tunnel.
- E-post via valfritt SMTP-konto.
- Krypteringsnyckeln skapas automatiskt första gången.
- Månadsfilen `jobbansokningar_ÅÅÅÅ-MM-DD.txt` med jobb-ID, jobbtyp, stad och omfattning. Den finns i översikten och kan mejlas till en eller flera mottagare.

## Licens

MIT.
