# Split by season, keeping every shot from a game together.

split_data <- function(shots, cfg) {
  
  required <- c("shot_id", "game_id", "season")
  missing <- setdiff(required, names(shots))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(shots) == 0L || anyNA(shots[required])) {
    stop("Shot data is empty or contains missing identifiers.")
  }
  
  if (anyDuplicated(shots$shot_id) > 0L) {
    stop("Duplicate shot IDs found.")
  }
  
  seasons <- list(
    train = as.character(cfg$train_seasons),
    validation = as.character(cfg$validation_seasons),
    test = as.character(cfg$test_seasons)
  )
  
  if (any(lengths(seasons) == 0L)) {
    stop("Specify seasons for training, validation, and testing.")
  }
  
  assigned <- unlist(seasons, use.names = FALSE)
  
  if (anyNA(assigned) || anyDuplicated(assigned) > 0L) {
    stop("Season assignments must be nonmissing and cannot overlap.")
  }
  
  if (any(!grepl("^[0-9]{4}-[0-9]{2}$", assigned))) {
    stop("Use season labels such as 2025-26.")
  }
  
  starts <- lapply(
    seasons,
    function(x) as.integer(substr(x, 1, 4))
  )
  
  if (
    max(starts$train) >= min(starts$validation) ||
    max(starts$validation) >= min(starts$test)
  ) {
    stop("Training must precede validation, which must precede testing.")
  }
  
  absent <- setdiff(assigned, unique(shots$season))
  
  if (length(absent) > 0L) {
    stop("Missing requested seasons: ", paste(absent, collapse = ", "))
  }
  
  unassigned <- setdiff(unique(shots$season), assigned)
  
  if (length(unassigned) > 0L) {
    stop(
      "Seasons without a split assignment: ",
      paste(unassigned, collapse = ", ")
    )
  }
  
  # A game cannot belong to multiple seasons.
  game_seasons <- unique(shots[c("game_id", "season")])
  
  if (anyDuplicated(game_seasons$game_id) > 0L) {
    stop("A game ID appears under multiple seasons.")
  }
  
  splits <- lapply(
    seasons,
    function(years) {
      shots[shots$season %in% years, , drop = FALSE]
    }
  )
  
  games <- lapply(
    splits,
    function(x) unique(x$game_id)
  )
  
  if (
    length(intersect(games$train, games$validation)) > 0L ||
    length(intersect(games$train, games$test)) > 0L ||
    length(intersect(games$validation, games$test)) > 0L
  ) {
    stop("A game appears in more than one split.")
  }
  
  splits$summary <- data.frame(
    split = names(seasons),
    seasons = vapply(
      seasons,
      paste,
      collapse = ", ",
      FUN.VALUE = character(1)
    ),
    shots = vapply(splits, nrow, integer(1)),
    games = vapply(games, length, integer(1))
  )
  
  splits
}