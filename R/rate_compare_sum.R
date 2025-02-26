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

#' Unstratified and Stratified  Miettinen and Nurminen Test in Aggregate Data level
#'
#' Unstratified and Stratified  Miettinen and Nurminen Test.
#'
#' @param n0,n1 the sample size in the control group and experimental group, separately. The length should be the same as the length for `x0/x1` and `strata`.
#' @param x0,x1 the number of events in the control group and experimental group, separately. The length should be the same as the length for `n0/n1` and `strata`.
#' @param strata a vector of stratum indication to be used in the analysis. If `NULL` or the length of unique values of `strata` equals to 1, it is unstratified MN analysis. Otherwise,
#' it is stratified MN analysis. The length of `strata` should be the same as the length for `x0/x1` and `n0/n1`.
#' @param delta a numeric value to set the difference of two group under the null.
#' @param weight weighting schema used in stratified MN method. Default is "ss".
#' - `"equal"` for equal weighting,
#' - `"ss"` for sample size weighting,
#' - `"cmh"` for Cochran Mantel-Haenszel's weights.
#' @param test a character string specifying the side of p-value,
#' must be one of `"one.sided"`, or `"two.sided"`.
#' @param bisection the number of sections in the interval used in Bisection Method. Default is 100.
#' @param eps the level of precision. Default is eps=1e-06.
#' @param alpha pre-defined alpha level for two-sided confidence interval.
#' @references Miettinen, O. and Nurminen, M, \emph{Comparative Analysis of Two Rates}. Statistics in Medicine, 4:213-226, 1985.
#' @examples
#'
#' ## To conduct the stratified MN analysis with sample size weights:
#' treatment <- c(rep("pbo", 100), rep("exp", 100))
#' response <- c(rep(0, 80), rep(1, 20), rep(0, 40), rep(1, 60))
#' stratum <- c(rep(1:4, 12), 1, 3, 3, 1, rep(1:4, 12), rep(1:4, 25))
#' n0 <- sapply(split(treatment[treatment == "pbo"], stratum[treatment == "pbo"]), length)
#' n1 <- sapply(split(treatment[treatment == "exp"], stratum[treatment == "exp"]), length)
#' x0 <- sapply(split(response[treatment == "pbo"], stratum[treatment == "pbo"]), sum)
#' x1 <- sapply(split(response[treatment == "exp"], stratum[treatment == "exp"]), sum)
#' strata <- c("a", "b", "c", "d")
#' rate_compare_sum(
#'   n0, n1, x0, x1,
#'   strata,
#'   delta = 0,
#'   weight = "ss",
#'   test = "one.sided",
#'   alpha = 0.05
#' )
#' @export

rate_compare_sum <- function(n0, n1,
                             x0, x1,
                             strata = NULL,
                             delta = 0,
                             weight = c("ss", "equal", "cmh"),
                             test = c("one.sided", "two.sided"),
                             bisection = 100,
                             eps = 1e-06,
                             alpha = 0.05) {
  if (any(is.na(c(n0, n1, x0, x1))) | all(c(x0, x1) == 0)) {
    z <- data.frame(
      est = NA, z_score = NA,
      p = NA, lower = NA, upper = NA
    )
    return(z)
  }

  test <- match.arg(test)
  weight <- match.arg(weight)

  len <- c(length(n0), length(n1), length(x0), length(x1))
  if (!is.null(strata)) len <- c(len, length(strata))
  if (max(len) != min(len)) {
    stop("The length of input parameters n0, n1, x0, x1, and strata are different.")
  }

  # Count the event
  n <- n0 + n1
  c <- x0 + x1
  r1 <- x1 / n1
  r0 <- x0 / n0

  # start the analysis
  l3 <- n
  l2 <- (n1 + 2 * n0) * delta - n - c
  l1 <- (n0 * delta - n - 2 * x0) * delta + c
  l0 <- x0 * delta * (1 - delta)

  q <- (l2 / (3 * l3))^3 - l1 * l2 / (6 * l3^2) + l0 / (2 * l3)
  sign <- ifelse(q > 0, 1, -1)
  p <- sqrt((l2 / (3 * l3))^2 - l1 / (3 * l3)) * sign

  # calcualte R tilter
  temp <- q / (p^3)
  # to limit this temo within (-1,1)
  temp <- pmax(pmin(temp, 1), -1)
  a <- (pi + acos(temp)) / 3

  # Start to calculate R tilter
  r0t <- 2 * p * cos(a) - l2 / (3 * l3)
  r1t <- r0t + delta
  vart <- (r1t * (1 - r1t) / n1 + r0t * (1 - r0t) / n0) * (n / (n - 1))

  if (is.null(strata) | length(unique(strata)) == 1) {
    r_diff <- (r1 - r0)
    z_score <- (r_diff - delta) / sqrt(vart)
    pval <- switch(test,
      one.sided = ifelse(delta <= 0, 1 - pnorm(z_score), pnorm(z_score)),
      two.sided = 1 - pchisq(z_score^2, 1)
    )
  }
  if (!length(unique(strata)) == 1) {
    # Start to calculate the chi-square
    w <- switch(weight,
      equal = rep(1, length(strata)),
      ss = n / sum(n),
      cmh = (n0 * n1 / n) / sum(n0 * n1 / n)
    )
    r1_w <- r1 * w
    r0_w <- r0 * w
    var_w <- w^2 * vart
    r_diff <- (sum(r1_w) - sum(r0_w))
    z_score <- (r_diff - delta) / sqrt(sum(var_w))
    pval <- switch(test,
      one.sided = ifelse(delta <= 0, 1 - pnorm(z_score), pnorm(z_score)),
      two.sided = 1 - pchisq(z_score^2, 1)
    )
  }

  # bisection function to find the roots
  # f is the function for which the root is sought,
  # a and b are minimum and maximum of the interval
  # which contains the root from Bisection Method
  biroot <- function(f, a, b) {
    h <- abs(b - a) / bisection
    i <- 0
    j <- 0
    a1 <- b1 <- 0
    roots <- c()
    while (i <= bisection) {
      a1 <- a + i * h
      b1 <- a1 + h
      if (f(a1) * f(b1) < 0) {
        repeat {
          if (abs(b1 - a1) < eps) {
            break
          }
          x <- (a1 + b1) / 2
          if (f(a1) * f(x) < 0) {
            b1 <- x
          } else {
            a1 <- x
          }
        }
        j <- j + 1
        roots[j] <- (a1 + b1) / 2
      }
      i <- i + 1
    }
    if (j == 0) {
      print(paste(
        "After", bisection,
        "loops lower or uppder limit was not found: change initial lower or upper bound."
      ))
    } else {
      return(roots)
    }
  }

  # # Start to calculate the Confidence Interval
  func_d <- function(d) {
    l3 <- n
    l2 <- (n1 + 2 * n0) * d - n - c
    l1 <- (n0 * d - n - 2 * x0) * d + c
    l0 <- x0 * d * (1 - d)

    q <- (l2 / (3 * l3))^3 - l1 * l2 / (6 * l3^2) + l0 / (2 * l3)
    sign <- ifelse(q > 0, 1, -1)
    p <- sqrt((l2 / (3 * l3))^2 - l1 / (3 * l3)) * sign
    # Adust p
    p <- ifelse(p > (-1e-20) & p < 0,
      p - 1e-16,
      ifelse(
        p >= 0 & p < (1e-20),
        p + 1e-16,
        p
      )
    )
    # calculate R tilter
    temp <- q / (p^3)
    # to limit this temp within (-1,1)
    temp <- pmax(pmin(temp, 1), -1)
    a <- (pi + acos(temp)) / 3
    # Start to calculate R tilter
    r0t <- 2 * p * cos(a) - l2 / (3 * l3)
    r1t <- r0t + d
    vart <- (r1t * (1 - r1t) / n1 + r0t * (1 - r0t) / n0) * (n / (n - 1))

    if (is.null(strata) | length(unique(strata)) == 1) {
      r_diff <- (x1 / n1 - x0 / n0)
      chisq_obs <- (r_diff - d)^2 / vart
    }
    if (!length(unique(strata)) == 1) {
      # Start to calculate the chi-square
      r1_w <- r1 * w
      r0_w <- r0 * w
      var_w <- w^2 * vart
      vs <- sum(var_w)

      r_diff <- sum(r1_w) - sum(r0_w)
      chisq_obs <- (r_diff - d)^2 / vs
    }
    return(chisq_obs - qchisq(1 - alpha, 1))
  }

  ci <- biroot(f = func_d, a = -0.999, b = 0.999)
  ci <- ci[(abs(ci) < 1)]

  z <- data.frame(
    est = r_diff, z_score = z_score,
    p = pval, lower = ci[1], upper = ci[2]
  )
  z
}
