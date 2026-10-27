# Jobb

**Dokumentation:** [pissmyran.github.io/jobb](https://pissmyran.github.io/jobb/) – start, dokumentation och Docker på en sida med sök.

Jobb söker jobb på StudentConsulting åt dig och samlar månadens ansökningar i en textfil. Det körs som en Cloudflare Worker med D1, R2, Browser Rendering och Workflows, eller som en färdig Docker-image.

## Vad den gör

- **Söker** till passande jobb i StudentConsultings vy *Matcha jobb*, med valfria extra filter på ord, ort och land.
- **Stannar vid tio:** högst tio ansökningar per kalendermånad. En ansökan räknas först när StudentConsulting själv visar den som inskickad, och ett oklart resultat blockerar i stället för att ge plats åt en elfte.
- **Samlar månaden** i `jobbansokningar_ÅÅÅÅ-MM-DD.txt` med jobb-ID, jobbtyp, stad och omfattning. Filen kan laddas ner eller mejlas till en eller flera mottagare.
- **Körs av sig själv** den 10:e varje månad, med omförsök den 11:e–13:e, och kan startas för hand den 1:a–14:e.

Jobb rapporterar inte till Arbetsförmedlingen; det finns inget API för det.

## Tester

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## Dokumentation

Börja i [översikten](docs/oversikt.md).

- [Arkitektur](docs/architecture.md): bindningar, state och säkerhet
- [Automation](docs/automation.md): översikten, körningar, månadsgränsen, månadsfilen och inställningar
- [StudentConsulting](docs/providers.md): inloggning, sökning, ansökan och verifiering
- [Inloggning och nycklar](docs/authentication.md): Cloudflare Access, lösenordsläget och krypterade inställningar
- [Drift](docs/operations.md): driftsättning, migreringar, kontroller och felsökning

## Driftsätta på ett eget Cloudflare-konto

Koden innehåller inga kontouppgifter. Där ett eget värde behövs, som domän, resurs-id eller nycklar, står en platshållare (`__NAMN__`). Alla platshållare finns i `cloudflare.example.env`, med en kommentar om var värdet hämtas. Värdena hamnar bara i Cloudflare, aldrig i repot.

**Alternativ 1: deploy från din egen dator.**

1. Skapa resurserna: en D1-databas (`npx wrangler d1 create <namn> --jurisdiction eu`), R2-bucketen `jobb-evidence` och hemligheten `JOBB_CONFIG_KEY` i Secrets Store (en lång slumpmässig sträng).
2. Kopiera `cloudflare.example.env` till en egen fil utanför repot och fyll i dina värden.
3. Rendera en kopia med dina värden: `node tools/render.mjs <din-fil.env> build`. Verktyget stoppar om ett värde saknas.
4. Kör databasmigreringarna: `npx wrangler d1 migrations apply DB --remote --cwd build`.
5. Deploya: `npx wrangler deploy --cwd build`.
6. Radera `build/`. StudentConsulting-kontot och övriga inställningar sparas sedan under **System** i översikten.

**Alternativ 2: Workers Builds med GitHub-koppling.** Lägg in värdena som *build variables* i Cloudflare (Workers → din Worker → Settings → Build), sätt byggkommandot till `node tools/render.mjs - build` och deploykommandot till `npx wrangler deploy --cwd build`. Bygg bara produktionsgrenen. Workers Builds kör inte migreringarna; se [Drift](docs/operations.md).

## Köra med Docker

Jobb finns som färdig image på Docker Hub, `docker.io/driftaegis/jobb`. Du behöver inte bygga något själv: i `docker-compose.yml` står imagen så här, och `docker compose up -d` hämtar den.

I `docker-compose.yml`:

```yaml
    image: docker.io/driftaegis/jobb:1
```

Taggen `1` ger alla uppdateringar inom version 1; `X.Y` ger bara rättningar och `X.Y.Z` exakt en version. Alla inställningar beskrivs i [docker/README.md](docker/README.md), och ändringarna listas i [CHANGELOG.md](CHANGELOG.md). Vill du bygga imagen själv från källkoden: `docker build -t jobb .` i repots rot.

## Bidra

Frågor och idéer tas i [Discussions](https://github.com/pissmyran/.github/discussions), fel och förslag som issues här. Läs [CONTRIBUTING.md](https://github.com/pissmyran/.github/blob/main/CONTRIBUTING.md) innan du öppnar en pull request. Säkerhetsproblem rapporteras privat via fliken Security.

## Licens

MIT, se [LICENSE](LICENSE).
