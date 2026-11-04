# Data

- `example/shots.csv` is an eight-row synthetic fixture for pipeline checks. It contains no real player statistics and is not used to fit the published model.
- `raw/` holds the NBA season files downloaded from the [SportsDataverse shot archive](https://github.com/sportsdataverse/sportsdataverse-data/releases/tag/nba_stats_shots).
- `processed/` holds the cleaned shots, season splits, and scored test shots.

The full raw and processed files are generated locally and ignored by Git. From the project root, run `source("scripts/run.R")` in RStudio to recreate them. The synthetic fixture is enough to run `Rscript tests/test-pipeline.R` without downloading NBA data.
