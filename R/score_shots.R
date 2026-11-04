# Apply a saved model to compatible shot data.

score_shots <- function(selected_model, shots) {
  
  required <- unique(c(
    selected_model$features,
    "is_three"
  ))
  
  missing <- setdiff(required, names(shots))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(shots) == 0L) {
    stop("No shots were supplied.")
  }
  
  for (name in required) {
    if (
      !is.numeric(shots[[name]]) ||
      any(!is.finite(shots[[name]]))
    ) {
      stop("Column must contain finite numeric values: ", name)
    }
  }
  
  if (!all(shots$is_three %in% c(0, 1))) {
    stop("is_three must contain only 0 and 1.")
  }
  
  if (identical(selected_model$prediction_type, "constant")) {
    
    probability <- rep(
      selected_model$constant_probability,
      nrow(shots)
    )
    
  } else if (
    identical(selected_model$prediction_type, "fitted")
  ) {
    
    probability <- as.numeric(stats::predict(
      selected_model$fit,
      newdata = shots,
      type = "response"
    ))
    
  } else {
    stop("Unknown model prediction type.")
  }
  
  if (
    length(probability) != nrow(shots) ||
    any(!is.finite(probability)) ||
    any(probability < 0 | probability > 1)
  ) {
    stop("The model returned invalid probabilities.")
  }
  
  scored <- shots
  
  scored$make_probability <- probability
  
  # Expected field-goal points, excluding free throws.
  scored$expected_points <- probability * ifelse(
    scored$is_three == 1L,
    3,
    2
  )
  
  scored
}


# Evaluate the frozen selection on the final test seasons.
evaluate_test <- function(selected_model, test, cfg) {
  
  required <- c("season", "shot_made")
  missing <- setdiff(required, names(test))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (
    anyNA(test$season) ||
    !setequal(unique(test$season), cfg$test_seasons)
  ) {
    stop("Supply only the configured test seasons.")
  }
  
  previously_used <- c(
    selected_model$training_seasons,
    selected_model$validation_seasons
  )
  
  if (
    length(intersect(
      unique(test$season),
      previously_used
    )) > 0L
  ) {
    stop("Test seasons overlap training or validation.")
  }
  
  actual <- test$shot_made
  
  if (
    !is.numeric(actual) ||
    any(!is.finite(actual)) ||
    !all(actual %in% c(0, 1))
  ) {
    stop("Test outcomes must contain only 0 and 1.")
  }
  
  scored <- score_shots(selected_model, test)
  
  probability <- scored$make_probability
  
  safe_probability <- pmin(
    pmax(probability, 1e-15),
    1 - 1e-15
  )
  
  scored$actual_points <- actual * ifelse(
    scored$is_three == 1L,
    3,
    2
  )
  
  scored$points_above_expected <-
    scored$actual_points - scored$expected_points
  
  metrics <- data.frame(
    model = selected_model$model_name,
    seasons = paste(sort(unique(test$season)), collapse = ", "),
    shots = nrow(test),
    
    log_loss = -mean(
      actual * log(safe_probability) +
        (1 - actual) * log1p(-safe_probability)
    ),
    
    brier_score = mean(
      (probability - actual)^2
    ),
    
    mean_predicted = mean(probability),
    actual_make_rate = mean(actual)
  )
  
  list(
    metrics = metrics,
    scored_shots = scored
  )
}