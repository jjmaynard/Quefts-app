# Deploying Quefts-app

Two independently-deployed pieces, per `PROJECT_TRACKER.md` Phase 9:

- **API** (`api/`, R/Plumber) → [Railway](https://railway.com)
- **Frontend** (`web/`, Next.js) → [Vercel](https://vercel.com)

> **This guide is untested.** It was written without a Railway or Vercel
> account, or a local Docker install, to actually deploy and verify against
> (see `PROJECT_TRACKER.md` Phase 9 for why). Treat `api/Dockerfile` and the
> steps below as a well-reasoned starting point, not a proven path — the
> first real deployment attempt is the actual test.

## 1. Deploy the API to Railway

Railway builds `api/Dockerfile` (repo root as build context — see
`railway.json`, which points Railway at it automatically once the repo is
connected).

1. In Railway, create a new project → **Deploy from GitHub repo** → select
   this repository.
2. Railway should detect `railway.json` and build `api/Dockerfile`
   automatically. If it doesn't, set the build method to "Dockerfile" and
   the Dockerfile path to `api/Dockerfile` manually in the service's
   Settings → Build tab.
3. Set environment variables on the service (Settings → Variables):
   - `ALLOWED_ORIGIN` — set this **after** step 2.3 below gives you the
     Vercel production URL (e.g. `https://your-app.vercel.app`). Leaving it
     unset defaults to `*` (any origin), which works but isn't appropriate
     to leave that way once you have a real frontend URL.
   - Railway sets `PORT` itself; you don't need to.
4. Deploy. Railway will show a generated public URL
   (`https://<something>.up.railway.app`) — that's your API's base URL.
5. Verify it's actually working before moving on:
   ```
   curl https://<your-app>.up.railway.app/health
   curl https://<your-app>.up.railway.app/crops
   ```

### Known limitation: result persistence doesn't survive redeploys

`POST /recommendation` saves each result to `api/.cache/results/*.json`
(Phase 8, for the shareable `/results/[id]` pages) on the container's local
filesystem. Railway's filesystem is ephemeral by default — every redeploy
(including ones triggered by a new git push) starts from a fresh
filesystem, so **previously shared `/results/[id]` links will 404 after any
redeploy**. Results survive fine across requests within one running
deployment, just not across deployments.

If persistent share links matter, the fix is a
[Railway Volume](https://docs.railway.com/reference/volumes) mounted at
`/app/api/.cache` (persists across redeploys), or migrating the result
store to an actual database — neither is implemented here; this is
flagged as a known gap, not fixed, to keep this phase's scope to what was
asked (containerize + deploy, not redesign the persistence layer).

## 2. Deploy the frontend to Vercel

1. In Vercel, **Add New Project** → import this repository.
2. Vercel needs to know the Next.js app isn't at the repo root: set
   **Root Directory** to `web` in the project's Settings → General (or in
   the import wizard before the first deploy). Framework preset should
   auto-detect as Next.js once the root directory is set correctly.
3. Add an environment variable (Settings → Environment Variables):
   - `NEXT_PUBLIC_API_URL` = the Railway URL from step 1.4 (e.g.
     `https://your-app.up.railway.app`) -- no trailing slash.
4. Deploy. Vercel gives you a production URL
   (`https://<your-app>.vercel.app`).
5. Go back to Railway and set `ALLOWED_ORIGIN` (step 1.3) to this exact
   URL, then redeploy the API so the new CORS setting takes effect.

### Known limitation: CORS and preview deployments

`ALLOWED_ORIGIN` is a single origin string. Vercel also creates preview
deployments at per-branch/per-PR URLs
(`your-app-git-<branch>-<team>.vercel.app`), which won't match a single
production `ALLOWED_ORIGIN` and will be blocked by CORS when calling the
API. Fine for a production-only setup; if preview deployments need to call
the live API too, `api/plumber.R`'s CORS filter would need to check the
request's `Origin` header against a pattern (e.g. any `*.vercel.app`
subdomain) rather than a single fixed string.

## 3. Local, container-free verification (no Docker needed)

Before trying the Railway build, you can sanity-check the same code path
without Docker: run `Rscript api/run_api.R` locally (as in Phases 6-8),
confirm `/health`, `/crops`, and `POST /recommendation` all behave, then
separately confirm `web`'s production build (`npm run build && npm start`
in `web/`, with `NEXT_PUBLIC_API_URL` pointed at the local API) works
end-to-end. This doesn't test the Dockerfile or Railway/Vercel-specific
configuration, but rules out the application code itself as the source of
any deployment issue.

## 4. If the Docker build fails

Since this was never actually built, the most likely failure points, in
roughly descending order of likelihood:

- **`renv::restore()` timing out or failing to find binaries** for a
  package (most likely `sf`, `terra`, `raster`, or `Rquefts` on CRAN) for
  the exact R/OS combination `rocker/geospatial:4.5.2` provides. If this
  happens, the fix is almost always compiling from source instead of
  waiting for a binary (slower build, but should still succeed given
  `rocker/geospatial` already has the system GDAL/GEOS/PROJ libraries these
  packages need) -- check the actual build log for which package failed
  and why before assuming anything deeper is wrong.
- **Railway's build context.** If Railway doesn't pick up `railway.json`
  automatically, double check the build settings actually point
  `dockerfilePath` at `api/Dockerfile` with the repo root as context (not
  `api/` as context) -- the Dockerfile's `COPY R/ ./R/` etc. assume a
  root-level context.
