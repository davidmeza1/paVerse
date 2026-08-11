#' padm event-type vocabulary
#'
#' Reads the controlled event-type vocabulary shipped with the package
#' (`inst/extdata/event-types.csv`), kept in sync with
#' `spec/padm/vocab/event-types.csv` at the repo root. This copy will move to
#' a standalone `padm` package once a second consumer needs it.
#'
#' @return A data frame with columns `event_type`, `event_subtype`,
#'   `category`, `description`, `affects_assignment`, `affects_headcount`.
#' @export
pa_event_types <- function() {
  path <- system.file("extdata", "event-types.csv", package = "pa.synthetic")
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
}

#' @keywords internal
.clamp01 <- function(x) pmin(pmax(x, 0), 1)

#' @keywords internal
.month_seq <- function(from, to) {
  if (to < from) return(as.Date(character(0)))
  seq(from, to, by = "month")
}

#' @keywords internal
.add_months <- function(date, n) {
  as.Date(as.character(seq(date, by = paste(n, "months"), length.out = 2)[2]))
}

#' @keywords internal
.new_ids <- function(prefix, n, width = 6, start = 1) {
  sprintf(paste0(prefix, "%0", width, "d"), seq.int(start, length.out = n))
}
