# NBA Shot Quality

An R project that estimates the probability of making an NBA field goal, then compares each player's actual scoring with what the model expected from their shot selection.

## Explore the results

Download the [dashboard snapshot](dashboard/index.html) using GitHub's **Download raw file** button, then open it in a browser. No R installation or NBA data download is needed to view it. The dashboard lets you select a player, compare field-goal scoring, switch between makes and misses, predicted probabilities, and shot density, and replay shots in game ID order. The snapshot covers the 2025–26 regular season.

For a quick look, see the [validation calibration chart](output/figures/validation_calibration.png), [Paul George's shot map](output/figures/player_202331_outcomes.png), or the [findings report](reports/findings.md).

## Rebuild the analysis

Install R and open [NBA-Shot-Quality.Rproj](NBA-Shot-Quality.Rproj) in RStudio. This project was tested with R 4.4. Quarto is needed only to render a new dashboard. Run commands from the repository root, where [config.R](config.R) is located.

In the RStudio Console:

```r
source("scripts/run.R")
```

The runner installs missing R packages, downloads or reuses the archived shots, prepares the data, trains the candidate models, selects a model on validation data, and evaluates that selection on the held-out test season. The first run needs internet access; model fitting can take several minutes. See the [data guide](data/README.md) for the source, files, and what Git ignores.

## Generate a player report or dashboard

Once the rebuild has saved scored test shots, these commands reuse them without training again:

```r
source("scripts/player_report.R")
source("scripts/render.R")
```

- **Player report:** Set `selected_player_id` in [config.R](config.R). If it is `NULL`, the report defaults to Paul George (NBA ID `202331`). From Terminal, you can instead pass an ID directly: `Rscript scripts/player_report.R 202331`. The report writes a CSV to `output/tables/` and three charts to `output/figures/`. The player must have shots in the saved test dataset.
- **Dashboard:** Open the newly rendered `dist/dashboard/index.html` in a browser. Rendering uses Quarto from your PATH, the standard macOS RStudio bundle, or the executable specified by `QUARTO_BIN`. The dashboard lists players and seasons present in the saved test data; the default analysis has one test season.

The repository includes a dashboard snapshot and selected PNGs for viewing. The downloaded data, fitted model files, and new outputs under `dist/` are kept locally.

## Model and results

| Stage | Seasons | Role |
| --- | --- | --- |
| Training | 2022–23 and 2023–24 | Fit logistic regression and a spatial GAM |
| Validation | 2024–25 | Select the lowest log loss among the candidates and a training-average benchmark |
| Test | 2025–26 | Evaluate the frozen selection on 219,159 shots |

The spatial GAM won on validation. Its held-out log loss was **0.65277**, and its Brier score was **0.23017**. It predicted a 47.18% overall make rate; the observed rate was 47.10%. This overall agreement does not establish calibration for every player or shot type.

The model uses shot location, distance, two- versus three-point shot type, period, and time remaining in the period. Player identity and shot outcomes are excluded from the predictors. Expected field-goal points equal make probability times shot value and exclude free throws. Actual points above expectation can reflect omitted context such as defender pressure as well as shot making.

## Run the tests

In a fresh checkout, run setup first to install the dependencies. You can then run the tests independently of the analysis:

```r
source("scripts/setup.R")
source("tests/test-pipeline.R")
```

From Terminal at the project root, the equivalent commands are `Rscript scripts/setup.R` and `Rscript tests/test-pipeline.R`. The tests use [eight synthetic shots](data/example/shots.csv) to check data preparation, season separation, and expected-points calculations. Once dependencies are installed, the tests need no network access, NBA downloads, or model training. Run them locally; automated GitHub Actions checks are not enabled in the published repository.
