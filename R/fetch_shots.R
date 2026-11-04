fetch_shot_season <- function(season, cfg, refresh = FALSE) {
  
  if (!grepl('^[0-9]{4}-[0-9]{2}$', season)) stop('Use a season like 2025-26.')
  end_year <- as.integer(substr(season, 1, 4)) + 1L
  
  if (substr(season, 6, 7) != sprintf('%02d', end_year %% 100L)) stop('Invalid season.')
  
  dir.create(cfg$paths$raw, recursive = TRUE, showWarnings = FALSE)
  
  path <- file.path(cfg$paths$raw, paste0('sdv_shots_', end_year, '.rds'))
  
  url <- paste0('https://github.com/sportsdataverse/sportsdataverse-data/',
                'releases/download/nba_stats_shots/shots_', end_year, '.rds')
  
  downloaded <- !file.exists(path) || refresh
  
  input <- path
  
  if (downloaded) {
    message('Downloading archived NBA shots: ', season)
    input <- tempfile(fileext = '.rds')
    on.exit(unlink(input), add = TRUE)
    request <- httr2::request(url) |>
      httr2::req_timeout(120) |>
      httr2::req_retry(max_tries = cfg$max_retries, retry_on_failure = TRUE)
    httr2::req_perform(request, path = input)
  } else message('Loading cached archive: ', season)
  
  x <- as.data.frame(readRDS(input))
  
  required <- c('game_id', 'season', 'season_type_id', 'person_id',
                'player_name', 'period', 'clock', 'shot_result', 'shot_value',
                'shot_distance', 'x_legacy', 'y_legacy')
  
  if (!all(required %in% names(x))) stop('Archive columns do not match the expected schema.')
  
  if (!nrow(x) || any(is.na(x$season) | x$season != end_year)) stop('Archive season mismatch.')
  x$source_row <- seq_len(nrow(x))
  
  x <- x[!is.na(x$season_type_id) & as.character(x$season_type_id) == '2', ]
  
  if (!nrow(x)) stop('No regular-season shots in this archive.')
  
  if (any(is.na(x$shot_result) | !x$shot_result %in% c('Made', 'Missed')) ||
      !all(c('Made', 'Missed') %in% x$shot_result)) stop('Expected both makes and misses.')
  
  if (any(is.na(x$shot_value) | !x$shot_value %in% c(2, 3))) stop('Invalid shot values.')
  
  valid_clock <- !is.na(x$clock) & grepl('^PT[0-9]+M[0-9.]+S$', x$clock)
  
  if (!all(valid_clock)) stop('Unexpected game-clock format.')
  
  minutes <- as.numeric(sub('^PT([0-9]+)M.*$', '\\1', x$clock))
  
  seconds <- as.numeric(sub('^PT[0-9]+M([0-9.]+)S$', '\\1', x$clock))
  
  shots <- data.frame(
    shot_id = paste(end_year, x$source_row, sep = ':'),
    game_id = as.character(x$game_id), season = season,
    player_id = x$person_id, player_name = x$player_name,
    period = x$period, seconds_remaining = minutes * 60 + seconds,
    shot_type = ifelse(x$shot_value == 3, '3PT Field Goal', '2PT Field Goal'),
    shot_distance = x$shot_distance, loc_x = x$x_legacy, loc_y = x$y_legacy,
    shot_attempted_flag = 1L, shot_made_flag = as.integer(x$shot_result == 'Made'),
    source = 'SportsDataverse NBA play-by-play shots', stringsAsFactors = FALSE)
  
  if (downloaded) {
    
    if (!file.copy(input, path, overwrite = TRUE)) stop('Could not save the archive cache.')
    
    jsonlite::write_json(list(source_url = url,
                              retrieved_at_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE),
                              season = season, regular_season_rows = nrow(shots),
                              sha256 = digest::digest(file = path, algo = 'sha256')),
                         paste0(path, '.metadata.json'), auto_unbox = TRUE, pretty = TRUE)
  }
  
  message(season, ': ', format(nrow(shots), big.mark = ','), ' regular-season shots.')
  shots
}

fetch_shots <- function(cfg, seasons = cfg$download_seasons, refresh = FALSE) {
  dplyr::bind_rows(lapply(unique(seasons), function(season)
    fetch_shot_season(season, cfg, refresh)))
}