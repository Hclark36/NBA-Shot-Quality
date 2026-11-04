# NBA Shot Quality

A reusable R pipeline and interactive dashboard for NBA field-goal make probability and expected scoring.

Open `NBA-Shot-Quality.Rproj` in RStudio. To build the analysis from scratch, run:

```r
source("scripts/run.R")
```

The runner installs missing R packages, downloads or reuses archived data, and rebuilds the model and test outputs. It can take several minutes. The source is [SportsDataverse’s archived NBA play-by-play shots](https://github.com/sportsdataverse/sportsdataverse-data/releases/tag/nba_stats_shots). Only regular-season field-goal attempts are included.

With scored shots already saved, use these commands without retraining:

```r
source("scripts/player_report.R")  # defaults to Paul George when no player ID is set
source("scripts/render.R")         # standalone interactive HTML; requires Quarto
```

Set `selected_player_id` in `config.R`, or run `Rscript scripts/player_report.R 202331` from the project root. Player CSVs go to `output/tables/` and PNGs to `output/figures/`. Open `dist/dashboard/index.html` to select a player, compare scoring totals, switch court views, or replay shots in game ID order. The dashboard contains only scored test seasons; the default configuration has one, 2025–26.

The models train on 2022–23 and 2023–24. Validation on 2024–25 selected the spatial GAM by log loss. On 219,159 held-out 2025–26 shots, log loss was 0.65277 and Brier score was 0.23017. Player identity is not a predictor. Expected points exclude free throws, and above-expected results can reflect omitted context such as defender pressure. Generated data, models, figures, and HTML are ignored by Git.
