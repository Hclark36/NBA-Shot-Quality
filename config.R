config <- list(
  
  # Reproducibility
  seed = 36L,
  
  # Train on earlier seasons and evaluate on later seasons.
  # These are fixed historical windows, not an automatic "latest" setting.
  train_seasons = c("2022-23", "2023-24"),
  validation_seasons = "2024-25",
  test_seasons = "2025-26",
  
  # Player selection affects reports, NOT league-wide model training.
  # NULL = generate results for all available players.
  # Replace NULL with an NBA player ID to generate one player's report.
  selected_player_id = NULL,
  
  # Minimum attempts for player comparison tables.
  # This does not remove shots from model training.
  min_player_attempts = 100L,
  
  # Initial model uses shot characteristics rather than player identity.
  model_features = c(
    "x_ft",
    "y_ft",
    "shot_distance",
    "is_three",
    "period",
    "period_seconds_remaining"
  ),
  
  # API request settings
  timeout_seconds = 30,
  max_retries = 3L,
  request_pause_seconds = 1,
  
  # Project-relative file locations
  paths = list(
    raw = "data/raw",
    processed = "data/processed",
    models = "output/models",
    tables = "output/tables",
    figures = "output/figures"
  )
)

# Combined seasons needed for downloading.
config$download_seasons <- unique(c(
  config$train_seasons,
  config$validation_seasons,
  config$test_seasons
))

# Prevent accidental overlap between evaluation groups.
stopifnot(
  length(intersect(
    config$train_seasons,
    config$validation_seasons
  )) == 0L,
  
  length(intersect(
    config$train_seasons,
    config$test_seasons
  )) == 0L,
  
  length(intersect(
    config$validation_seasons,
    config$test_seasons
  )) == 0L
)