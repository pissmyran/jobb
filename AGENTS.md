# AGENTS.md

## Läs först

1. [CLAUDE.md](CLAUDE.md): gemensamma regler för arbetssätt, deploy, loggning, kostnader och Docker. Allt arbete sker på `dev`; `main` ändras bara genom en PR från `dev` med squash merge.
2. [docs/oversikt.md](docs/oversikt.md): karta över dokumentationen.
3. [docs/architecture.md](docs/architecture.md): bindningar, state och säkerhet.
4. [docs/automation.md](docs/automation.md) och [docs/providers.md](docs/providers.md): körningarna och StudentConsulting.
5. [docs/authentication.md](docs/authentication.md) och [docs/operations.md](docs/operations.md): inloggning, nycklar och drift.

## Regler som alltid gäller

- Månadsgränsen är exakt tio verifierade ansökningar. Ett osäkert resultat från StudentConsulting stoppar, det räknas aldrig som lyckat eller misslyckat.
- I produktion är Cloudflare Access den enda inloggningen, och Workern kontrollerar Access-JWT:n själv. `AUTH_MODE=password` finns bara för egna installationer.
- Webbläsarlogiken stannar i `packages/studentconsulting` och sprids inte in i resten av koden. Browser Rendering kostar per webbläsartimme.
- D1 är den enda sanningen om körningar och ansökningar; R2 innehåller bara bevis.
- Kör `pnpm typecheck` och `pnpm test` före push till `dev`. En migrering som lägger till körs före deployen, en som tar bort efter.
- Ändra inte behörigheter eller driftsättningen för att få en kontroll att gå igenom.
- Inga personliga värden i koden, bara platshållare (`__NAMN__`) som deklareras i `cloudflare.example.env`. Uppdatera `CHANGELOG.md` och versionen i `package.json` vid varje ny image.
- Hemligheter, kontouppgifter, sessioner och bevis hamnar aldrig i Git, loggar eller publik dokumentation.
