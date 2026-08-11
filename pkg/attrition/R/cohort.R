#' Cohort retention table at fixed tenure checkpoints
#'
#' A simpler, table-shaped complement to [attr_curve()]: for each hire-year
#' cohort, the fraction retained to each tenure checkpoint (3, 6, 12, 24, 36
#' months by default). A person only enters the denominator for a checkpoint
#' once they are *observable* at it — either they've already exited (so we
#' know definitively whether they made it that far) or they're still active
#' with tenure already at or beyond the checkpoint. Still-active persons who
#' haven't yet reached a checkpoint are excluded from that checkpoint's
#' denominator rather than counted as failures — they're right-censored, not
#' churned.
#'
#' @param tenure A data frame shaped like `workforce::wf_tenure()`'s output:
#'   `person_id`, `hire_date`, `tenure_months`, `is_active`.
#' @param checkpoints_months Integer vector of tenure checkpoints, in months.
#'   Default `c(3, 6, 12, 24, 36)`.
#' @return A data frame with one row per cohort x checkpoint: `cohort`,
#'   `n` (cohort size), `checkpoint_months`, `n_observable`, `retention`
#'   (fraction of `n_observable` with `tenure_months >= checkpoint_months`;
#'   `NA` if nothing is observable yet at that checkpoint).
#' @export
attr_cohort <- function(tenure, checkpoints_months = c(3, 6, 12, 24, 36)) {
  d <- tenure
  d$cohort <- format(d$hire_date, "%Y")

  by_cohort <- split(d, d$cohort)
  rows <- lapply(names(by_cohort), function(cy) {
    dc <- by_cohort[[cy]]
    n0 <- nrow(dc)

    per_checkpoint <- lapply(checkpoints_months, function(m) {
      observable <- !dc$is_active | dc$tenure_months >= m
      n_observable <- sum(observable)
      retained <- sum(dc$tenure_months >= m)
      retention <- if (n_observable == 0) NA_real_ else retained / n_observable
      data.frame(
        cohort = cy, n = n0, checkpoint_months = m,
        n_observable = n_observable, retention = retention,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, per_checkpoint)
  })

  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res[order(res$cohort, res$checkpoint_months), ]
}
