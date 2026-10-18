# AGENTS.md

## Läs först

1. [CLAUDE.md](CLAUDE.md) — gemensamma regler för arbetssätt, deploy, loggning, kostnader och Docker. Arbetet sker lokalt; färdigt och granskat arbete pushas direkt till `main` på GitHub.
2. [docs/index.md](docs/index.md) — dokumentationskarta.
3. [docs/project-context.md](docs/project-context.md) — teknisk current-state.
4. [docs/architecture.md](docs/architecture.md) — runtime, state och trust boundaries.
5. [docs/operations.md](docs/operations.md) — verifiering, deployment och incidentkontroller.
6. [docs/automation.md](docs/automation.md) och [docs/providers.md](docs/providers.md) — domänspecifika flöden.
7. [docs/authentication.md](docs/authentication.md) — auth- och credentialgränser.

## Invariants

- Månadsgränsen är exakt tio verifierade lämpliga ansökningar; osäkra providerresultat ska faila stängt.
- Jobb rapporterar inte till Arbetsförmedlingen (det finns inget API). Månadens tio ansökningar samlas i `jobbansokningar_ÅÅÅÅ-MM-DD.txt` med jobb-ID, jobbtyp, stad och omfattning, som kan laddas ner från översikten eller mejlas till en eller flera mottagare.
- Inloggning: i produktion är Cloudflare Access den enda vägen; Workern verifierar Access-JWT:n (`CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD`). `AUTH_MODE=password` (lösenord och signerad sessionscookie) finns bara för egna installationer och ska aldrig sättas i produktion. Ingen GitHub-inloggning.
- Browser Run är integrationsgräns för browserbaserade providerflöden; sprid inte browserimplementation in i domänlogiken. Browser Rendering debiteras per webbläsartimme.
- D1 är canonical run/application state; R2 evidence är stöddata.
- Kör minst `pnpm typecheck` och `pnpm test` före deploy, och applicera nya D1-migrationer efter att den nya Workern är deployad.
- Ändra inte permissions eller deploymentarkitektur som workaround för failing checks.
- Koden innehåller inga personliga värden, bara platshållare (`__NAMN__`) som deklareras i `cloudflare.example.env` och fylls i av `tools/render.mjs` vid deploy och av `docker/entrypoint.sh` i containern. Se regeln i `CLAUDE.md`. I containern finns `docker/container-entry.ts` med SMTP-utskick och `docker/scheduler.mjs` för den månatliga körningen. Uppdatera `CHANGELOG.md` och versionen i `package.json` vid varje ny image.
- Lägg aldrig secrets, providercredentials, sessionsmaterial eller privat evidence i Git eller publik dokumentation.
