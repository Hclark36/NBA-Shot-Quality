# Shot quality: 2025–26 held-out results

The league-wide spatial GAM had the lowest validation log loss (0.65262), ahead of logistic regression (0.66013) and the training-average benchmark (0.69111). Selection used 2024–25 shots only. Training used 2022–23 and 2023–24.

On 219,159 shots from 2025–26, the frozen GAM scored 0.65277 log loss and 0.23017 Brier score. It predicted a 47.18% average make rate; the observed rate was 47.10%. The close aggregate rates do not establish calibration for every court zone or player.

Paul George made 225 of 513 attempts. He scored 550 field-goal points against 536.23 expected, a difference of +13.77 points or +2.68 per 100 attempts. His free throws are excluded. Defender distance and other context absent from the model can contribute to the difference, so it should not be interpreted as an isolated measure of shooting skill.

See the local dashboard for interactive shot maps, replay, and player comparisons. Generate the report figures with `source("scripts/player_report.R")`.
