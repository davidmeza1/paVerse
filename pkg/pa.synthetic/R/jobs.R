#' Generate a synthetic job catalog
#'
#' Builds a `padm`-conforming `pa_job` table: a fixed set of job families,
#' each with a 5-level ladder (`job_level` 1 = entry, 5 = senior).
#'
#' @param seed Integer seed (kept for interface symmetry; the catalog itself
#'   is deterministic given the fixed family/level structure).
#' @return A data frame conforming to `pa_job`
#'   (`spec/padm/schemas/pa_job.schema.json`).
#' @export
pa_synth_jobs <- function(seed = 1) {
  families <- c("Engineering", "Sales", "Operations", "Finance", "People")
  titles <- list(
    Engineering = c("Associate Engineer", "Engineer", "Senior Engineer", "Staff Engineer", "Principal Engineer"),
    Sales = c("Sales Associate", "Account Executive", "Senior Account Executive", "Sales Manager", "Director of Sales"),
    Operations = c("Operations Associate", "Operations Analyst", "Senior Analyst", "Operations Manager", "Director of Operations"),
    Finance = c("Finance Associate", "Financial Analyst", "Senior Analyst", "Finance Manager", "Director of Finance"),
    People = c("People Associate", "People Partner", "Senior People Partner", "People Manager", "Director of People")
  )

  rows <- do.call(rbind, lapply(families, function(fam) {
    data.frame(
      job_id = sprintf("JOB_%s_%d", toupper(substr(fam, 1, 3)), seq_along(titles[[fam]])),
      job_title = titles[[fam]],
      job_family = fam,
      job_level = seq_along(titles[[fam]]),
      stringsAsFactors = FALSE
    )
  }))
  rownames(rows) <- NULL
  rows
}
