#' Generate a synthetic org hierarchy
#'
#' Builds a `padm`-conforming `pa_org_unit` table: a single root at level 1,
#' with the remaining units distributed across levels `2:depth`, each
#' attached to a randomly chosen unit at the level above. All units are
#' treated as open since inception (`valid_from = 2015-01-01`, `valid_to =
#' NA`) — v0 does not simulate reorgs.
#'
#' @param n_units Total number of org units, including the root. Must be
#'   `>= depth`.
#' @param depth Number of levels in the hierarchy (root is level 1).
#' @param seed Integer seed for reproducibility.
#' @return A data frame conforming to `pa_org_unit`
#'   (`spec/padm/schemas/pa_org_unit.schema.json`).
#' @export
pa_synth_org <- function(n_units = 15, depth = 3, seed = 1) {
  stopifnot(n_units >= depth, depth >= 1)

  withr::with_seed(seed, {
    ids <- .new_ids("OU", n_units, width = 4)
    level <- integer(n_units)
    parent <- character(n_units)
    level[1] <- 1L
    parent[1] <- NA_character_

    if (depth > 1 && n_units > 1) {
      remaining <- n_units - 1L
      per_level <- diff(floor(seq(0, remaining, length.out = depth)))
      idx <- 2L
      for (lvl in 2:depth) {
        n_here <- per_level[lvl - 1]
        if (n_here <= 0) next
        parent_pool <- ids[level == lvl - 1L]
        for (i in seq_len(n_here)) {
          level[idx] <- lvl
          parent[idx] <- sample(parent_pool, 1L)
          idx <- idx + 1L
        }
      }
    }

    dept_names <- c("Engineering", "Sales", "Operations", "Finance", "People",
                     "Product", "Marketing", "Legal", "Support", "Data")
    name <- vapply(seq_len(n_units), function(i) {
      if (level[i] == 1L) {
        "Company"
      } else if (level[i] == 2L) {
        dept_names[((i - 2L) %% length(dept_names)) + 1L]
      } else {
        sprintf("%s Team %d", name_for_parent(parent[i], ids, level, dept_names), i)
      }
    }, character(1))

    data.frame(
      org_unit_id = ids,
      valid_from = as.Date("2015-01-01"),
      valid_to = as.Date(NA),
      org_unit_name = name,
      parent_org_unit_id = parent,
      org_unit_level = level,
      stringsAsFactors = FALSE
    )
  })
}

#' @keywords internal
name_for_parent <- function(parent_id, ids, level, dept_names) {
  i <- match(parent_id, ids)
  if (is.na(i)) return("Org")
  if (level[i] == 2L) dept_names[((i - 2L) %% length(dept_names)) + 1L] else "Org"
}
