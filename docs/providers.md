# Provider implementation

## StudentConsulting

The StudentConsulting provider uses Browser Run through a small browser abstraction.

Implemented flow:

1. Open StudentConsulting's `/signin` entry point.
2. Follow the OIDC redirect to `id.studentconsulting.com`.
3. If `/signin` reuses an existing authenticated session and lands directly on the exact `/sv/profil/` area without visible login controls, accept that session without reading credentials again. Otherwise fill the configured email/password credentials and submit the login form.
4. Authenticate with OIDC returning to the verified StudentConsulting profile entry `https://www.studentconsulting.com/sv/profil/`, then revisit that profile entry for discovery. Authentication is accepted only when Browser Run is on the exact StudentConsulting origin under `/sv/profil/`. Resolve visible job-matching navigation semantically. Accepted labels are restricted to established **Matcha jobb** variants plus explicit `Jobbmatchning`/`Jobbmatchningar` and `Matchning(ar) mot jobb` forms; unrelated public labels such as `Rusta och matcha jobb` are rejected. A matched-profile anchor must resolve to exactly one URL on the exact configured origin inside `/sv/profil/...` or legacy `/sv/min-profil/...`. StudentConsulting may render a benign root placeholder in `href`; in that case an exact trusted `data-href` or `data-url` on the same semantic anchor may supply the route. If no trusted data route exists, exactly one visible semantic placeholder anchor may be clicked. If the URL stays on the profile entry, navigation is rescanned once for a newly exposed trusted semantic route/control; the same placeholder is not clicked recursively. Any resulting route must validate to the same trusted profile area. External, credential-bearing, redirected-outside-profile or ambiguous values fail closed. If no matching anchor exists, one unambiguous visible button/role-link/data-navigation control may be activated and its resulting URL must pass the same validation. Missing, untrusted or ambiguous navigation fails closed. There is no hardcoded matched-profile fallback.
5. Reject visible login controls after authentication, after opening the matched profile, and after every paginated listing navigation. Redirects outside the selected verified profile route fail closed.
6. Accept only strictly normalized StudentConsulting job-detail URLs exposed by that verified page through `href`, `data-href`, `data-url` or inline navigation such as `onclick`; absolute URLs retain and validate their original authority. If no job-matching navigation is recognized, diagnostics contain only same-origin `/sv/profil/...` or legacy `/sv/min-profil/...` paths (bounded to 20) plus structural counts for total/visible anchors and controls, semantic-match counts, and `data-href`/`data-url`/`onclick` elements. Labels, profile text, query values, attribute payloads and input values are never emitted. If the selected first matched page is neither explicitly empty nor exposes a trusted job URL, the provider emits only structural counts (anchors/data attributes/onclick/iframes/job-like elements).
7. Read Jobb-ID, location, occupational category and country from each job page; if country cannot be resolved to a supported country code, the candidate is not eligible for autosubmit.
8. Treat optional include/exclude/location/country rules as additional filters on top of the provider match.
9. Reserve one of exactly ten monthly D1 quota slots before any submit side effect.
10. Stop if any visible required application field is unresolved.
11. Submit only when `STUDENTCONSULTING_AUTOSUBMIT=true` and there is exactly one recognized application submit control.
12. Verify the application from authenticated StudentConsulting state before it can be treated as confirmed. The provider first reads the same-origin job-openings API inside the authenticated Browser Run and accepts only the exact Jobb-ID with `is_applied=true`. If that signal is unavailable or false, it falls back to the authenticated `Ansökningar` navigation, which accepts only one trusted exact-origin profile destination (including placeholder/data-navigation or a single semantic click). A direct navigation must remain on the exact selected profile path after load; redirects to another profile view are rejected. An applications view rendered in place after a placeholder click is accepted only while the browser remains in the trusted profile area and the exact job reference was absent before the click and appears afterward. Verification then requires the exact Jobb-ID either in the applications view text or in a trusted StudentConsulting job-detail URL. Reconciliation never submits a new application.

Runtime secrets/configuration:

- `STUDENTCONSULTING_EMAIL`
- `STUDENTCONSULTING_PASSWORD`
- `STUDENTCONSULTING_AUTOSUBMIT` (`true` enables submission after policy and form validation)
- optional `JOB_INCLUDE_TERMS`, `JOB_EXCLUDE_TERMS`, `JOB_ALLOWED_LOCATIONS`, and `JOB_ALLOWED_COUNTRIES`

Autosubmit defaults to disabled. Discovery fails closed unless the authenticated **Matcha jobb** profile view is present. A provider-rendered empty matched list is reported separately from a page where no trusted job-detail URL can be discovered; neither condition falls back to the public listing. `JOB_INCLUDE_TERMS` is optional and, when set, narrows that matched list further. These values can be supplied by deployment/runtime or, when absent there, by the authenticated System configuration; deployment values take precedence. Dashboard-managed secrets are encrypted before D1 persistence and are never returned as plaintext. A definitely failed pre-submit attempt releases its reserved quota slot and may be retried within the same automation run: only an application owned by that same run, still in `failed`, with both `applied_at` and `verified_at` unset is atomically requeued for a new attempt. Any application that may already have been sent (`submitted`, `needs_user_action`, `verified`, active states, or a non-null `applied_at`) continues to block a replacement. An ambiguous result remains `uncertain` so the system cannot compensate with a possible 11th application.

## Evidence and diagnostics

Application attempts persist status, machine-readable error codes and provider messages in D1. StudentConsulting Matcha-jobb discovery scans navigational `href`, `data-href`, `data-url` and inline navigation attributes, but every extracted candidate must still normalize to the trusted StudentConsulting `/sv/lediga-jobb/.../<Jobb-ID>` route before it can become a job candidate. Verified StudentConsulting evidence is stored in the private `jobb-evidence` R2 bucket with metadata in D1.

The `evidence.sha256` schema field currently exists but is not populated by the evidence write path. It must not be treated as an active integrity guarantee until hashing is implemented and verified.
