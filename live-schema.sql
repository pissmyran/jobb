-- D1-schema för jobb, läst från sqlite_master 2026-10-16. Endast struktur, ingen data.

CREATE TABLE activity_report_exports (
  report_month TEXT PRIMARY KEY,
  target_count INTEGER NOT NULL CHECK (target_count > 0),
  item_count INTEGER NOT NULL CHECK (item_count >= 0),
  content_text TEXT NOT NULL,
  ready_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE application_attempts (
  id TEXT PRIMARY KEY,
  application_id TEXT NOT NULL REFERENCES applications(id),
  attempt_no INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('started','submitted','verified','failed','unknown')),
  error_code TEXT,
  error_message TEXT,
  started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TEXT,
  UNIQUE(application_id, attempt_no)
);

CREATE TABLE applications (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL REFERENCES jobs(id),
  status TEXT NOT NULL CHECK (status IN ('queued','applying','submitted','verified','failed','needs_user_action')),
  applied_at TEXT,
  verified_at TEXT,
  report_month TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, automation_run_id TEXT,
  UNIQUE(job_id)
);

CREATE TABLE automation_runs (
  id TEXT PRIMARY KEY,
  mode TEXT NOT NULL CHECK (mode IN ('manual','scheduled')),
  application_month TEXT NOT NULL,
  report_month TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('running','needs_user_auth','completed','failed')),
  target_count INTEGER NOT NULL DEFAULT 10 CHECK (target_count > 0),
  verified_count INTEGER NOT NULL DEFAULT 0 CHECK (verified_count >= 0),
  workflow_instance_id TEXT,
  auth_session_id TEXT,
  auth_live_view_url TEXT,
  auth_expires_at TEXT,
  last_notified_at TEXT,
  last_error TEXT,
  started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "d1_migrations"(
		id         INTEGER PRIMARY KEY AUTOINCREMENT,
		name       TEXT UNIQUE,
		applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE evidence (
  id TEXT PRIMARY KEY,
  application_id TEXT NOT NULL REFERENCES applications(id),
  kind TEXT NOT NULL,
  object_key TEXT NOT NULL,
  sha256 TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE integration_probes (
  id TEXT PRIMARY KEY,
  automation_run_id TEXT NOT NULL REFERENCES automation_runs(id),
  integration TEXT NOT NULL CHECK (integration IN ('arbetsformedlingen_activity_report')),
  status TEXT NOT NULL CHECK (status IN ('capturing','captured','failed')),
  page_url TEXT,
  object_key TEXT,
  summary_json TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (automation_run_id, integration)
);

CREATE TABLE jobs (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  employer TEXT,
  location TEXT,
  country_code TEXT,
  is_international INTEGER NOT NULL DEFAULT 0 CHECK (is_international IN (0, 1)),
  source_url TEXT NOT NULL,
  raw_json TEXT,
  discovered_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(provider, external_id)
);

CREATE TABLE monthly_application_slots (
  report_month TEXT NOT NULL,
  slot_no INTEGER NOT NULL CHECK (slot_no BETWEEN 1 AND 10),
  application_id TEXT UNIQUE,
  reservation_owner TEXT,
  state TEXT NOT NULL DEFAULT 'free'
    CHECK (state IN ('free','reserved','submitted','verified','uncertain')),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (report_month, slot_no)
);

CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  automation_run_id TEXT NOT NULL REFERENCES automation_runs(id),
  kind TEXT NOT NULL CHECK (kind IN ('bankid_required','run_failed','run_completed')),
  channel TEXT NOT NULL CHECK (channel IN ('email','webhook')),
  status TEXT NOT NULL CHECK (status IN ('sent','failed')),
  error_message TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE report_activity_items (
  report_month TEXT NOT NULL,
  application_id TEXT NOT NULL REFERENCES applications(id),
  external_id TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending','save_attempted','saved')),
  last_error TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (report_month, application_id),
  UNIQUE (report_month, external_id)
);

CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  report_month TEXT NOT NULL UNIQUE,
  target_count INTEGER NOT NULL DEFAULT 10 CHECK (target_count > 0),
  status TEXT NOT NULL CHECK (status IN ('collecting','ready','needs_user_auth','submitting','submitted','failed')),
  submitted_at TEXT,
  external_reference TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE runtime_configuration (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    ciphertext TEXT NOT NULL,
    iv TEXT NOT NULL,
    schema_version INTEGER NOT NULL DEFAULT 1 CHECK (schema_version > 0),
    updated_by_github_id INTEGER,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

CREATE INDEX idx_activity_report_exports_ready_at
  ON activity_report_exports(ready_at);

CREATE INDEX idx_applications_report_month_status ON applications(report_month, status);

CREATE INDEX idx_attempts_application ON application_attempts(application_id, attempt_no);

CREATE INDEX idx_automation_runs_month_mode
  ON automation_runs(application_month, mode, started_at DESC);

CREATE INDEX idx_automation_runs_status
  ON automation_runs(status, updated_at DESC);

CREATE INDEX idx_integration_probes_run
  ON integration_probes(automation_run_id, updated_at DESC);

CREATE INDEX idx_monthly_application_slots_application
  ON monthly_application_slots(application_id);

CREATE INDEX idx_monthly_application_slots_owner
  ON monthly_application_slots(report_month, reservation_owner);

CREATE INDEX idx_notifications_run
  ON notifications(automation_run_id, created_at DESC);

CREATE INDEX idx_report_activity_items_state
  ON report_activity_items(report_month, state);
