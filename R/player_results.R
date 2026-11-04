# Summarize actual versus expected field-goal scoring by player.

summarize_players <- function(scored_shots, min_attempts = 100L) {
  
  required <- c(
    "player_id",
    "player_name",
    "season",
    "game_id",
    "shot_made",
    "make_probability",
    "actual_points",
    "expected_points"
  )
  
  missing <- setdiff(required, names(scored_shots))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(scored_shots) == 0L) {
    stop("No scored shots were supplied.")
  }
  
  if (
    length(min_attempts) != 1L ||
    !is.finite(min_attempts) ||
    min_attempts < 1 ||
    min_attempts != floor(min_attempts)
  ) {
    stop("min_attempts must be a positive whole number.")
  }
  
  if (
    anyNA(scored_shots$player_id) ||
    anyNA(scored_shots$season) ||
    anyNA(scored_shots$game_id)
  ) {
    stop("Player, season, and game identifiers cannot be missing.")
  }
  
  numeric_fields <- c(
    "shot_made",
    "make_probability",
    "actual_points",
    "expected_points"
  )
  
  for (name in numeric_fields) {
    if (
      !is.numeric(scored_shots[[name]]) ||
      any(!is.finite(scored_shots[[name]]))
    ) {
      stop("Column must contain finite numeric values: ", name)
    }
  }
  
  if (
    any(!scored_shots$shot_made %in% c(0, 1)) ||
    any(
      scored_shots$make_probability < 0 |
      scored_shots$make_probability > 1
    )
  ) {
    stop("Invalid outcomes or probabilities.")
  }
  
  # Group by NBA ID, not by name.
  # Names are display labels only.
  players <- scored_shots |>
    dplyr::group_by(player_id, season) |>
    dplyr::summarise(
      player_name = {
        labels <- as.character(player_name)
        labels <- labels[
          !is.na(labels) & nzchar(trimws(labels))
        ]
        
        if (length(labels)) labels[1] else "Unknown"
      },
      
      games_with_shots = dplyr::n_distinct(game_id),
      attempts = dplyr::n(),
      makes = sum(shot_made),
      
      actual_fg_pct = mean(shot_made),
      expected_fg_pct = mean(make_probability),
      
      actual_points = sum(actual_points),
      expected_points = sum(expected_points),
      
      .groups = "drop"
    ) |>
    dplyr::mutate(
      fg_above_expected_pp = 100 * (
        actual_fg_pct - expected_fg_pct
      ),
      
      points_above_expected = actual_points - expected_points,
      
      points_above_expected_per_100 = (
        100 * points_above_expected / attempts
      ),
      
      eligible_for_comparison = attempts >= min_attempts
    ) |>
    dplyr::arrange(
      dplyr::desc(points_above_expected_per_100)
    )
  
  players
}


# Retrieve one player's shots without retraining the model.
select_player_shots <- function(scored_shots, player_id) {
  
  if (
    length(player_id) != 1L ||
    is.na(player_id)
  ) {
    stop("Provide one NBA player ID.")
  }
  
  selected <- scored_shots[
    as.character(scored_shots$player_id) ==
      as.character(player_id),
    ,
    drop = FALSE
  ]
  
  if (nrow(selected) == 0L) {
    stop("No shots found for player ID: ", player_id)
  }
  
  selected
}