# QUEFTS Decision Support API -- Plumber, deployed to Railway.
#
# UNTESTED: written without a local Docker install to build/verify against
# (see PROJECT_TRACKER.md Phase 9) -- review the first build's output
# carefully, especially the renv::restore() step below.
#
# Build context must be the PROJECT ROOT, not api/, since this needs R/,
# data/, renv.lock, .Rprofile, and renv/ from outside this directory:
#   docker build -f api/Dockerfile -t quefts-api .
# Railway is configured (see railway.json) to do this automatically.

# rocker/geospatial ships GDAL/GEOS/PROJ and their R bindings (sf/terra/
# raster) already compiled against matching system libraries, which avoids
# needing to apt-get install and configure those separately -- the tag
# matches this project's pinned R version (renv.lock).
FROM rocker/geospatial:4.5.2

WORKDIR /app

# Install dependencies first (from renv.lock + the renv infrastructure
# renv::init() generated in Phase 1) so this expensive layer is cached
# across builds that only change application code below.
COPY renv.lock .Rprofile ./
COPY renv/activate.R renv/settings.json ./renv/

RUN R -e "install.packages('renv', repos = 'https://packagemanager.posit.co/cran/latest')" \
 && R -e "renv::restore()"

# Application code and data (not web/, dev-history/, docs/, experimental/,
# tests/ -- none of which the running API needs).
COPY R/ ./R/
COPY data/ ./data/
COPY api/ ./api/

# Railway injects PORT at runtime; HOST must be 0.0.0.0 so the container's
# proxy can reach it (its own loopback interface, 127.0.0.1 -- the local-dev
# default in api/run_api.R -- isn't reachable from outside the container).
ENV HOST=0.0.0.0
EXPOSE 8000

CMD ["Rscript", "api/run_api.R"]
