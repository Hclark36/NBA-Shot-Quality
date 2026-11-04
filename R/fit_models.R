# Train reusable shot-quality models.
# Player identity and actual points are never predictors.

fit_models <- function(train, cfg) {
  
  features <- c(
    "x_ft",
    "y_ft",
    "shot_distance",
    "is_three",
    "period",
    "period_seconds_remaining"
  )
  
  required <- c(
    "season",
    "shot_made",
    features
  )
  
  missing <- setdiff(required, names(train))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(train) == 0L) {
    stop("No training shots were supplied.")
  }
  
  # Reject validation or test seasons.
  if (
    anyNA(train$season) ||
    !setequal(unique(train$season), cfg$train_seasons)
  ) {
    stop("Supply only the complete set of configured training seasons.")
  }
  
  for (name in c(features, "shot_made")) {
    if (
      !is.numeric(train[[name]]) ||
      any(!is.finite(train[[name]]))
    ) {
      stop("Column must contain finite numeric values: ", name)
    }
  }
  
  if (
    !all(train$shot_made %in% c(0, 1)) ||
    length(unique(train$shot_made)) != 2L
  ) {
    stop("Training data must include both made and missed shots.")
  }
  
  set.seed(cfg$seed)
  
  # Use only the required columns.
  # This prevents names, descriptions, and results from entering
  # the predictor set accidentally.
  training_data <- as.data.frame(train[required])
  
  message("Fitting logistic regression...")
  
  logistic <- stats::glm(
    shot_made ~
      x_ft + I(x_ft^2) +
      y_ft + I(y_ft^2) +
      shot_distance + I(shot_distance^2) +
      is_three +
      period +
      period_seconds_remaining,
    data = training_data,
    family = stats::binomial(link = "logit"),
    control = stats::glm.control(maxit = 100),
    na.action = stats::na.fail,
    model = FALSE,
    x = FALSE,
    y = FALSE
  )
  
  if (!isTRUE(logistic$converged)) {
    stop("Logistic regression did not converge.")
  }
  
  message("Fitting the spatial GAM. This may take several minutes...")
  
  # Make the smooth-term constructor available in the formula.
  s <- mgcv::s
  
  spatial_gam <- mgcv::bam(
    shot_made ~
      s(x_ft, y_ft, k = 60) +
      s(shot_distance, k = 12) +
      is_three +
      period +
      s(period_seconds_remaining, k = 12),
    data = training_data,
    family = stats::binomial(link = "logit"),
    method = "fREML",
    discrete = TRUE,
    nthreads = 2,
    na.action = stats::na.fail
  )
  
  # Confirm both models produce valid probabilities.
  check_data <- training_data[
    seq_len(min(1000L, nrow(training_data))),
    ,
    drop = FALSE
  ]
  
  models <- list(
    logistic = logistic,
    spatial_gam = spatial_gam
  )
  
  for (name in names(models)) {
    probabilities <- stats::predict(
      models[[name]],
      newdata = check_data,
      type = "response"
    )
    
    if (
      any(!is.finite(probabilities)) ||
      any(probabilities < 0 | probabilities > 1)
    ) {
      stop("Invalid probabilities from model: ", name)
    }
  }
  
  list(
    models = models,
    features = features,
    training_seasons = sort(unique(train$season)),
    training_shots = nrow(train),
    training_make_rate = mean(train$shot_made),
    seed = cfg$seed,
    fitted_at_utc = format(
      Sys.time(),
      tz = "UTC",
      usetz = TRUE
    ),
    session_info = capture.output(sessionInfo())
  )
}