# Automation

Manual and scheduled runs use the same pipeline and the same rules. The interface is in Swedish; button names are given as they appear, with a translation.

## The dashboard

The dashboard at `/` has five views:

- **Översikt** (overview): the monthly goal, ten result slots that are only filled by verified applications, the monthly files with **Ladda ner .txt** (download .txt) and **Skicka med e-post** (send by email), and what needs attention. Reserved but uncertain slots are shown separately as blocks, not as finished applications.
- **Ansökningar** (applications): every application with filters, link to its run, latest error and number of evidence items. An application in `needs_user_action` can be checked against StudentConsulting again (**Kontrollera igen**, check again) or marked as not submitted (**Markera ej inskickad**). Only StudentConsulting's own confirmation can make an application verified.
- **Körningar** (runs): the history with details on applications, attempts, evidence, sending and integration checks. An active run can be stopped, and a finished run without applications can be deleted.
- **Månadsfiler** (monthly files): every monthly file and a calendar marking days with verified applications and the day the file was finished.
- **System:** the status of the settings, the settings form and the send history. Saved secrets are never shown again.

On mobile the tables are shown as cards.

## Manual run

**Kör nu** (run now) works on the 1st–14th of every month (`Europe/Stockholm`). Outside that window the button is disabled and the API rejects the start. A manual start requires sign-in, the same origin, a saved StudentConsulting account and `STUDENTCONSULTING_AUTOSUBMIT` turned on.

The start claims the run in D1 in a single step, and only if no other run is `running`. Two tabs, or a tab and the schedule, can therefore never start two runs at once. The Workflow instance id is saved immediately, and errors in the Workflow are written back as `failed`.

## Scheduled run

Cron starts the Worker at 09:00 UTC on the 10th–13th, that is 10 or 11 o'clock Swedish time.

- **On the 10th** the month's regular run happens, `scheduled:YYYY-MM`.
- **On the 11th–13th** a new attempt is made only if that run is still `failed`. A run that is finished or in progress is not restarted.
- **On the 14th and the rest of the month** no automatic searches happen.

A run first counts how many applications are already verified this month, then only applies to suitable jobs, and creates and emails the monthly file once ten are verified.

## The monthly limit

`0004_monthly_application_quota.sql` creates ten slots per month, and a slot is reserved **before** the application is sent.

- **Safe failure before anything was sent:** the slot is released. The same run may try again with the same application, but only if it is still `failed` and has neither `applied_at` nor `verified_at`. The attempt gets the next number, and the history stays on the run.
- **Submitted:** the slot is kept.
- **Verified:** the slot is marked as verified.
- **Unclear result:** the slot is kept as `uncertain`. No replacement is sent, since it could become number eleven.

Jobb therefore never knowingly sends more than ten applications in a calendar month. An unclear result shows in the dashboard and blocks further applications until it is resolved, with **Kontrollera igen** (check again) or **Markera ej inskickad** (mark as not submitted). The latter releases the block but never counts as a successful application.

## Error codes

Every attempt saves an error code and StudentConsulting's message:

| Code | Meaning |
| --- | --- |
| `APPLICATION_FAILED` | StudentConsulting rejected the application, or it failed. |
| `APPLICATION_UNKNOWN` | It could not be determined safely whether the application was sent. |
| `APPLICATION_REQUIRES_INPUT` | The application has a required field Jobb cannot fill in. Retried once per run. |
| `VERIFICATION_FAILED` | The application was reported as sent, but the job ID was not among the applications. |
| `UNEXPECTED_APPLICATION_ERROR` | The browser or the code gave an unexpected error. |
| `RUN_STOPPED_BY_USER` | The run was stopped in the dashboard. |

Safe failures before anything was sent can be retried in later runs, even if the job is no longer in *Matcha jobb*.

## Settings

Every setting can be set as a variable on the Worker or saved under **System**. Variables on the Worker win.

| Name | Meaning |
| --- | --- |
| `STUDENTCONSULTING_EMAIL`, `STUDENTCONSULTING_PASSWORD` | The account at StudentConsulting. |
| `STUDENTCONSULTING_AUTOSUBMIT` | `true` turns on sending applications. Off by default. |
| `JOB_INCLUDE_TERMS` | Optional: only jobs that contain one of the words, for example `supporttekniker,helpdesk`. |
| `JOB_EXCLUDE_TERMS` | Optional: skip jobs that contain one of the words, for example `chef,senior`. |
| `JOB_ALLOWED_LOCATIONS` | Optional: only these cities, for example `Stockholm,Uppsala`. |
| `JOB_ALLOWED_COUNTRIES` | Optional: only these countries, for example `SE,NO,DK`. |
| `NOTIFY_EMAIL_TO` | One or more recipients of the monthly file, comma separated. |
| `NOTIFY_EMAIL_FROM` | The sender address. |
| `NOTIFY_EMAIL_MODE` | `group` (one shared email) or `separate` (one email per recipient). |

`CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD` and `PUBLIC_BASE_URL` are set at deployment. `JOBB_CONFIG_KEY` lives in Secrets Store, and `JOBB_CONFIG_KEY_PREVIOUS` is only needed during a key rotation.

## The monthly file and email

As soon as the month has ten verified applications, a text file is saved in the D1 table `activity_report_exports`. Each job gets four lines:

- **Job ID**
- **Job type:** the occupation, or the occupation word in the title when StudentConsulting only gives a category such as "Logistik / Transport"
- **City**
- **Extent:** from the listing, otherwise full time, part time or extra job from the title

The file is named `jobbansokningar_YYYY-MM-DD.txt` after the day the tenth application was verified. It is fetched from `GET /api/reports/:month/export.txt` and sent with `POST /api/reports/:month/email`.

A new file is emailed automatically if recipients are set. The file is attached and also included in the body. Every send is logged in `notifications` (`kind = export_email`), and a failed send never fails the run.

## Historical gaps

A separate path in the Workflow can read the signed-in history at StudentConsulting and add applications that are missing for an explicitly chosen month. It only adds what StudentConsulting itself shows and never sends a new application. If the month then has ten applications, the monthly file is created.

## API

| Request | Does |
| --- | --- |
| `GET /api/health` | Answers whether the Worker is alive. |
| `GET /api/ready` | Checks D1, that sign-in is configured and that `JOBB_CONFIG_KEY` can be read. Does not call StudentConsulting and shows no secrets. |
| `GET /api/dashboard` | Everything the dashboard shows, without secrets. |
| `POST /api/configuration` | Saves the settings encrypted. |
| `POST /api/runs/manual` | Starts a manual run. |
| `GET /api/runs/:id` | Details of a run. |
| `POST /api/runs/:id/stop` | Stops an active run. |
| `DELETE /api/runs/:id` | Deletes a finished run without applications. |
| `POST /api/applications/:id/recheck` | Checks an application against StudentConsulting again. |
| `POST /api/applications/:id/not-submitted` | Confirms that an uncertain application was not sent. |
| `GET /api/reports/:month/export.txt` | The monthly file. |
| `POST /api/reports/:month/email` | Emails the monthly file. |
| `POST /auth/logout` | Signs out through Cloudflare Access. |

Every request except `/api/health` and `/api/ready` requires sign-in, and every changing request requires the same origin.
