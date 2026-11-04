if (!file.exists("config.R")) {
  stop(
    "Cannot find config.R. Open your project's .Rproj file ",
    "and run this script from the main project folder."
  )
}

source("config.R")

# Create the data and output folders.
for (folder in unlist(config$paths, use.names = FALSE)) {
  dir.create(
    folder,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

# Keep installed packages in this project.
dir.create(".Rlib", showWarnings = FALSE)

.libPaths(c(
  normalizePath(".Rlib"),
  .libPaths()
))

# Packages for the initial pipeline.
packages <- c(
  "httr2",      # API requests
  "jsonlite",   # Read and write JSON
  "digest",     # File checksums
  "dplyr",      # Data preparation
  "tidyr",     # Reshape data
  "mgcv",      # Spatial GAM model
  "ggplot2",   # Charts and court maps
  "plotly",    # Interactive charts
  "crosstalk", # Linked dashboard filters
  "htmltools", # HTML components
  "knitr",     # Report execution
  "rmarkdown", # Report dependencies
  "testthat"   # Pipeline tests
)

# Identify packages that still need installation.
installed <- vapply(
  packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)

missing <- packages[!installed]

# Preserve an existing package mirror where available.
repos <- getOption("repos")

if (is.null(repos) || length(repos) == 0L) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

repos[repos == "@CRAN@"] <- "https://cloud.r-project.org"

if (length(missing) > 0L) {
  install.packages(
    missing,
    lib = ".Rlib",
    repos = repos
  )
}

# Confirm installation succeeded.
unavailable <- packages[
  !vapply(
    packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
]

if (length(unavailable) > 0L) {
  stop(
    "Packages still missing: ",
    paste(unavailable, collapse = ", "),
    ". Check the installation messages above."
  )
}

cat("\nSetup complete!\n")
cat("Project folder:", getwd(), "\n")
cat("Packages and data folders are ready.\n")