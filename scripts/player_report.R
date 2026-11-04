# Run from the project root: Rscript scripts/player_report.R [NBA_PLAYER_ID]
source("config.R")

if (dir.exists(".Rlib")) .libPaths(c(normalizePath(".Rlib"), .libPaths()))

source("R/player_results.R")

source("R/plot_shots.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) > 1L) stop("Supply at most one NBA player ID.")

id <- if (length(args)) args[1] else config$selected_player_id

if (is.null(id)) id <- 202331L

if (!grepl("^[0-9]+$", as.character(id))) stop("Supply a numeric NBA player ID.")

path <- file.path(config$paths$processed, "scored_test_shots.rds")
if (!file.exists(path)) stop("Run scripts/run.R to create scored test shots.")

shots <- select_player_shots(readRDS(path), id)

summary <- summarize_players(shots, config$min_player_attempts)

label <- if (as.character(id) == "202331") "Paul George" else summary$player_name[1]

plots <- plot_player_shots(shots, player_label = label)

prefix <- paste0("player_", id)

for (folder in config$paths[c("tables", "figures")])
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
write.csv(summary, file.path(config$paths$tables, paste0(prefix, "_summary.csv")), row.names = FALSE)

for (name in names(plots)) {
  if (interactive()) print(plots[[name]])
  ggplot2::ggsave(file.path(config$paths$figures, paste0(prefix, "_", name, ".png")),
    plots[[name]], width = 9, height = 8, dpi = 200, bg = "white")
}

print(as.data.frame(summary))