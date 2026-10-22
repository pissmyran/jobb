# StudentConsulting

Integrationen ligger i `packages/studentconsulting` och pratar med StudentConsulting genom Browser Rendering via ett litet webbläsarlager. Resten av koden ser bara jobbkandidater, ansökningsresultat och felkoder.

## Grundregler

1. Bara passande jobb räknas mot månadsmålet.
2. Månadsmålet är tio verifierade ansökningar.
3. Misslyckade eller oklara ansökningar räknas inte.
4. En ansökan skickas aldrig om blint; ett oklart resultat verifieras först.
5. Allt som är osäkert eller tvetydigt stoppar, i stället för att gissa.

## Inloggning

1. Jobb öppnar `/signin` och följer OIDC-omdirigeringen till StudentConsultings inloggning.
2. Om sessionen redan är inloggad och landar direkt i profilen (`/sv/profil/`) utan synliga inloggningsfält används den, utan att lösenordet läses igen. Annars fylls kontot i och formuläret skickas.
3. Inloggningen godkänns bara när webbläsaren står på StudentConsultings exakta ursprung under `/sv/profil/`. Synliga inloggningsfält kontrolleras igen efter inloggningen, efter att profilen öppnats och efter varje sidbyte i listan.

## Sökning i *Matcha jobb*

1. Länken till jobbmatchningen hittas på sin text. Bara etablerade varianter av **Matcha jobb**, **Jobbmatchning(ar)** och **Matchning(ar) mot jobb** godtas; andra publika etiketter avvisas.
2. Länken måste leda till exakt en adress på samma ursprung under `/sv/profil/…` (eller den äldre `/sv/min-profil/…`). En platshållare i `href` får kombineras med exakt en betrodd `data-href` eller `data-url`. Finns ingen sådan får exakt en synlig länk klickas, och om adressen inte ändras söks sidan av en gång till efter en ny betrodd länk.
3. Saknas en sådan länk får en enda entydig knapp eller navigeringskontroll aktiveras, och adressen efteråt måste klara samma kontroll.
4. Externa adresser, adresser med inloggningsuppgifter, omdirigeringar ut ur profilen och flera möjliga alternativ stoppar körningen. Det finns ingen hårdkodad reservadress.
5. Från den verifierade sidan godtas bara strikt normaliserade jobbadresser av formen `/sv/lediga-jobb/…/<Jobb-ID>`, oavsett om de kommer från `href`, `data-href`, `data-url` eller `onclick`. Jobb faller aldrig tillbaka på den publika jobblistan.
6. En tom matchningslista rapporteras för sig och skiljs från en sida där inga betrodda jobbadresser hittas.

När något inte känns igen innehåller diagnostiken bara högst 20 sökvägar under profilen och antal element av olika slag, aldrig etiketter, profiltext, frågesträngar eller ifyllda värden.

## Lämplighet

1. Jobb-ID, ort, yrkeskategori och land läses från jobbsidan.
2. När jobbsidan saknar land hämtas det från StudentConsultings publika jobb-API med filtren för Sverige, Norge och Danmark. Ett land som inte går att avgöra stoppar kandidaten.
3. `JOB_INCLUDE_TERMS`, `JOB_EXCLUDE_TERMS`, `JOB_ALLOWED_LOCATIONS` och `JOB_ALLOWED_COUNTRIES` filtrerar därefter, ovanpå StudentConsultings egen matchning.

## Ansökan

1. En av månadens tio platser reserveras innan något skickas.
2. Frågor om erfarenhet besvaras med *Ingen erfarenhet* när exakt det alternativet finns, och fältet *Pitch* fylls i med en kort standardtext om det är tomt. Andra obligatoriska fält som inte kan fyllas i stoppar ansökan med `APPLICATION_REQUIRES_INPUT`.
3. Ansökan skickas bara när `STUDENTCONSULTING_AUTOSUBMIT=true` och det finns exakt en igenkänd skicka-knapp.

## Verifiering

1. Jobb läser StudentConsultings jobb-API inifrån den inloggade webbläsaren och kräver att exakt det jobb-ID:t har `is_applied=true`.
2. Om det inte går öppnas vyn **Ansökningar** med samma regler för ursprung och profil som vid sökningen. Exakt jobb-ID måste då synas i vyn eller i en betrodd jobbadress.
3. Verifieringen skickar aldrig någon ny ansökan.

Verifierade ansökningar sparar bevis som JSON i R2 och metadata i D1-tabellen `evidence`. Kolumnen `evidence.sha256` finns men fylls inte i ännu, så den är inget integritetsskydd.
