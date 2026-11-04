# Data guide

The analysis uses [SportsDataverse's archived NBA play-by-play shot files](https://github.com/sportsdataverse/sportsdataverse-data/releases/tag/nba_stats_shots). The downloader reads the GitHub release assets, validates their season and columns, and retains regular-season two- and three-point field-goal attempts, including both makes and misses. It does not use the live NBA shot-chart endpoint.

| Season | Use | Shots in the verified run |
| --- | --- | ---: |
| 2022–23 | Training | 217,219 |
| 2023–24 | Training | 218,702 |
| 2024–25 | Validation | 219,527 |
| 2025–26 | Final test | 219,159 |
| **Total** | | **874,607** |

| Location | Contents | In Git? |
| --- | --- | --- |
| [example/shots.csv](example/shots.csv) | Eight synthetic rows for testing. No real player stats; never used to train the NBA models. | Yes |
| `raw/` | Season archives such as `sdv_shots_2026.rds` (2025–26), plus source URL, download time, row count, and checksum metadata. | Only the folder placeholder |
| `processed/prepared_shots.rds` | Cleaned shots and the cleaning audit. | No |
| `processed/shot_splits.rds` | Separate chronological training, validation, and test data. | No |
| `processed/scored_test_shots.rds` | Test shots with make probabilities, expected points, and actual points above expectation. This is the input to the player report and dashboard. | No |

NBA game IDs are kept as text to preserve leading zeros. Shot IDs identify rows within the source archive and are not official NBA event IDs. Court coordinates are converted to feet. The clock feature measures time remaining in the period, not time remaining on the shot clock.

To regenerate the NBA files, open the RStudio project and run `source("scripts/run.R")`. It reuses cached raw files where available. To check the code without the NBA dataset, run `source("scripts/setup.R")` and then `source("tests/test-pipeline.R")` from the project root. See the [main README](../README.md) for the full workflow.
