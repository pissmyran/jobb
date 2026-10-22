# Översikt

Jobb är en Cloudflare Worker med en skyddad översikt, en Workflow som gör själva jobbsökningen och en månadsfil med resultatet.

```text
Översikten / Cron
        |
        v
Cloudflare Worker ──> D1        körningar, ansökningar, månadsgräns, inställningar
        |         ──> R2        bevis från verifierade ansökningar
        |         ──> Email     utskick av månadsfilen
        v
Workflow ──> Browser Rendering ──> StudentConsulting
```

## Var finns vad

| Ämne | Sida |
| --- | --- |
| Bindningar, state, säkerhet och loggning | [Arkitektur](architecture.md) |
| Översiktens vyer, körningar, månadsgränsen, felkoder, månadsfilen och inställningar | [Automation](automation.md) |
| Inloggning, sökning, ansökan och verifiering hos StudentConsulting | [StudentConsulting](providers.md) |
| Cloudflare Access, lösenordsläget och krypterade inställningar | [Inloggning och nycklar](authentication.md) |
| Driftsättning, migreringar, kontroller och felsökning | [Drift](operations.md) |

## Vem äger vilken data

- **D1** är den enda sanningen om körningar, ansökningar och månadsgränsen.
- **R2** innehåller bara bevis som stöd; inget beslut fattas utifrån R2.
- **Workflow** styr körningen men lagrar inget eget state som översikten litar på.
- **Browser Rendering** är bara transporten till StudentConsulting. Webbläsarlogiken stannar i `packages/studentconsulting` och sprids inte in i resten av koden.
- **Översikten** visar och styr, men är aldrig en egen källa till sanning.

## Innan du ändrar något

- **Automationen:** läs [Automation](automation.md) och kontrollera att månadsgränsen och reglerna om att stanna vid osäkerhet fortfarande håller.
- **StudentConsulting:** läs [StudentConsulting](providers.md) och [Arkitektur](architecture.md). Håll isär fel hos StudentConsulting och fel i körningens state.
- **Inloggningen:** läs [Inloggning och nycklar](authentication.md) innan du ändrar routes, inloggning eller Access-inställningar.
