# Standardizes pa.synthetic::pa_synth_raw()'s deliberately messy "workday"
# export back into a padm-conforming pa_event data frame. This is demo-only
# glue code, not a package function: every real integration writes something
# like this once per source system, which is exactly the kind of one-off
# ingest work padm is meant to make checkable (via padm_validate()) rather
# than trustworthy-by-assertion.
#
# Every quirk handled here is documented in pa_synth_raw()'s roxygen block:
# mixed date formats (ISO / US / Excel serial), mixed-case event reason text
# with underscores sometimes rendered as spaces, and stray padding
# whitespace.
standardize_workday <- function(raw) {
  raw_date <- trimws(as.character(raw[["Effective Date"]]))
  is_iso <- grepl("^\\d{4}-\\d{2}-\\d{2}$", raw_date)
  is_us <- grepl("^\\d{1,2}/\\d{1,2}/\\d{4}$", raw_date)
  is_excel <- !is_iso & !is_us & grepl("^\\d+$", raw_date)

  event_date <- as.Date(rep(NA_character_, length(raw_date)))
  event_date[is_iso] <- as.Date(raw_date[is_iso], format = "%Y-%m-%d")
  event_date[is_us] <- as.Date(raw_date[is_us], format = "%m/%d/%Y")
  event_date[is_excel] <- as.Date(as.numeric(raw_date[is_excel]), origin = "1899-12-30")

  # "hire", "leave_start", "exit - voluntary", "Exit - Voluntary", "EXIT -
  # VOLUNTARY" all mean the same thing once lowered, trimmed, and split.
  reason <- tolower(trimws(raw[["Event Reason"]]))
  parts <- strsplit(reason, " - ", fixed = TRUE)
  event_type <- gsub(" ", "_", vapply(parts, `[`, character(1), 1))
  subtype_raw <- vapply(parts, function(p) if (length(p) > 1) p[2] else NA_character_, character(1))
  event_subtype <- gsub(" ", "_", subtype_raw)

  fte <- as.numeric(gsub("%", "", trimws(raw[["FTE %"]]))) / 100

  regretted_raw <- trimws(raw[["Regretted Flag"]])
  is_regretted <- ifelse(regretted_raw == "", NA, regretted_raw == "Y")

  out <- data.frame(
    event_id = NA_character_,
    person_id = raw[["Worker ID"]],
    event_date = event_date,
    event_type = event_type,
    event_subtype = event_subtype,
    is_regretted = is_regretted,
    org_unit_id = raw[["Supervisory Org"]],
    job_id = raw[["Position ID"]],
    manager_person_id = raw[["Manager Worker ID"]],
    fte = fte,
    base_pay_amount = raw[["Annual Salary"]],
    base_pay_currency = raw[["Currency"]],
    source_system = raw[["Source System ID"]],
    stringsAsFactors = FALSE
  )

  out <- out[order(out$person_id, out$event_date), ]
  out$event_id <- sprintf("EV%08d", seq_len(nrow(out)))
  rownames(out) <- NULL
  out
}
