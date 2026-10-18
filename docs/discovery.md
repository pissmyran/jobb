# Integration discovery

Status: initial public-surface discovery. Private authenticated endpoints are deliberately not assumed until observed and documented.

## StudentConsulting

Verified from public documentation:

- Jobs can be filtered by location, county, country and occupational area.
- Applying requires a registered StudentConsulting account.
- Applications may use the web CV or an attached CV and can include a motivation/personal letter.
- Submitted applications and recruitment status are visible under `Ansökningar` in the authenticated profile.

Implementation consequence: treat a successful submission as provisional until it can be verified against the user's application history. Do not blindly retry an ambiguous submit operation.

## Arbetsförmedlingen

No public write API for submitting an individual's activity report exists, so Jobb does not report to Arbetsförmedlingen. It collects the month's applications in a `.txt` instead.

## Automation principles

1. Only suitable jobs count toward the monthly target.
2. Monthly target defaults to 10 verified successful applications.
3. Failed or ambiguous submissions do not count.
4. Submission operations must be idempotent or followed by verification before retry.
5. Evidence and error diagnostics are retained separately from public source code and secrets.

## Next discovery

- Capture the StudentConsulting application flow using an authenticated browser session owned by the user.
- Identify whether application actions use stable supported web forms or internal JSON requests.
- Map StudentConsulting job fields to the normalized internal job model.
