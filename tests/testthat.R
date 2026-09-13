# Test runner for the Quefts-app testthat suite.
#
# Run from the project root so renv activates and every source() call
# inside the sourced R/ files (which use project-root-relative paths)
# resolves correctly:
#
#   Rscript tests/testthat.R
#
# testthat::test_dir() auto-sources every tests/testthat/helper-*.R file
# once before running the tests/testthat/test-*.R files.

library(testthat)

# testthat::test_dir() may change the working directory while it runs, so
# capture the project root now (this script must be launched with the repo
# root as cwd) and hand it to the helper via an env var, rather than relying
# on relative paths inside the helper/test files.
Sys.setenv(QUEFTS_PROJECT_ROOT = normalizePath("."))

test_dir("tests/testthat", reporter = "summary")
