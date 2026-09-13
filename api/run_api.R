# Starts the QUEFTS Decision Support API.
#
# Run from the project root, so renv activates and the root-relative
# source() call inside api/plumber.R resolves:
#
#   Rscript api/run_api.R
#
# Override the port with the PORT env var, e.g. PORT=9000 Rscript api/run_api.R

port <- as.integer(Sys.getenv("PORT", "8000"))

# plumber::plumb() evaluates api/plumber.R with the working directory set to
# api/ itself, not the caller's cwd -- so the root-relative source() call
# inside it can't just rely on getwd(). Pass the root through explicitly.
Sys.setenv(QUEFTS_PROJECT_ROOT = normalizePath("."))

pr <- plumber::plumb("api/plumber.R")
pr$run(host = "127.0.0.1", port = port)
