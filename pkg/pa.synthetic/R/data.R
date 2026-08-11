#' Cached synthetic demo datasets
#'
#' Pre-generated, seeded synthetic datasets conforming to `padm`, built by
#' `data-raw/build_demo_data.R` so examples and the ecosystem demo run
#' instantly without re-simulating. All contain no real people — see
#' [pa_synth_org()], [pa_synth_jobs()], [pa_synth_cohort()], and
#' [pa_synth_events()] for the generators that produced them.
#'
#' @format
#' - `padm_demo_org_unit`: a `pa_org_unit` table, 15 units over 3 levels.
#' - `padm_demo_job`: a `pa_job` table, 5 families x 5 levels.
#' - `padm_demo_person`: a `pa_person` table, ~600 people hired 2019-2024.
#' - `padm_demo_event`: the full `pa_event` stream for those people through
#'   2025-12-31, including the documented adverse-impact signal — see
#'   [pa_synth_events()] Details.
#' - `padm_demo_raw`: [pa_synth_raw()] applied to `padm_demo_event` — a messy
#'   Workday-style export of the same data, for demonstrating the
#'   standardize-to-`padm` step.
#'
#' @name padm_demo_data
#' @aliases padm_demo_org_unit padm_demo_job padm_demo_person padm_demo_event padm_demo_raw
#' @docType data
#' @keywords datasets
NULL
