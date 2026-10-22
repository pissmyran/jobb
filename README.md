# jobb

**Dokumentation:** [vinedrinker.github.io/jobb](https://vinedrinker.github.io/jobb/) – start, dokumentation och Docker på en sida med sök.

Jobb är en Cloudflare-baserad applikation för jobbsökning och ansökningsautomation med D1, R2, Browser Run och Cloudflare Workflows. Systemet håller auditerbar state för körningar, ansökningar, fel och evidence.

## Operator-wizard

Provider-/credentialförutsättningar verifieras utan att exportera eller skriva secretvärden:

```bash
bash scripts/setup-provider-credentials.sh
```

Wizarden är human-only och verifierar befintlig provider-state; den skapar eller roterar inga credentials.

## Snabb verifiering

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## Dokumentation

Börja i **[dokumentationsöversikten](docs/oversikt.md)**.

- [Automation](docs/automation.md) — scheduling, quota, dashboard, månadsfil och e-post
- [Providers](docs/providers.md) — providerbeteende och integrationsgränser
- [Projektkontext](docs/project-context.md) — aktuell teknisk state
- [Arkitektur](docs/architecture.md) — runtime, state och trust boundaries
- [Authentication](docs/authentication.md) — dashboardauth/Cloudflare Access
- [Discovery](docs/discovery.md) — sök-/discoveryflöde
- [Drift](docs/operations.md) — verifiering, deployment och incidentkontroller

README är en ingång, inte en driftmanual.

## Grundinvarianter

- D1 är canonical run/application state; R2 innehåller stödjande evidence.
- osäkra eller tvetydiga providerutfall ska inte behandlas som verifierad framgång.
- användarstyrd e-legitimation/signering ska inte automatiseras.
- auth- och providercredentials får inte hamna i repository, logs eller publik dokumentation.

## Driftsätta på ett eget Cloudflare-konto

Koden innehåller inga kontouppgifter. Där ett eget värde behövs, som domän, resurs-id eller nycklar, står en platshållare (`__NAMN__`). Alla platshållare finns i `cloudflare.example.env`, med en kommentar om var värdet hämtas. Värdena hamnar bara i Cloudflare, aldrig i repot.

**Alternativ 1: deploy från din egen dator (standard).**

1. Kopiera `cloudflare.example.env` till en egen fil utanför repot och fyll i dina värden.
2. Rendera en kopia med dina värden: `node tools/render.mjs <din-fil.env> build [overlay-katalog]`. Verktyget stoppar om ett värde saknas. Filer i overlay-katalogen kopieras ovanpå, till exempel egna bilder.
3. Lägg in hemligheter en gång, antingen var för sig med `npx wrangler secret put <NAMN>` eller alla på en gång från en JSON-fil med `npx wrangler secret bulk <fil.json>`. Radera filen efteråt.
4. Kör databasmigreringarna (se `docs/`) och deploya: `npx wrangler deploy --cwd build`.
5. Radera `build/`. Cloudflare har nu värdena. Vill du ändra något fyller du i filen igen och upprepar steg 2 och 4.

**Alternativ 2: Workers Builds med GitHub-koppling.** Lägg in värdena som *build variables* i Cloudflare (Workers → din Worker → Settings → Build), sätt byggkommandot till `node tools/render.mjs - build` och deploykommandot till `npx wrangler deploy --cwd build`. Bygg bara produktionsgrenen (stäng av bygg för andra grenar), så skapas inga förhandsversioner. Hemligheter läggs in som i alternativ 1.

## Köra med Docker

Kopiera `docker-compose.yml`, fyll i värdena och kör `docker compose up -d`. Alla inställningar beskrivs i [docker/README.md](docker/README.md). Vill du inte ha värdena i compose-filen kan du lägga dem som `NAMN=värde`-rader i `import.env` i datakatalogen och starta om. Containern sparar dem i `settings.env`, som bara containern kan läsa, och raderar importfilen. Imagen byggs från repots rot med `docker build -t jobb .`.

## Bidra

Frågor och idéer tas i [Discussions](https://github.com/VineDrinker/.github/discussions), fel och förslag som issues här. Läs [CONTRIBUTING.md](https://github.com/VineDrinker/.github/blob/main/CONTRIBUTING.md) innan du öppnar en pull request. Säkerhetsproblem rapporteras privat via fliken Security.
