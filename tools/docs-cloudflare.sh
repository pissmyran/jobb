#!/bin/sh
# Builds the documentation site for Cloudflare (Workers Builds build command:
# `sh tools/docs-cloudflare.sh`). The Worker in wrangler.docs.jsonc serves it
# under /docs on the app's own host, so the pages go in site-cf/docs/.
set -eu
python3 -m venv .venv-docs
.venv-docs/bin/pip install --quiet --no-deps -r requirements-docs.txt
node tools/docs-site.mjs
.venv-docs/bin/zensical build --clean
rm -rf site-cf
mkdir -p site-cf
cp -r site site-cf/docs
