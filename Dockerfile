# Jobb as a self-hosted container. Build from the repo root:
#   docker build -t jobb .
# The Worker and its Workflow run in workerd (the Cloudflare Workers runtime)
# through `wrangler dev --local`; D1, R2 and the workflow state live under
# /data, so keep that directory on a volume. The source has only placeholders;
# the entrypoint fills them in from the container environment.
#
# BROWSER_MODE=bundled (default) uses the Chrome installed below, so job
# searches work without any Cloudflare account.
FROM node:26.13.0-trixie-slim@sha256:e4db4c914bf8ad241bd24804fc25d272d89bad97e68cdc8a1414862790a02c39

ENV NODE_ENV=production \
    WRANGLER_SEND_METRICS=false \
    CI=true \
    XDG_CACHE_HOME=/opt/cache \
    PORT=8787

WORKDIR /opt/app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json apps/web/
COPY packages ./packages
# The pnpm version comes from packageManager in package.json.
RUN npx --yes "$(node -p "require('./package.json').packageManager.split('+')[0]")" install --frozen-lockfile && \
    rm -rf /root/.npm /root/.cache
COPY tools ./tools
COPY apps/web ./apps/web
COPY migrations ./migrations
COPY cloudflare.example.env ./
COPY docker ./docker
RUN find apps packages -name '*.test.ts' -delete

# Chrome for local Browser Rendering, at the exact version and cache path that
# wrangler's local browser uses, plus the system libraries it needs (apt);
# unzip is only needed to unpack Chrome.
RUN version=$(grep -ho 'BROWSER_VERSION = "[0-9.]*"' node_modules/.pnpm/miniflare@*/node_modules/miniflare/dist/src/index.js | head -1 | cut -d'"' -f2) && \
    test -n "$version" && \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates fonts-liberation fonts-noto-color-emoji libasound2t64 libatk-bridge2.0-0t64 \
      libatk1.0-0t64 libcairo2 libcups2t64 libdbus-1-3 libdrm2 libexpat1 libfontconfig1 libgbm1 \
      libglib2.0-0t64 libgtk-3-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 libx11-xcb1 libxcb1 \
      libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxkbcommon0 \
      libxrandr2 libxrender1 libxss1 libxtst6 unzip && \
    npx --yes @puppeteer/browsers@3.2.6 install "chrome@$version" --path /opt/cache/.wrangler && \
    apt-get purge -y unzip && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /root/.npm && \
    /opt/cache/.wrangler/chrome/linux-$version/chrome-linux64/chrome --version

RUN mkdir -p /data /srv && chown -R node:node /data /srv /opt/cache /opt/app/node_modules \
    /opt/app/apps/web/node_modules
USER node
VOLUME /data
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/api/health').then(r=>process.exit(r.status<500?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/opt/app/docker/entrypoint.sh"]
