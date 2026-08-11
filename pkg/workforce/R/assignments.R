#' Fold a padm event stream into assignment intervals
#'
#' The `admiral`-analogue derivation at the heart of `workforce`: turns the
#' immutable `pa_event` stream into `pa_assignment`, an SCD-2 table of
#' uninterrupted assignment intervals per person (see `spec/padm/padm-v0.md`
#' §3.1). Every event whose `affects_assignment` vocabulary flag is `TRUE`
#' (see [padm_event_types()]) closes the person's currently open interval
#' and opens a new one carrying that event's resulting state — except
#' `"exit"`, which closes the open interval and opens nothing.
#'
#' Because [pa.synthetic::pa_synth_events()] (and any padm-conforming
#' source) records the *resulting* state on every assignment-affecting
#' event row, no merging of partial updates is needed here — each event's
#' own `org_unit_id`/`job_id`/`manager_person_id`/`fte` becomes the new
#' interval's state directly.
#'
#' @param event A `pa_event` data frame.
#' @return A `pa_assignment` data frame: `person_id`, `valid_from`,
#'   `valid_to` (`NA` = currently open), `org_unit_id`, `job_id`,
#'   `manager_person_id`, `fte`, `is_on_leave`, `exit_type`.
#' @export
wf_assignments <- function(event) {
  affects <- .assignment_affecting_types()
  ev <- event[event$event_type %in% affects, ]
  ev <- ev[order(ev$person_id, ev$event_date, ev$event_id), ]

  by_person <- split(ev, ev$person_id)
  rows <- lapply(by_person, function(pe) {
    n <- nrow(pe)
    is_opener <- pe$event_type != "exit"
    idx <- which(is_opener)
    if (length(idx) == 0L) return(NULL)

    next_idx <- pmin(idx + 1L, n)
    has_next <- (idx + 1L) <= n
    valid_to <- as.Date(ifelse(has_next, as.character(pe$event_date[next_idx]), NA))
    is_exit_next <- has_next & pe$event_type[next_idx] == "exit"
    exit_type <- ifelse(is_exit_next, pe$event_subtype[next_idx], NA_character_)

    data.frame(
      person_id = pe$person_id[idx],
      valid_from = pe$event_date[idx],
      valid_to = valid_to,
      org_unit_id = pe$org_unit_id[idx],
      job_id = pe$job_id[idx],
      manager_person_id = pe$manager_person_id[idx],
      fte = pe$fte[idx],
      is_on_leave = pe$event_type[idx] == "leave_start",
      exit_type = exit_type,
      stringsAsFactors = FALSE
    )
  })

  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res[order(res$person_id, res$valid_from), ]
}
