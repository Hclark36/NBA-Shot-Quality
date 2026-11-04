if (!file.exists("config.R")) {
  stop("Open your project's .Rproj file before running this script.")
}

source("config.R")

if (dir.exists(".Rlib")) {
  .libPaths(c(normalizePath(".Rlib"), .libPaths()))
}

if (!requireNamespace("mgcv", quietly = TRUE)) {
  stop("Run scripts/setup.R to install the required packages.")
}

if (!file.exists("R/score_shots.R")) {
  stop("Create R/score_shots.R using the scoring code provided earlier.")
}

source("R/score_shots.R")

# Locate the saved data and selected model.
splits_path <- file.path(
  config$paths$processed,
  "shot_splits.rds"
)

model_path <- file.path(
  config$paths$models,
  "selected_shot_model.rds"
)

if (!file.exists(splits_path)) {
  stop("Missing shot_splits.rds. Run the data-splitting step first.")
}

if (!file.exists(model_path)) {
  stop("Missing selected_shot_model.rds. Run the validation step first.")
}

splits <- readRDS(splits_path)
selected_model <- readRDS(model_path)

cat("Selected model:", selected_model$model_name, "\n")
cat("Test seasons:", paste(config$test_seasons, collapse = ", "), "\n")

# Score the reserved test data.
test_results <- evaluate_test(
  selected_model = selected_model,
  test = splits$test,
  cfg = config
)

# Ensure output folders exist.
dir.create(
  config$paths$tables,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  config$paths$processed,
  recursive = TRUE,
  showWarnings = FALSE
)

# Save final performance metrics.
write.csv(
  test_results$metrics,
  file.path(
    config$paths$tables,
    "final_test_metrics.csv"
  ),
  row.names = FALSE
)

# Save individual shots with predicted probabilities,
# expected points, and points above expectation.
saveRDS(
  test_results$scored_shots,
  file.path(
    config$paths$processed,
    "scored_test_shots.rds"
  )
)

print(test_results$metrics)

cat("\nFinal test complete. Results saved.\n")