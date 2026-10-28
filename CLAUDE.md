# CLAUDE.md – jobb

Vägledning för Claude Code i `pissmyran/jobb`. Tjänsten jobb: en månatlig jobbansökningshjälp på Cloudflare Workers, plus en Docker-bild för egen drift.

De gemensamma reglerna för alla repon finns i [STYRNING.md](https://github.com/pissmyran/.github/blob/main/STYRNING.md) i `pissmyran/.github`. Kärnreglerna nedan är en ordagrann kopia. Jämför versionen i markeringen med källan i början av varje session (`curl -sS https://raw.githubusercontent.com/pissmyran/.github/main/STYRNING.md`); är kopian äldre, uppdatera den först i en egen PR (`docs: sync core rules from .github`).

## Kärnregler

<!-- kärnregler:start version=2026-10-28 källa=https://github.com/pissmyran/.github/blob/main/STYRNING.md -->
1. **Inga personliga värden.** Repot är publikt. Skriv aldrig in riktiga id:n, domäner, e-postadresser, namn, nycklar, betallänkar eller kontouppgifter i kod, konfiguration, tester, dokumentation eller commit-meddelanden. Använd platshållare och `example.com`-värden.
2. **Inga hemligheter.** Tokens, lösenord, sessioner och nycklar hamnar aldrig i Git, loggar, issues eller publik dokumentation. Hemligheter läggs in utanför repot (Cloudflare, GitHub-miljöer, `wrangler secret put`).
3. **Gren och pull request.** Varje session börjar från senaste `main` (`git fetch origin main`) på en egen gren. `main` ändras bara genom en PR som squash-mergas. Ingen pushar direkt till `main`. En sessions arbete hålls i en PR.
4. **Testa lokalt före varje push.** Det finns inga testkontroller i CI. Repots egna tester och kontroller (avsnittet Kommandon i repots `CLAUDE.md`) är den enda testgrinden. Pusha aldrig med fallerande tester, och skriv tester för det du ändrar.
5. **Rör aldrig workflows.** `.github/workflows/`, `.github/actions/` och `CODEOWNERS` ändras inte av Claude, inte ens för att laga ett fel. Ingen kontroll stoppar det längre, men regeln gäller fullt ut. Behövs en ändring: beskriv den i ett issue och låt ägaren göra den. Bara Renovate och Dependabot får uppdatera dem.
6. **Granskning.** CodeRabbit granskar och CodeQL (GitHubs standardinställning) skannar. Varje granskningstråd måste lösas innan merge. Svara i tråden med vad du ändrade, eller med skälet om fyndet är brus.
7. **Auto-merge sist.** Slå på auto-merge först när CodeRabbit har granskat den senaste commiten och alla trådar är lösta. Ändrar PR:en bara filer som CodeRabbit hoppar över (`docs/`, `*.md`), räcker det att CodeQL är klar.
8. **Laga orsaken, inte symptomet.** När något fallerar eller en granskning kräver ändring: läs allt, hitta orsaken och gör om den delen rätt. Små uppenbara fel får rättas direkt. Försvaga aldrig ett test, hoppa aldrig över en kontroll och tysta aldrig en varning.
9. **Säkerhet först.** Säkerhetslarm (CodeQL, Dependabot, Renovate) går före annat arbete. Länka issuet med `Closes #n`.
10. **Senaste versionerna.** Lås aldrig verktyg, runtime eller paket till ett versionsnummer; använd `@latest`, `node`, `latest` och versionsintervall. Renovate håller allt aktuellt. Enda undantaget är actions, som låses med commit-SHA och uppdateras av Renovate.
11. **Commits och titlar.** Sessionen signerar commits själv. Ändra aldrig gits användare, e-post eller signering, och använd aldrig `--no-verify`. PR-titeln blir commiten på `main` och skrivs på engelska enligt Conventional Commits: `typ: beskrivning` eller `typ(område): beskrivning`, med typ feat, fix, docs, refactor, perf, test, build, ci, chore, style eller revert.
12. **Dokumentation i samma PR.** Ändras beteende, inställningar eller kommandon uppdateras `README.md`, `docs/` och repots `CLAUDE.md` i samma PR.
13. **Inga lösa grenar.** Radera grenen när PR:en är mergad eller stängd. PR:er från forkar är förslag: gör ändringen själv på en egen gren om den är önskad, och stäng originalet med tack och länk.
14. **Noll kronor.** Slå aldrig på något som kan kosta pengar.
15. **GitHub bara via REST.** `gh pr` och `gh issue` fungerar inte i molnsessioner (GraphQL är avstängt). Använd `gh api` och de särskilda `ccr`-vägarna; se avsnittet GitHub från sessionen.
<!-- kärnregler:slut -->

## Om repot

Ett av fyra syskonrepon (`dumpen`, `jobb`, `klarsprak`, `politiker`) med samma mönster för platshållare, deploy, Docker och dokumentation. Läs `AGENTS.md`, `README.md` och `docs/` före större ändringar.

| Katalog | Ingång | Hanterare | Bindningar |
|---|---|---|---|
| `.` | `apps/web/src/index.ts` | fetch, scheduled `0 9 10-13 * *`, Workflow `JobAutomationWorkflow` | D1, R2, Browser Rendering, send_email, Secrets Store `JOBB_CONFIG_KEY` |

## Kommandon

Installera, typkontrollera och testa (pnpm enligt `packageManager`):

```bash
P="npx --yes $(node -p "require('./package.json').packageManager")"
$P install && $P typecheck && $P test
```

Kör också, för det du har ändrat: `npx --yes prettier@latest --check .` (inställningar i `.prettierrc.json`, radbredd 100; rätta med `--write`), `shellcheck` på `.sh`-filer och `jq empty` på `.json`-filer. Tester som läser källfiler får inte bero på formatering; anropa hellre den riktiga koden.

## Arkitektur

- **Flödet:** söker tio lämpliga jobb i månaden på StudentConsulting genom ett Workflow med `@cloudflare/playwright` över Browser Rendering, och samlar dem i `jobbansokningar_ÅÅÅÅ-MM-DD.txt` (jobb-ID, jobbtyp, ort, omfattning) som kan laddas ned och mejlas till en eller flera mottagare. Ingen rapportering till Arbetsförmedlingen (det finns inget API).
- **Månadsgränsen** är exakt tio verifierade ansökningar. Ett osäkert resultat stoppar och räknas aldrig som lyckat eller misslyckat; skillnaden mellan applied, not_applied och unknown ska bevaras.
- **Webbläsarlogiken** stannar i `packages/studentconsulting`. Browser Rendering kostar per webbläsartimme, så håll sessionerna korta och stäng dem även vid fel.
- **D1** är enda sanningen om körningar och ansökningar; R2 innehåller bara bevis.
- **Inloggning:** i produktion är Cloudflare Access enda inloggningen och Workern verifierar Access-JWT:n själv. `AUTH_MODE=password` finns bara för egen drift.
- **Konfigurationen** i D1 är krypterad med AES-GCM och en nyckel härledd från `JOBB_CONFIG_KEY` (rotation via `JOBB_CONFIG_KEY_PREVIOUS`). `CONFIG_NAMESPACE` får aldrig ändras för en befintlig databas.

## Platshållare och deploy

- **Koden är generisk** och innehåller bara platshållare `__NAMN__`. Varje platshållare som används ska deklareras i `cloudflare.example.env` med ett exempelvärde och en kommentar om var det riktiga värdet kommer ifrån.
- **`node tools/render.mjs <values.env | -> <utkatalog> [overlay]`** kopierar repot, fyller i alla deklarerade platshållare (och stoppar om ett värde saknas), lägger overlay-katalogen ovanpå, tar bort routes med tomt mönster och länkar `node_modules`. Med `-` kommer värdena från miljövariabler.
- **Produktion** driftsätts av Workers Builds (Cloudflares GitHub-koppling) när en PR mergas till `main`, med värdena som byggvariabler i Cloudflare: bygg med `node tools/render.mjs - build`, driftsätt med `npx wrangler deploy --cwd build`. Bara `main` byggs.
- **Egen driftsättning** från en privat värdefil fungerar likadant: rendera, kör `npx wrangler deploy --cwd build` och släng den renderade kopian. Hemligheter läggs in med `npx wrangler secret put`.
- **Migreringar:** driftsätt den nya Workern innan en migrering som tar bort tabeller eller kolumner körs.
- **Tester** körs på den orenderade källan och ser alltså platshållarna.

## Kostnad och loggning

- **Gratisplanen:** sikta på Workers Free, 10 ms CPU per anrop. Ingen full inventering eller omskanning per cron-körning, förfrågan eller tillagt objekt; arbeta inkrementellt och spara härledda data när de skrivs.
- **Loggning:** loggar med sampling 1 och anropsloggar, traces 0,01, frågesträngar maskerade och Workers Issues på. Logga fel och varningar och högst en eller två rader per körning. Hanterade fel når Issues bara genom `console.error`.

## Dokumentation

`README.md`, `docker/README.md` och `docs/` är också dokumentationssajten på GitHub Pages (`pissmyran.github.io/jobb`), byggd med Zensical (`zensical.toml`, `requirements-docs.txt`) och publicerad från `main` av `.github/workflows/pages.yml`. Appen ligger bakom Cloudflare Access, så dokumentationen publiceras bara på GitHub.

- **Bygg lokalt:** `node tools/docs-site.mjs && zensical build` (utdata i `site/`). `tools/docs-site.mjs` gör README till startsida och pekar länkar till filer utanför sajten mot GitHub.
- **Wikin** speglas envägs av `.github/workflows/wiki.yml`. Redigera aldrig wikin.
- **README** ska behålla raden `**Dokumentation:**` överst. Nya sidor under `docs/` läggs in i `nav` i `zensical.toml`; titlarna där blir också wikins sidnamn.

## Docker och release

- **Filer:** `Dockerfile` (bygg från roten: `docker build -t jobb .`), `docker-compose.yml`, `CHANGELOG.md` och `docker/` (`README.md` är sidan på Docker Hub, `entrypoint.sh`, `import-settings.sh` och containerns wrangler-konfiguration).
- **Körning:** Workern körs i workerd via `wrangler dev --local` med allt tillstånd under `/data`. Entrypointen renderar källan med `tools/render.mjs` från containerns miljö med standardvärden som fungerar direkt, och genererar saknade krypteringsnycklar en gång till `/data`. Befintliga nycklar skrivs aldrig över. Bilderna startar tomma och läser aldrig från någons Cloudflare-resurser.
- **Inställningar** kommer från `docker-compose.yml`, eller en gång från `/data/import.env`, som `import-settings.sh` slår ihop med `/data/settings.env` och sedan raderar. Icke-tomma compose-variabler vinner.
- **Håll ihop:** `docker/README.md`, `docker-compose.yml` och `CHANGELOG.md` ska stämma med varandra. Dokumentationen ska ange Docker Hub-bilden att använda i compose, inte bygga från repot.
- **Release:** höj versionen i `package.json` i PR:en enligt semver och lägg till `## X.Y.Z – ÅÅÅÅ-MM-DD` i `CHANGELOG.md`. När PR:en når `main` skapar `release.yml` tagg och release och anropar `docker.yml`, som publicerar `X.Y.Z`, `X.Y`, `X` och `latest` till Docker Hub. En merge utan versionshöjning släpper inget. Fallerar Docker-jobbet kan ägaren köra om det; Claude ändrar inte workflowen.

## Granskning i det här repot

- **Grind:** `main` kräver PR, linjär historik, lösta granskningstrådar och CodeQL utan fel eller allvarliga larm. Inga andra kontroller krävs, så de lokala testerna i Kommandon är testgrinden.
- **CodeRabbit:** ärver den centrala konfigurationen i `pissmyran/coderabbit`. Repots `.coderabbit.yaml` pekar ut riskområden med egna granskningsinstruktioner; läs den del som gäller filerna du ändrar innan du börjar.
- **Extra noggrant:** ansökningsflödet (kvot, reservationer, omförsök), autentisering, krypterad konfiguration och migreringar.

## GitHub från sessionen

GraphQL är avstängt, så `gh pr` och `gh issue` fungerar inte. Använd REST:

- Öppna PR: `gh api repos/pissmyran/jobb/pulls -f base=main -f head=<gren> -f title='…' -f body='…'`
- PR från gren: `gh api 'repos/pissmyran/jobb/pulls?head=pissmyran:<gren>&state=open'`
- Issue: `gh api repos/pissmyran/jobb/issues/<n>` och `…/issues/<n>/comments`
- Granskningstrådar: `gh api repos/pissmyran/jobb/pulls/<n>/ccr/review_threads`
- Svara i tråd: `gh api repos/pissmyran/jobb/pulls/<n>/comments/<id>/replies -f body='…'`
- Lös tråd: `gh api -X POST repos/pissmyran/jobb/pulls/<n>/ccr/comments/<id>/resolve`
- Kontroller: `gh api repos/pissmyran/jobb/commits/<sha>/check-runs`
- Auto-merge på: `gh api -X PUT repos/pissmyran/jobb/pulls/<n>/ccr/auto_merge`
- Stäng PR: `gh api -X PATCH repos/pissmyran/jobb/pulls/<n> -f state=closed`
- Radera gren: `gh api -X DELETE repos/pissmyran/jobb/git/refs/heads/<gren>`
