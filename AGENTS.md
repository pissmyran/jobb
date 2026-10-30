# AGENTS.md – jobb

En månatlig jobbansökningshjälp på Cloudflare Workers, plus en Docker-bild för egen drift.

Läs de gemensamma reglerna i början av varje session: [GOVERNANCE.md](https://raw.githubusercontent.com/pissmyran/.github/main/GOVERNANCE.md) och [SERVICES.md](https://raw.githubusercontent.com/pissmyran/.github/main/SERVICES.md). Läs `README.md` före större ändringar.

## Läs vid behov

Read `.coderabbit.yaml` for repository-specific review guidance, including historical imports, monthly exports, dashboard state and documentation mirrors. Shared review settings remain in `pissmyran/coderabbit`.

- [docs/oversikt.md](docs/oversikt.md): karta över dokumentationen.
- [docs/architecture.md](docs/architecture.md): bindningar, state och säkerhet.
- [docs/automation.md](docs/automation.md) och [docs/providers.md](docs/providers.md): körningarna och StudentConsulting.
- [docs/authentication.md](docs/authentication.md) och [docs/operations.md](docs/operations.md): inloggning, nycklar och drift.

## Kommandon

Installera, typkontrollera och testa (pnpm enligt `packageManager`):

```bash
P="npx --yes $(node -p "require('./package.json').packageManager")"
$P install && $P typecheck && $P test
```

## Regler

- **Ingång:** `apps/web/src/index.ts`. Hanterare: fetch, scheduled `0 9 10-13 * *`, Workflow `JobAutomationWorkflow`. Bindningar: D1, R2, Browser Rendering, send_email, Secrets Store `JOBB_CONFIG_KEY`.
- **Flödet:** tio lämpliga jobb i månaden söks på StudentConsulting av ett Workflow med `@cloudflare/playwright` över Browser Rendering och samlas i `jobbansokningar_ÅÅÅÅ-MM-DD.txt` (jobb-ID, jobbtyp, ort, omfattning) som kan laddas ned och mejlas. Ingen rapportering till Arbetsförmedlingen.
- **Månadsgränsen** är exakt tio verifierade ansökningar. Ett osäkert resultat stoppar och räknas aldrig som lyckat eller misslyckat; skillnaden mellan applied, not_applied och unknown bevaras.
- **Webbläsarlogiken** stannar i `packages/studentconsulting`. Browser Rendering kostar per webbläsartimme: håll sessionerna korta och stäng dem även vid fel.
- **D1** är enda sanningen om körningar och ansökningar; R2 innehåller bara bevis.
- **Inloggning:** i produktion är Cloudflare Access enda inloggningen och Workern verifierar Access-JWT:n själv. `AUTH_MODE=password` finns bara för egen drift.
- **Konfigurationen** i D1 är krypterad med AES-GCM med en nyckel härledd från `JOBB_CONFIG_KEY` (rotation via `JOBB_CONFIG_KEY_PREVIOUS`). `CONFIG_NAMESPACE` ändras aldrig för en befintlig databas.
- **Migreringar:** en som lägger till körs före deployen.
- **Release:** versionen finns i `package.json`.
- **Extra noggrant:** ansökningsflödet (kvot, reservationer, omförsök), autentisering, krypterad konfiguration och migreringar.
