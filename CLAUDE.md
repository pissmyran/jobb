# CLAUDE.md – jobb

Vägledning för Claude Code i `pissmyran/jobb`. Tjänsten jobb: en månatlig jobbansökningshjälp på Cloudflare Workers, plus en Docker-bild för egen drift.

De gemensamma reglerna för alla repon finns i [GOVERNANCE.md](https://github.com/pissmyran/.github/blob/main/GOVERNANCE.md) i `pissmyran/.github`. Kärnreglerna nedan är en ordagrann kopia. Jämför i början av varje session versionen i markeringen med källan:

```sh
curl -fsS https://raw.githubusercontent.com/pissmyran/.github/main/GOVERNANCE.md
```

Är kopian äldre, uppdatera den först i en egen PR (`docs: sync core rules from .github`).

## Kärnregler

<!-- core-rules:start version=2026-10-29 source=https://github.com/pissmyran/.github/blob/main/GOVERNANCE.md -->
1. **No personal values.** The repository is public. Never write real IDs, domains, email addresses, names, keys, payment links or account details in code, configuration, tests, documentation or commit messages. Use placeholders and `example.com` values.
2. **No secrets.** Tokens, passwords, sessions and keys never end up in Git, logs, issues or public documentation. Secrets live outside the repository (Cloudflare, GitHub environments, `wrangler secret put`, the sandbox proxy).
3. **Stay in scope.** Work only in the repositories you were assigned. Never ask for broader token permissions. If a task needs more, describe it in an issue and let the owner decide.
4. **Branch and pull request.** Every session starts from the latest `main` (`git fetch origin main`) on its own branch. `main` changes only through a squash-merged pull request. Nobody pushes directly to `main`. One session's work stays in one pull request.
5. **Test locally before every push.** CI runs no test checks. The repository's own tests and checks (the Commands section of its `CLAUDE.md`) are the only test gate. Never push with failing tests, and write tests for what you change.
6. **Never touch workflows.** Do not change `.github/workflows/`, `.github/actions/` or `CODEOWNERS`, not even to fix an error. The token has no Workflows permission, so such a push is rejected. If a change is needed, describe it in an issue and let the owner make it. Only Renovate and Dependabot update them.
7. **Review.** CodeRabbit, Sourcery and Codex review, and CodeQL (GitHub default setup) scans. Resolve every review thread before merge. Reply in the thread with what you changed, or with the reason if the finding is noise.
8. **Auto-merge last.** Enable auto-merge only when the review bots have reviewed the latest commit (CodeRabbit skips `docs/` and `*.md`; for those changes Sourcery and Codex are enough), all threads are resolved and every check that runs on the pull request is green, including checks the rules do not require.
9. **Fix the cause, not the symptom.** When something fails or a review asks for a change: read everything, find the cause and redo that part properly. Small obvious errors may be fixed directly. Never weaken a test, skip a check or silence a warning.
10. **Security first.** Security alerts (CodeQL, Dependabot, secret scanning, Renovate) come before other work. Open an issue for each alert and link it from the fix with `Closes #n`. Never copy a secret value into an issue. If an alert would expose an exploitable weakness or a live secret, use a private draft security advisory instead of a public issue.
11. **Latest versions.** Never add new pins to a version number; use `@latest`, `node`, `latest` and version ranges. Existing pins that Renovate keeps current (for example `packageManager`, `requirements-docs.txt`, `.node-version`, lockfiles and actions pinned to a commit SHA) stay, and only Renovate changes them.
12. **Commits and titles.** Commit with the git identity the sandbox provides. Never change git's user, email or signing, and never use `--no-verify`. The pull request title becomes the commit on `main` and follows Conventional Commits in English: `type: description` or `type(scope): description`, with type feat, fix, docs, refactor, perf, test, build, ci, chore, style or revert.
13. **Documentation in the same pull request.** When behaviour, settings or commands change, update `README.md`, `docs/` and the repository's `CLAUDE.md` in the same pull request.
14. **No stray branches.** Delete the branch when the pull request is merged or closed. Pull requests from forks are suggestions: make the change yourself on your own branch if it is wanted, and close the original with thanks and a link.
15. **Zero cost.** Never enable anything that can cost money.
16. **Model before task.** Before every new task, state which model fits it best and that it must be activated before work starts. Switching is not automatic. Do not start the task until the owner has confirmed or switched.
<!-- core-rules:end -->

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

- **Bygg lokalt:** installera Zensical med `pip install -r requirements-docs.txt` (gärna i en virtuell miljö), kör sedan `node tools/docs-site.mjs && zensical build` (utdata i `site/`). `tools/docs-site.mjs` gör README till startsida och pekar länkar till filer utanför sajten mot GitHub.
- **Wikin** speglas envägs av `.github/workflows/wiki.yml`. Redigera aldrig wikin.
- **README** ska behålla raden `**Dokumentation:**` överst. Nya sidor under `docs/` läggs in i `nav` i `zensical.toml`; titlarna där blir också wikins sidnamn.
- **Engelsk spegling:** `docs/eng/` är en engelsk översättning av dokumentationen: `README.md` blir `docs/eng/index.md`, `docker/README.md` blir `docs/eng/docker.md` och övriga sidor behåller sina filnamn. Ändras en svensk sida uppdateras den engelska i samma PR, och en ny sida läggs in i både det svenska och det engelska avsnittet i `nav`. Språkväljaren i sidhuvudet styrs av `extra.alternate` i `zensical.toml`.
- **Språk:** dokumentationen är svensk i första hand. Allt annat skrivs på engelska: kod, kommentarer, PR-titlar och beskrivningar, commit-meddelanden, granskningssvar och etiketter.

## Docker och release

- **Filer:** `Dockerfile` (bygg från roten: `docker build -t jobb .`), `docker-compose.yml`, `CHANGELOG.md` och `docker/` (`README.md` är sidan på Docker Hub, `entrypoint.sh`, `import-settings.sh` och containerns wrangler-konfiguration).
- **Körning:** Workern körs i workerd via `wrangler dev --local` med allt tillstånd under `/data`. Entrypointen renderar källan med `tools/render.mjs` från containerns miljö med standardvärden som fungerar direkt, och genererar saknade krypteringsnycklar en gång till `/data`. Befintliga nycklar skrivs aldrig över. Bilderna startar tomma och läser aldrig från någons Cloudflare-resurser.
- **Inställningar** kommer från `docker-compose.yml`, eller en gång från `/data/import.env`, som `import-settings.sh` slår ihop med `/data/settings.env` och sedan raderar. Icke-tomma compose-variabler vinner.
- **Håll ihop:** `docker/README.md`, `docker-compose.yml` och `CHANGELOG.md` ska stämma med varandra. Dokumentationen ska ange Docker Hub-bilden att använda i compose, inte bygga från repot.
- **Release:** höj versionen i `package.json` i PR:en enligt semver och lägg till `## X.Y.Z – ÅÅÅÅ-MM-DD` i `CHANGELOG.md`. När PR:en når `main` skapar `release.yml` tagg och release och anropar `docker.yml`, som publicerar `X.Y.Z`, `X.Y`, `X` och `latest` till Docker Hub. En merge utan versionshöjning släpper inget. Fallerar Docker-jobbet, kör om de fallerade jobben i release-körningen ("Re-run failed jobs"). Stannade releasen efter att taggen skapades, kör `docker.yml` manuellt (workflow_dispatch på taggen); annars publiceras ingen bild. Saknar sessionen behörighet, be ägaren göra det. Workflowfilerna ändras aldrig.

## Granskning i det här repot

- **Grind:** `main` kräver PR, linjär historik, lösta granskningstrådar och CodeQL utan fel eller allvarliga larm. Inga andra kontroller krävs, men de som körs ska vara gröna. De lokala testerna i Kommandon är testgrinden.
- **CodeRabbit:** ärver den centrala konfigurationen i `pissmyran/coderabbit`. Repots `.coderabbit.yaml` pekar ut riskområden med egna granskningsinstruktioner; läs den del som gäller filerna du ändrar innan du börjar.
- **Sourcery och Codex:** granskar också, som GitHub-appar utan egen konfiguration här, och de granskar även dokumentation. Behandla deras trådar som CodeRabbits.
- **Extra noggrant:** ansökningsflödet (kvot, reservationer, omförsök), autentisering, krypterad konfiguration och migreringar.

## GitHub från sandlådan

Sandlådan lägger in agentens fine-grained token för `github.com` och `api.github.com`, så `git` och `gh` fungerar som vanligt. Token når bara den här agentens repon.

Öppna en PR:

```sh
gh pr create --base main --title '<title>' --body '<body>'
```

Visa kontrollerna på en PR:

```sh
gh pr checks <n>
```

Lista granskningskommentarerna på rader (varje `id` används för svar):

```sh
gh api repos/pissmyran/jobb/pulls/<n>/comments
```

Svara på en granskningskommentar:

```sh
gh api repos/pissmyran/jobb/pulls/<n>/comments/<id>/replies -f body='<reply>'
```

Lista granskningstrådarna med nod-id (`id`) och första kommentaren:

```sh
gh api graphql -f query='query { repository(owner: "pissmyran", name: "jobb") { pullRequest(number: <n>) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 1) { nodes { databaseId body } } } } } } }'
```

Lös en granskningstråd med trådens nod-id, inte kommentarens id:

```sh
gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id='<thread-id>'
```

Slå på auto-merge och radera grenen efter merge:

```sh
gh pr merge <n> --auto --squash --delete-branch
```

Stäng en PR och radera dess gren:

```sh
gh pr close <n> --delete-branch
```

Lista Dependabot-larm:

```sh
gh api repos/pissmyran/jobb/dependabot/alerts
```

Lista kodskanningslarm:

```sh
gh api repos/pissmyran/jobb/code-scanning/alerts
```

Lista larm från hemlighetsskanning:

```sh
gh api repos/pissmyran/jobb/secret-scanning/alerts
```
## GitHub från sessionen

GraphQL är avstängt, så `gh pr` och `gh issue` fungerar inte. Använd REST:

- Öppna PR: `gh api repos/pissmyran/jobb/pulls -f base=main -f head=<gren> -f title='…' -f body='…'`
- PR från gren: `gh api 'repos/pissmyran/jobb/pulls?head=pissmyran:<gren>&state=open'`
- Issue: `gh api repos/pissmyran/jobb/issues/<n>` och `…/issues/<n>/comments`
- Granskningstrådar: `gh api repos/pissmyran/jobb/pulls/<n>/ccr/review_threads`
- Svara i tråd: `gh api repos/pissmyran/jobb/pulls/<n>/comments/<id>/replies -f body='…'`
- Lös tråd: `gh api -X POST repos/pissmyran/jobb/pulls/<n>/ccr/comments/<id>/resolve`
- Kontroller: `gh api repos/pissmyran/jobb/commits/<sha>/check-runs`
- Auto-merge på: `gh api -X PUT repos/pissmyran/jobb/pulls/<n>/ccr/auto_merge -f merge_method=squash`
- Är PR:en redan klar att mergas (auto-merge vägras då), squash-merga direkt: `gh api -X PUT repos/pissmyran/jobb/pulls/<n>/merge -f merge_method=squash`
- Stäng PR: `gh api -X PATCH repos/pissmyran/jobb/pulls/<n> -f state=closed`
- Radera gren: GitHub raderar grenen vid merge. En stängd PR:s gren raderas med `git push origin --delete <gren>` (API-vägen är spärrad).
