#    Copyright (c) 2022 Merck & Co., Inc., Rahway, NJ, USA and its affiliates. All rights reserved.
#
#    This file is part of the metalite.ae program.
#
#    metalite.ae is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' Format AE specific analysis
#'
#' @inheritParams extend_ae_specific_inference
#' @param digits_prop a numeric value of number of digits for proportion value.
#' @param digits_ci a numeric value of number of digits for confidence interval
#' @param digits_p a numeric value of number of digits for p-value .
#' @param digits_dur a numeric value of number of digits for average duration of AE
#' @param digits_events a numeric value of number of digits for average of number of AE per subjects.
#' @param display a character vector of measurement to be displayed.
#'  - `n`: number of subjects with AE.
#'  - `prop`: proportion of subjects with AE.
#'  - `total`: total columns
#'  - `diff`: risk difference
#'  - `diff_ci`: 95% confidence interval of risk difference using M&N method
#'  - `diff_p`: p-value of risk difference using M&N method
#'  - `dur`: average of AE duration
#'  - `events`: average number of AE per subject
#' @param mock a boolean value to display mock table
#' @export
format_ae_specific <- function(outdata,
                               display = c("n", "prop", "total"),
                               digits_prop = 1,
                               digits_ci = 1,
                               digits_p = 3,
                               digits_dur = c(1, 1),
                               digits_events = c(1, 1),
                               mock = FALSE) {
  display <- tolower(display)
  display <- match.arg(display,
    c("n", "prop", "total", "diff", "diff_ci", "diff_p", "dur", "events"),
    several.ok = TRUE
  )

  # Add "n"
  display <- unique(c("n", display))

  # Report Missing columns
  display_col <- setdiff(
    names(outdata),
    c(
      "meta", "population", "observation", "parameter",
      "order", "group", "reference_group", "name", "n_pop"
    )
  )
  display_missing <- setdiff(display, c(display_col, "total"))

  # TODO: check missing components
  # if(length(display_missing) > 0){
  #   stop("Missing component in outdata: ", paste(display_missing, collapse = "; "))
  # }

  # Define total column
  display_total <- "total" %in% display
  index_total <- ncol(outdata$n)

  # Create output
  tbl <- list()
  if ("n" %in% display) {
    if (display_total) {
      n <- outdata$n
    } else {
      n <- outdata$n[, -index_total]
    }
    tbl[["n"]] <- n
  }

  if ("prop" %in% display) {
    if (display_total) {
      prop <- outdata$prop
    } else {
      prop <- outdata$prop[, -index_total]
    }
    prop <- apply(prop, 2, fmt_pct, digits = digits_prop, pre = "(", post = ")")
    tbl[["prop"]] <- prop
  }

  if ("diff" %in% display) {
    diff <- apply(outdata$diff, 2, fmt_est, digits = digits_prop)
    tbl[["diff"]] <- diff
  }

  if ("diff_ci" %in% display) {

    if(is.null(outdata$ci_lower)){
      stop("Please use extend_ae_specific_inference() to get the calculation of ci!")
    }

    ci <- outdata$ci_lower * NA
    names(ci) <- gsub("lower", "ci", names(ci))
    for (i in 1:ncol(outdata$ci_lower)) {
      lower <- outdata$ci_lower[[i]]
      upper <- outdata$ci_upper[[i]]
      ci[, i] <- fmt_ci(lower, upper, digits = digits_ci)
    }
    tbl[["diff_ci"]] <- ci
  }

  if ("diff_p" %in% display) {

    if(is.null(outdata$p)){
      stop("Please use extend_ae_specific_inference() to get the calculation of p-values!")
    }

    p <- apply(outdata$p, 2, fmt_pval, digits = digits_p)
    tbl[["diff_p"]] <- p
  }

  if ("dur" %in% display) {

    if(is.null(outdata$dur)){
      stop("Please use extend_ae_specific_duration() to get the calculation of duration!")
    }

    dur <- outdata$dur * NA
    for (i in 1:ncol(outdata$dur)) {
      m <- outdata$dur[[i]]
      se <- outdata$dur_se[[i]]
      dur[, i] <- fmt_est(m, se, digits = digits_dur)
    }
    tbl[["dur"]] <- dur
  }

  if ("events" %in% display) {

    if(is.null(outdata$events)){
      stop("Please use extend_ae_specific_events() to get the calculation of events!")
    }

    events <- outdata$events * NA
    for (i in 1:ncol(outdata$events)) {
      m <- outdata$events[[i]]
      se <- outdata$events_se[[i]]
      events[, i] <- fmt_est(m, se, digits = digits_dur)
    }
    tbl[["events"]] <- events
  }

  # Arrange Within Group information
  within_var <- names(tbl)[names(tbl) %in% c("n", "prop", "dur", "events")]
  within_tbl <- tbl[within_var]

  names(within_tbl) <- NULL
  n_within <- length(within_tbl)
  n_group <- ncol(tbl[["n"]])
  within_tbl <- do.call(cbind, within_tbl)
  within_tbl <- within_tbl[, as.vector(matrix(1:(n_group * n_within), ncol = n_group, byrow = TRUE))]

  # Arrange Between Group information
  between_var <- names(tbl)[names(tbl) %in% c("diff", "diff_ci", "diff_p")]
  between_tbl <- tbl[between_var]

  names(between_tbl) <- NULL
  between_tbl <- do.call(cbind, between_tbl)

  # Create Results
  if (is.null(between_tbl)) {
    res <- within_tbl
  } else {
    res <- data.frame(within_tbl, between_tbl)
  }

  # Transfer to Mock
  if (mock) {
    n_mock <- min(20, nrow(tbl[[1]]), na.rm = TRUE)
    res <- to_mock(res, n = nrow(tbl[[1]]))
  }

  res <- data.frame(name = outdata$name, res)

  if (mock) {
    res <- res[1:n_mock, ]
    outdata$order <- outdata$order[1:n_mock]
  }

  outdata$tbl <- res
  outdata
}
