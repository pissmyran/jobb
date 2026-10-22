# Inloggning och nycklar

## Översikten: Cloudflare Access

Cloudflare Access står framför Workerns domän och sköter inloggningen. Vem som får logga in styrs av Access-policyn i Zero Trust, inte av Jobb.

Workern kontrollerar ändå varje anrop: `Cf-Access-Jwt-Assertion` måste vara en RS256-signerad JWT från teamets `/cdn-cgi/access/certs`, med rätt `iss`, `aud` (= `CF_ACCESS_AUD`), giltig `exp` och `nbf` och en e-postadress. Ett anrop som tar sig förbi Access släpps alltså ändå inte in.

- `CF_ACCESS_TEAM_DOMAIN` är teamdomänen, `<team>.cloudflareaccess.com`.
- `CF_ACCESS_AUD` är Access-applikationens *Application Audience (AUD) Tag*.

Saknas något av dem, eller är de ofullständiga, avvisas alla anrop och `/api/ready` rapporterar fel. `POST /auth/logout` skickar vidare till `/cdn-cgi/access/logout`, och `/login` leder till `/`.

## Lösenordsläget (egen installation)

Med `AUTH_MODE=password` skyddas översikten i stället av `ADMIN_PASSWORD` (minst 8 tecken) och en HMAC-signerad sessionscookie som gäller i 30 dagar. Byte av lösenord loggar ut alla. Läget är till för Docker och andra egna installationer och sätts aldrig i produktion bakom Access.

## StudentConsulting-kontot

`STUDENTCONSULTING_EMAIL` och `STUDENTCONSULTING_PASSWORD` sätts antingen som hemligheter på Workern eller sparas under **System**. Hemligheter på Workern går före. Lokalt kan de ligga i `.dev.vars`, som aldrig checkas in.

Koden får kontot genom en `CredentialsProvider`. Lösenordet loggas aldrig, skrivs aldrig till R2, skickas aldrig tillbaka i API-svar och syns aldrig i skärmbilder. Det enda som sparas i D1 är det krypterade inställningsdokumentet.

## Nyckeln och nyckelbyte

Inställningsdokumentet krypteras med AES-GCM, med en nyckel som härleds med HKDF ur `JOBB_CONFIG_KEY` i Secrets Store.

Så byter du nyckel utan att förlora inställningarna:

1. Lägg den nya nyckeln som `JOBB_CONFIG_KEY` och den gamla som `JOBB_CONFIG_KEY_PREVIOUS`.
2. Öppna översikten. Första läsningen krypterar om dokumentet med den nya nyckeln, utan att ändra vem eller när det senast ändrades.
3. Ta bort `JOBB_CONFIG_KEY_PREVIOUS`.

Ett dokument som ingen av nycklarna kan läsa rapporteras som oläsbart och ersätts nästa gång något sparas under **System**.

## I repot

Bara namnen på hemligheter, gränssnitt, exempel med påhittade värden och instruktioner hör hemma i Git. Riktiga värden gör det aldrig.
