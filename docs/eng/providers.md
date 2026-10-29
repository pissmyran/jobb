# StudentConsulting

The integration lives in `packages/studentconsulting` and talks to StudentConsulting through Browser Rendering via a small browser layer. The rest of the code only sees job candidates, application results and error codes.

## Ground rules

1. Only suitable jobs count toward the monthly goal.
2. The monthly goal is ten verified applications.
3. Failed or unclear applications do not count.
4. An application is never resent blindly; an unclear result is verified first.
5. Everything uncertain or ambiguous stops, instead of guessing.

## Sign-in

1. Jobb opens `/signin` and follows the OIDC redirect to StudentConsulting's sign-in.
2. If the session is already signed in and lands directly on the profile (`/sv/profil/`) without visible sign-in fields, it is used without reading the password again. Otherwise the account is filled in and the form is submitted.
3. Sign-in is only accepted when the browser is on StudentConsulting's exact origin under `/sv/profil/`. Visible sign-in fields are checked again after sign-in, after the profile has opened and after every page change in the list.

## Searching in *Matcha jobb*

1. The link to the job matching is found by its text. Only established variants of **Matcha jobb**, **Jobbmatchning(ar)** and **Matchning(ar) mot jobb** are accepted; other public labels are rejected.
2. The link must lead to exactly one address on the same origin under `/sv/profil/…` (or the older `/sv/min-profil/…`). A placeholder in `href` may be combined with exactly one trusted `data-href` or `data-url`. If there is none, exactly one visible link may be clicked, and if the address does not change the page is searched once more for a new trusted link.
3. If no such link exists, a single unambiguous button or navigation control may be activated, and the address afterwards must pass the same check.
4. External addresses, addresses with credentials, redirects out of the profile and several possible options stop the run. There is no hard-coded fallback address.
5. From the verified page, only strictly normalized job addresses of the form `/sv/lediga-jobb/…/<job ID>` are accepted, whether they come from `href`, `data-href`, `data-url` or `onclick`. Jobb never falls back to the public job list.
6. An empty match list is reported on its own and kept apart from a page where no trusted job addresses are found.

When something is not recognized, the diagnostics only hold at most 20 paths under the profile and counts of elements of different kinds, never labels, profile text, query strings or filled-in values.

## Suitability

1. Job ID, city, occupational category and country are read from the job page.
2. When the job page lacks a country, it is fetched from StudentConsulting's public job API with the filters for Sweden, Norway and Denmark. A country that cannot be determined stops the candidate.
3. `JOB_INCLUDE_TERMS`, `JOB_EXCLUDE_TERMS`, `JOB_ALLOWED_LOCATIONS` and `JOB_ALLOWED_COUNTRIES` then filter on top of StudentConsulting's own matching.

## Applying

1. One of the month's ten slots is reserved before anything is sent.
2. Questions about experience are answered with *Ingen erfarenhet* (no experience) when exactly that option exists, and the *Pitch* field is filled with a short default text if it is empty. Other required fields that cannot be filled in stop the application with `APPLICATION_REQUIRES_INPUT`.
3. The application is only sent when `STUDENTCONSULTING_AUTOSUBMIT=true` and there is exactly one recognized submit button.

## Verification

1. Jobb reads StudentConsulting's job API from inside the signed-in browser and requires that exactly that job ID has `is_applied=true`.
2. If that does not work, the **Ansökningar** (applications) view is opened with the same origin and profile rules as for the search. The exact job ID must then be visible in the view or in a trusted job address.
3. Verification never sends a new application.

Verified applications save evidence as JSON in R2 and metadata in the D1 table `evidence`. The column `evidence.sha256` exists but is not filled in yet, so it is no integrity protection.
