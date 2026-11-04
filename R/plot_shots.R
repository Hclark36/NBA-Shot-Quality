# Draw an NBA half court in feet, relative to the basket.
draw_half_court <- function() {
  
  circle <- function(radius, center_y = 0) {
    angle <- seq(0, 2 * pi, length.out = 200)
    
    data.frame(
      x = radius * cos(angle),
      y = center_y + radius * sin(angle)
    )
  }
  
  # Three-point arc joins the corner lines at x = +/-22 feet.
  angle <- seq(
    acos(22 / 23.75),
    pi - acos(22 / 23.75),
    length.out = 200
  )
  
  three_arc <- data.frame(
    x = 23.75 * cos(angle),
    y = 23.75 * sin(angle)
  )
  
  corner_height <- sqrt(23.75^2 - 22^2)
  
  ggplot2::ggplot() +
    ggplot2::annotate(
      "rect",
      xmin = -25, xmax = 25,
      ymin = -5.25, ymax = 41.75,
      fill = "#FBF8F1",
      color = "#687574"
    ) +
    ggplot2::annotate(
      "rect",
      xmin = -8, xmax = 8,
      ymin = -5.25, ymax = 13.75,
      fill = NA,
      color = "#687574"
    ) +
    ggplot2::geom_path(
      data = circle(6, center_y = 13.75),
      ggplot2::aes(x, y),
      color = "#687574"
    ) +
    ggplot2::geom_path(
      data = three_arc,
      ggplot2::aes(x, y),
      color = "#687574"
    ) +
    ggplot2::annotate(
      "segment",
      x = -22, xend = -22,
      y = -5.25, yend = corner_height,
      color = "#687574"
    ) +
    ggplot2::annotate(
      "segment",
      x = 22, xend = 22,
      y = -5.25, yend = corner_height,
      color = "#687574"
    ) +
    ggplot2::annotate(
      "segment",
      x = -3, xend = 3,
      y = -1.25, yend = -1.25,
      color = "#687574",
      linewidth = 1
    ) +
    ggplot2::geom_path(
      data = circle(0.75),
      ggplot2::aes(x, y),
      color = "#CE7231",
      linewidth = 1
    ) +
    ggplot2::coord_fixed(
      xlim = c(-26, 26),
      ylim = c(-7, 43)
    ) +
    ggplot2::theme_void(base_size = 13) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(
        hjust = 0,
        size = 9
      )
    )
}


plot_player_shots <- function(
    player_shots,
    player_label = "Selected player"
) {
  
  required <- c(
    "player_id", "season",
    "x_ft", "y_ft",
    "shot_made",
    "make_probability",
    "actual_points",
    "expected_points"
  )
  
  missing <- setdiff(required, names(player_shots))
  
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  if (nrow(player_shots) == 0L) {
    stop("No shots found for this player.")
  }
  
  if (
    anyNA(player_shots$player_id) ||
    length(unique(player_shots$player_id)) != 1L
  ) {
    stop("Supply shots for exactly one NBA player.")
  }
  
  numeric_fields <- c(
    "x_ft", "y_ft", "shot_made",
    "make_probability", "actual_points", "expected_points"
  )
  
  for (name in numeric_fields) {
    if (
      !is.numeric(player_shots[[name]]) ||
      any(!is.finite(player_shots[[name]]))
    ) {
      stop("Expected finite numeric values in: ", name)
    }
  }
  
  if (
    any(!player_shots$shot_made %in% c(0, 1)) ||
    any(
      player_shots$make_probability < 0 |
      player_shots$make_probability > 1
    )
  ) {
    stop("Invalid shot outcomes or probabilities.")
  }
  
  d <- player_shots
  
  d$result <- ifelse(
    d$shot_made == 1,
    "Made",
    "Missed"
  )
  
  # Keep long-distance attempts in the totals, even if off this map.
  visible <- d[
    d$x_ft >= -25 & d$x_ft <= 25 &
      d$y_ft >= -5.25 & d$y_ft <= 41.75,
    ,
    drop = FALSE
  ]
  
  seasons <- paste(
    sort(unique(d$season)),
    collapse = ", "
  )
  
  caption <- sprintf(
    "Half-court view: %s of %s attempts. All attempts remain in scoring totals.",
    nrow(visible),
    nrow(d)
  )
  
  outcomes <- draw_half_court() +
    ggplot2::geom_point(
      data = visible,
      ggplot2::aes(x_ft, y_ft, color = result),
      size = 2.5,
      alpha = 0.65
    ) +
    ggplot2::scale_color_manual(
      values = c(
        Made = "#087F78",
        Missed = "#CE7231"
      )
    ) +
    ggplot2::labs(
      title = paste(player_label, "— makes and misses"),
      subtitle = seasons,
      color = "Shot result",
      caption = caption
    )
  
  quality <- draw_half_court() +
    ggplot2::geom_point(
      data = visible,
      ggplot2::aes(
        x_ft,
        y_ft,
        color = make_probability
      ),
      size = 2.5,
      alpha = 0.8
    ) +
    ggplot2::scale_color_gradient(
      low = "#5B66A5",
      high = "#E6AD38",
      limits = c(0, 1),
      labels = function(x) paste0(round(x * 100), "%")
    ) +
    ggplot2::labs(
      title = paste(player_label, "— predicted shot quality"),
      subtitle = paste(seasons, "| brighter dots = higher make probability"),
      color = "Make probability",
      caption = caption
    )
  
  totals <- data.frame(
    measure = factor(
      c("Expected", "Actual"),
      levels = c("Expected", "Actual")
    ),
    points = c(
      sum(d$expected_points),
      sum(d$actual_points)
    )
  )
  
  difference <- sum(d$actual_points - d$expected_points)
  
  scoring <- ggplot2::ggplot(
    totals,
    ggplot2::aes(measure, points, fill = measure)
  ) +
    ggplot2::geom_col(
      width = 0.55,
      show.legend = FALSE
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.1f", points)),
      vjust = -0.4,
      size = 5
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        Expected = "#5B66A5",
        Actual = "#087F78"
      )
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0, 0.12))
    ) +
    ggplot2::labs(
      title = paste(player_label, "— actual versus expected"),
      subtitle = sprintf(
        "%s | %+.1f field-goal points above expectation",
        seasons,
        difference
      ),
      x = NULL,
      y = "Field-goal points",
      caption = "Excludes free throws. Expectations use the saved league-wide model."
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold")
    )
  
  list(
    outcomes = outcomes,
    quality = quality,
    scoring = scoring
  )
}