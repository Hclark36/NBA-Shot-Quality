# Compare predictions on validation data.
# The final test season stays untouched.

evaluate_models <- function(fitted_models, validation, cfg) {
  
  required <- c(
    "season",
    "shot_made",
    fitted_models$features
  )
  
  missing <- setdiff(required, names(validation))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(validation) == 0L) {
    stop("No validation shots were supplied.")
  }
  
  if (
    anyNA(validation$season) ||
    !setequal(
      unique(validation$season),
      cfg$validation_seasons
    )
  ) {
    stop("Supply only the configured validation seasons.")
  }
  
  # Confirm training and validation do not overlap.
  if (
    length(intersect(
      fitted_models$training_seasons,
      unique(validation$season)
    )) > 0L
  ) {
    stop("Training and validation seasons overlap.")
  }
  
  for (name in c(fitted_models$features, "shot_made")) {
    if (
      !is.numeric(validation[[name]]) ||
      any(!is.finite(validation[[name]]))
    ) {
      stop("Column must contain finite numeric values: ", name)
    }
  }
  
  actual <- validation$shot_made
  
  if (!all(actual %in% c(0, 1))) {
    stop("Outcomes must be coded as 0 or 1.")
  }
  
  # Generate predictions without refitting.
  predictions <- lapply(
    fitted_models$models,
    function(model) {
      as.numeric(stats::predict(
        model,
        newdata = validation,
        type = "response"
      ))
    }
  )
  
  # Benchmark: assign every shot the training make rate.
  predictions$training_mean <- rep(
    fitted_models$training_make_rate,
    nrow(validation)
  )
  
  score_probability <- function(probability, name) {
    
    if (
      length(probability) != length(actual) ||
      any(!is.finite(probability)) ||
      any(probability < 0 | probability > 1)
    ) {
      stop("Invalid predictions from: ", name)
    }
    
    # Clip only for logarithms to avoid log(0).
    safe_probability <- pmin(
      pmax(probability, 1e-15),
      1 - 1e-15
    )
    
    data.frame(
      model = name,
      shots = length(actual),
      
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
  }
  
  metrics <- dplyr::bind_rows(lapply(
    names(predictions),
    function(name) {
      score_probability(predictions[[name]], name)
    }
  ))
  
  metrics <- metrics[
    order(metrics$log_loss, metrics$brier_score, metrics$model),
    ,
    drop = FALSE
  ]
  
  rownames(metrics) <- NULL
  best_name <- metrics$model[1]
  
  # Group probabilities into fixed bins for calibration charts.
  calibration <- dplyr::bind_rows(lapply(
    names(predictions),
    function(name) {
      
      probability <- predictions[[name]]
      
      data.frame(
        model = name,
        probability = probability,
        actual = actual,
        bin = cut(
          probability,
          breaks = seq(0, 1, by = 0.1),
          include.lowest = TRUE
        )
      ) |>
        dplyr::group_by(model, bin) |>
        dplyr::summarise(
          shots = dplyr::n(),
          mean_predicted = mean(probability),
          actual_make_rate = mean(actual),
          .groups = "drop"
        )
    }
  ))
  
  # Save a reusable scoring bundle.
  # If the benchmark wins, preserve it as a constant predictor.
  selected_model <- list(
    model_name = best_name,
    prediction_type = if (
      best_name == "training_mean"
    ) "constant" else "fitted",
    
    fit = if (
      best_name == "training_mean"
    ) NULL else fitted_models$models[[best_name]],
    
    constant_probability = if (
      best_name == "training_mean"
    ) fitted_models$training_make_rate else NULL,
    
    features = fitted_models$features,
    training_seasons = fitted_models$training_seasons,
    validation_seasons = sort(unique(validation$season)),
    selection_metric = "validation log loss"
  )
  
  list(
    metrics = metrics,
    calibration = calibration,
    selected_model = selected_model
  )
}

# Create the clearer calibration chart.
plot_calibration <- function(evaluation) {
  
  model_labels <- c(
    spatial_gam = "Spatial GAM",
    logistic = "Logistic regression",
    training_mean = "Training Average"
  )
  
  model_colors <- c(
    spatial_gam = "#087F78",
    logistic = "#CE7231",
    training_mean = "#5B66A5"
  )
  
  calibration_data <- evaluation$calibration
  
  calibration_data$model <- factor(
    calibration_data$model,
    levels = c("spatial_gam", "logistic", "training_mean")
  )
  
  percent_label <- function(x) {
    paste0(round(x * 100), "%")
  }
  
  ggplot2::ggplot(
    calibration_data,
    ggplot2::aes(
      x = mean_predicted,
      y = actual_make_rate,
      color = model
    )
  ) +
    ggplot2::geom_abline(
      slope = 1,
      intercept = 0,
      linetype = "dashed",
      color = "gray55"
    ) +
    ggplot2::geom_line(
      data = subset(
        calibration_data,
        model != "training_mean"
      ),
      linewidth = 1
    ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::facet_wrap(
      ~model,
      ncol = 1,
      labeller = ggplot2::as_labeller(model_labels)
    ) +
    ggplot2::scale_color_manual(values = model_colors) +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 1, 0.25),
      labels = percent_label
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq(0, 1, 0.25),
      labels = percent_label
    ) +
    ggplot2::coord_cartesian(
      xlim = c(0, 1),
      ylim = c(0, 1)
    ) +
    ggplot2::labs(
      title = "Do predicted probabilities match actual results?",
      subtitle = paste(
        evaluation$selected_model$validation_seasons,
        collapse = ", "
      ),
      x = "Predicted make probability",
      y = "Actual make rate",
      caption = paste(
        "Dashed line = perfect calibration.",
        "\nAbove: underprediction. Below: overprediction.",
        "\nEach point represents a probability bin."
      )
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, size = 9)
    )
}