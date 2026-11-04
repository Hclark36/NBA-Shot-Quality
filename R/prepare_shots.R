# Validate downloaded shots and create modeling features.

prepare_shots <- function(shots) {
  
  required <- c(
    "shot_id", "game_id", "season",
    "player_id", "player_name",
    "period", "seconds_remaining",
    "shot_type", "shot_distance",
    "loc_x", "loc_y",
    "shot_attempted_flag", "shot_made_flag"
  )
  
  missing <- setdiff(required, names(shots))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  d <- as.data.frame(shots, stringsAsFactors = FALSE)
  
  if (nrow(d) == 0L) {
    stop("No shots were supplied.")
  }
  
  # These are archive source-row IDs, not official NBA event IDs.
  # Stop on repeated IDs rather than guessing which shots to remove.
  if (
    anyNA(d$shot_id) ||
    any(!nzchar(as.character(d$shot_id))) ||
    anyDuplicated(d$shot_id) > 0L
  ) {
    stop("Missing or duplicate source shot IDs. Check the downloads.")
  }
  
  # Preserve leading zeros in NBA game identifiers.
  d$game_id <- as.character(d$game_id)
  d$season <- as.character(d$season)
  
  if (
    anyNA(d$game_id) ||
    any(!grepl("^002[0-9]{7}$", d$game_id))
  ) {
    stop("Expected regular-season NBA game IDs with leading zeros.")
  }
  
  if (
    anyNA(d$season) ||
    any(!grepl("^[0-9]{4}-[0-9]{2}$", d$season))
  ) {
    stop("Invalid season labels.")
  }
  
  start_year <- as.integer(substr(d$season, 1, 4))
  
  expected_end <- sprintf(
    "%02d",
    (start_year + 1L) %% 100L
  )
  
  if (
    any(substr(d$season, 6, 7) != expected_end) ||
    any(substr(d$game_id, 4, 5) != substr(d$season, 3, 4))
  ) {
    stop("Game IDs and season labels do not agree.")
  }
  
  # Convert numeric fields explicitly.
  numeric_columns <- c(
    "player_id", "period", "seconds_remaining",
    "shot_distance", "loc_x", "loc_y",
    "shot_attempted_flag", "shot_made_flag"
  )
  
  for (name in numeric_columns) {
    original <- d[[name]]
    
    converted <- suppressWarnings(
      as.numeric(as.character(original))
    )
    
    if (any(!is.na(original) & is.na(converted))) {
      stop("Unexpected text in column: ", name)
    }
    
    d[[name]] <- converted
  }
  
  # Validate the outcome and confirm every row is a field-goal attempt.
  if (
    any(
      !is.finite(d$shot_made_flag) |
      !d$shot_made_flag %in% c(0, 1)
    ) ||
    any(
      !is.finite(d$shot_attempted_flag) |
      d$shot_attempted_flag != 1
    )
  ) {
    stop("Expected field-goal attempts with binary make/miss outcomes.")
  }
  
  if (
    anyNA(d$shot_type) ||
    any(!d$shot_type %in% c("2PT Field Goal", "3PT Field Goal"))
  ) {
    stop("Unexpected shot types. This model excludes free throws.")
  }
  
  # Record exclusions rather than silently dropping observations.
  d$exclusion_reason <- NA_character_
  
  missing_features <- (
    !is.finite(d$loc_x) |
      !is.finite(d$loc_y) |
      !is.finite(d$shot_distance) |
      !is.finite(d$period) |
      !is.finite(d$seconds_remaining)
  )
  
  d$exclusion_reason[missing_features] <-
    "Missing or non-finite shot features"
  
  # Regulation periods last 720 seconds; overtime lasts 300 seconds.
  period_limit <- ifelse(d$period <= 4, 720, 300)
  
  bad_values <- !missing_features & (
    d$shot_distance < 0 |
      d$period < 1 |
      d$period != floor(d$period) |
      d$seconds_remaining < 0 |
      d$seconds_remaining > period_limit
  )
  
  d$exclusion_reason[bad_values] <-
    "Invalid distance, period, or game clock"
  
  excluded <- d[!is.na(d$exclusion_reason), ]
  clean <- d[is.na(d$exclusion_reason), ]
  clean$exclusion_reason <- NULL
  
  if (nrow(clean) == 0L) {
    stop("No usable shots remain after validation.")
  }
  
  # Legacy court coordinates are in tenths of a foot.
  clean$x_ft <- clean$loc_x / 10
  clean$y_ft <- clean$loc_y / 10
  
  clean$is_three <- as.integer(
    clean$shot_type == "3PT Field Goal"
  )
  
  clean$shot_value <- ifelse(clean$is_three == 1L, 3L, 2L)
  clean$is_overtime <- as.integer(clean$period > 4)
  
  # This is time left in the period, NOT the shot clock.
  clean$period_seconds_remaining <- clean$seconds_remaining
  
  # Outcomes for evaluation and reporting, never model predictors.
  clean$shot_made <- as.integer(clean$shot_made_flag)
  clean$actual_points <- clean$shot_value * clean$shot_made
  
  audit <- data.frame(
    stage = c(
      "Downloaded regular-season shots",
      "Excluded feature rows",
      "Ready for modeling"
    ),
    shots = c(
      nrow(d),
      nrow(excluded),
      nrow(clean)
    )
  )
  
  list(
    shots = clean,
    audit = audit,
    excluded = excluded
  )
}