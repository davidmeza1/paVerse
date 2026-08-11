#' padm event-type vocabulary
#'
#' Reads the controlled event-type vocabulary shipped with the package
#' (`inst/extdata/padm/vocab/event-types.csv`), kept in sync with
#' `spec/padm/vocab/event-types.csv` at the repo root — the same copy also
#' ships in `pa.synthetic`. Both copies move to a standalone `padm` package
#' once it exists; duplicating a small CSV across two packages is an
#' acceptable v0 cost, silently drifting copies is not.
#'
#' @return A data frame with columns `event_type`, `event_subtype`,
#'   `category`, `description`, `affects_assignment`, `affects_headcount`.
#' @export
padm_event_types <- function() {
  path <- system.file("extdata", "padm", "vocab", "event-types.csv", package = "workforce")
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
}

#' @keywords internal
.assignment_affecting_types <- function() {
  vocab <- padm_event_types()
  unique(vocab$event_type[vocab$affects_assignment %in% TRUE])
}
