# Run from the repository root: Rscript tests/test-pipeline.R
if (dir.exists(".Rlib")) .libPaths(c(normalizePath(".Rlib"), .libPaths()))
library(testthat)
source("config.R")
for (file in c("prepare_shots", "split_data", "score_shots", "player_results"))
  source(file.path("R", paste0(file, ".R")))

# NBA game identifiers must retain their leading zeros.
raw <- read.csv("data/example/shots.csv", colClasses = c(game_id = "character"))
clean <- prepare_shots(raw)$shots
splits <- split_data(clean, config)
benchmark <- list(model_name = "fixture_benchmark", prediction_type = "constant",
  constant_probability = 0.25, features = character(),
  training_seasons = config$train_seasons, validation_seasons = config$validation_seasons)

test_that("cleaning preserves IDs, converts coordinates, and audits bad shots", {
  expect_identical(clean$game_id[1], "0022200001")
  expect_equal(clean$y_ft[1], 3)
  expect_equal(clean$actual_points, c(2, 0, 0, 3, 2, 0, 2, 0))
  bad <- raw
  bad$seconds_remaining[6] <- 301 # Overtime is only five minutes.
  audited <- prepare_shots(bad)
  expect_identical(audited$excluded$shot_id, "toy-6")
  expect_equal(nrow(audited$shots), 7L)
  bad$shot_id[2] <- bad$shot_id[1]
  expect_error(prepare_shots(bad), "duplicate source shot IDs")
})

test_that("chronological splits keep games together and reject leakage", {
  expect_equal(splits$summary$shots, c(4L, 2L, 2L))
  games <- lapply(splits[c("train", "validation", "test")], function(d) unique(d$game_id))
  expect_equal(length(unique(unlist(games))), sum(lengths(games)))
  bad <- config
  bad$validation_seasons <- config$train_seasons[1]
  expect_error(split_data(clean, bad), "cannot overlap")
  expect_error(evaluate_test(benchmark, splits$validation, config), "configured test seasons")
  bad$test_seasons <- config$validation_seasons
  expect_error(evaluate_test(benchmark, splits$validation, bad), "overlap training or validation")
})

test_that("expected points use shot value and aggregate correctly", {
  evaluated <- evaluate_test(benchmark, splits$test, config)
  shots <- evaluated$scored_shots
  expect_equal(shots$expected_points, c(0.5, 0.75))
  expect_equal(shots$points_above_expected, c(1.5, -0.75))
  expect_equal(evaluated$metrics$log_loss, -mean(log(c(0.25, 0.75))))
  expect_equal(evaluated$metrics$brier_score, 0.3125)
  summary <- summarize_players(shots, min_attempts = 3L)
  expect_equal(summary$points_above_expected_per_100, 37.5)
  expect_false(summary$eligible_for_comparison)
  expect_error(select_player_shots(shots, 123456L), "No shots found")
  shots$player_id[2] <- 1002L # Identical labels still represent different players.
  expect_equal(nrow(summarize_players(shots)), 2L)
})
