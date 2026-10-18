import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import test from "node:test";

const launcherUrl = new URL("../scripts/setup-provider-credentials.sh", import.meta.url);
const wizardUrl = new URL("../scripts/setup-provider-credentials.wizard.sh", import.meta.url);
const launcherPath = fileURLToPath(launcherUrl);
const wizardPath = fileURLToPath(wizardUrl);
const launcher = await readFile(launcherUrl, "utf8");
const wizard = await readFile(wizardUrl, "utf8");
const marker = "# STAGES: author this section.";
const stageOffset = wizard.indexOf(marker);
assert.notEqual(stageOffset, -1);
const stages = wizard.slice(stageOffset);

test("Jobb credential scripts have valid bash syntax", () => {
  for (const path of [launcherPath, wizardPath]) {
    const result = spawnSync("bash", ["-n", path], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
  }
});

test("Jobb keeps the curated helper and hardened launcher contract", () => {
  assert.match(launcher, /tput\(\)/);
  assert.match(launcher, /export -f tput/);
  assert.match(launcher, /exec bash "\$WIZARD"/);
  assert.doesNotMatch(launcher, /export TERM=dumb/);
});

test("Jobb credential stages are verification-only", () => {
  assert.doesNotMatch(stages, /^\s*(?:ask|ask_secret|write_env|set_secret|set_var)\s+/m);
  assert.doesNotMatch(stages, /\bgh\s+(?:secret|variable)\s+set\b/);
  assert.doesNotMatch(stages, /\bwrangler\s+secret\s+(?:put|bulk|delete)\b/);
  assert.doesNotMatch(stages, /\bwrangler\s+deploy\b/);
});

test("Jobb wizard covers its provider contract", () => {
  assert.match(stages, /Cloudflare Access/);
  assert.match(stages, /CF_ACCESS_AUD/);
  assert.match(stages, /JOBB_CONFIG_KEY/);
  assert.doesNotMatch(stages, /GITHUB_OAUTH|GitHub OAuth/);
  assert.match(stages, /STUDENTCONSULTING_EMAIL\/STUDENTCONSULTING_PASSWORD/);
  assert.match(stages, /STUDENTCONSULTING_AUTOSUBMIT/);
  assert.doesNotMatch(stages, /BankID/);
  assert.match(stages, /pnpm release/);
});
