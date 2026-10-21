#!/usr/bin/env node
// Assembles the source of the documentation site in site-docs/ for Zensical:
//
//   node tools/docs-site.mjs && zensical build
//
// README.md becomes the start page and docker/README.md the Docker page; docs/
// is copied as it is, except docs/agents/, which is written for coding agents.
// Links between those files are rewritten to the site's own pages, and links to
// anything else in the repo point to the file on GitHub, so every link works on
// the site. The repo address is repo_url in zensical.toml. The README line that
// links to the site itself ("**Dokumentation:** ...") is left out.
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { posix } from "node:path";

const out = "site-docs";
const repoUrl = readFileSync("zensical.toml", "utf8").match(/^repo_url\s*=\s*"([^"]+)"/m)?.[1];
if (!repoUrl) throw new Error("repo_url is missing in zensical.toml");

// Repo path -> path on the site.
const pages = new Map();
for (const [src, dst] of [
  ["README.md", "index.md"],
  ["docker/README.md", "docker.md"],
]) {
  if (existsSync(src)) pages.set(src, dst);
}
const walk = (dir) => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = posix.join(dir, entry.name);
    if (path === "docs/agents") continue;
    if (entry.isDirectory()) walk(path);
    else pages.set(path, path.slice("docs/".length));
  }
};
if (existsSync("docs")) walk("docs");

const link = (src, dst, target) => {
  if (/^([a-z]+:|#|\/)/i.test(target)) return target;
  const [path, anchor] = target.split("#", 2);
  const suffix = anchor === undefined ? "" : `#${anchor}`;
  const resolved = posix.normalize(posix.join(posix.dirname(src), path)).replace(/\/$/, "");
  const page = pages.get(resolved);
  if (page) return posix.relative(posix.dirname(dst), page) + suffix;
  return `${repoUrl}/blob/main/${resolved}${suffix}`;
};

const rewrite = (src, dst, text) => {
  let fenced = false;
  return text
    .split("\n")
    .filter((line) => !(src === "README.md" && line.startsWith("**Dokumentation:**")))
    .map((line) => {
      if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
      if (fenced) return line;
      return line.replace(
        /(\]\()([^)\s]+)((?:\s+"[^"]*")?\))/g,
        (_, open, target, close) => open + link(src, dst, target) + close,
      );
    })
    .join("\n");
};

rmSync(out, { recursive: true, force: true });
for (const [src, dst] of pages) {
  const target = posix.join(out, dst);
  mkdirSync(posix.dirname(target), { recursive: true });
  if (src.endsWith(".md")) writeFileSync(target, rewrite(src, dst, readFileSync(src, "utf8")));
  else cpSync(src, target);
}
console.log(`${out}/: ${pages.size} files`);
