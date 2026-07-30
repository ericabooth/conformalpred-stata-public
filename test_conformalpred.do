* ==========================================================================
* test_conformalpred.do -- test battery for conformalpred v0.1.0
* Run in batch from any scratch directory:  stata-mp -b do test_conformalpred.do
* All paths live in globals set here; nothing below is hard-coded.
* ==========================================================================
if "$pkgroot" == "" {
    global pkgroot "/Users/ebooth/Documents/GitHub/Book Manuscript:Applied Evaluation-Stata/conformalpred-stata-public"
}
adopath + "$pkgroot"

clear all
set more off
set seed 20260706

display as text "{hline 70}"
display as text "TEST 1: regress, heteroskedastic DGP, coverage on a fresh holdout"
display as text "{hline 70}"

* y = 2 + 3x + (0.5 + x) * N(0,1): variance grows with x, so the
* textbook normal interval is wrong but the conformal one is not.
clear
set obs 6000
generate double x     = runiform()
generate double ytrue = 2 + 3*x + (0.5 + x)*rnormal()
generate double y     = ytrue if _n <= 4000   // last 2000 = fresh holdout

conformalpred, command(regress y x) alpha(0.1) seed(12345)

* -- stored results
assert abs(r(alpha) - 0.1) < 1e-10
assert abs(r(coverage_target) - 0.9) < 1e-10
assert r(Q) > 0 & !missing(r(Q))
assert r(n_calib) > 0 & r(n_train) > 0
assert r(n_train) + r(n_calib) == 4000
assert abs(r(split) - 0.5) < 1e-10
assert "`r(cmd)'" == "regress"
assert "`r(depvar)'" == "y"
assert "`r(prefix)'" == "cp"
scalar Q1 = r(Q)
scalar ncal1 = r(n_calib)

* -- predict-then-check: bounds are yhat +/- Q around the training fit
predict double yh, xb
assert abs((cp_upper - yh) - Q1) < 1e-8 if !missing(cp_upper, yh)
assert abs((yh - cp_lower) - Q1) < 1e-8 if !missing(cp_lower, yh)
assert abs((cp_upper - cp_lower) - 2*Q1) < 1e-8 if !missing(cp_lower)

* -- bounds exist for the holdout even though y is missing there
count if _n > 4000 & !missing(cp_lower, cp_upper)
assert r(N) == 2000

* -- empirical coverage on the fresh holdout: target 90%
generate byte covered = inrange(ytrue, cp_lower, cp_upper) if _n > 4000
quietly summarize covered
display as text "holdout coverage = " as result %6.4f r(mean)
assert inrange(r(mean), 0.85, 0.95)

display as text "{hline 70}"
display as text "TEST 2: seed() reproducibility -- same seed, identical bounds"
display as text "{hline 70}"

conformalpred, command(regress y x) alpha(0.1) seed(12345) prefix(cp2)
assert abs(r(Q) - Q1) < 1e-12
assert r(n_calib) == ncal1
assert abs(cp2_lower - cp_lower) < 1e-12 if !missing(cp_lower)
assert abs(cp2_upper - cp_upper) < 1e-12 if !missing(cp_upper)
assert "`r(prefix)'" == "cp2"

display as text "{hline 70}"
display as text "TEST 3: split() fraction and default alpha"
display as text "{hline 70}"

conformalpred, command(regress y x) split(0.7) seed(999) prefix(sp)
assert abs(r(alpha) - 0.05) < 1e-10            // default alpha
assert abs(r(coverage_target) - 0.95) < 1e-10
assert abs(r(split) - 0.7) < 1e-10
* binomial split: n_train ~ Bin(4000, 0.7), sd ~ 29; allow +/- 150
assert inrange(r(n_train), 2650, 2950)
assert r(n_train) + r(n_calib) == 4000

* command abbreviation accepted (reg = regress)
conformalpred, command(reg y x) alpha(0.1) seed(5) prefix(ab)
assert "`r(cmd)'" == "regress"

display as text "{hline 70}"
display as text "TEST 4: poisson, coverage on a fresh holdout, custom prefix"
display as text "{hline 70}"

clear
set obs 6000
generate double x     = runiform()
generate double mu    = exp(0.5 + 1.2*x)
generate double ytrue = rpoisson(mu)
generate double ycnt  = ytrue if _n <= 4000

conformalpred, command(poisson ycnt x) alpha(0.1) seed(777) prefix(pi)
assert "`r(cmd)'" == "poisson"
assert "`r(depvar)'" == "ycnt"
assert r(Q) > 0 & !missing(r(Q))
confirm variable pi_lower
confirm variable pi_upper

generate byte pcov = inrange(ytrue, pi_lower, pi_upper) if _n > 4000
quietly summarize pcov
display as text "poisson holdout coverage = " as result %6.4f r(mean)
assert inrange(r(mean), 0.85, 0.96)

display as text "{hline 70}"
display as text "TEST 5: deliberate error cases"
display as text "{hline 70}"

sysuse auto, clear

* unsupported estimator (logit) must be rejected with 198 before running
capture conformalpred, command(logit foreign mpg) seed(1)
assert _rc == 198

* alpha out of range
capture conformalpred, command(regress price mpg) alpha(1.5) seed(1)
assert _rc == 198

* split out of range
capture conformalpred, command(regress price mpg) split(0) seed(1)
assert _rc == 198

* if/in inside command() is rejected
capture conformalpred, command(regress price mpg if foreign == 1) seed(1)
assert _rc == 198

* overlong prefix
capture conformalpred, command(regress price mpg) seed(1) ///
    prefix(a23456789012345678901234567)
assert _rc == 198

* pre-existing bound variable -> confirm new variable error 110
generate cp_lower = .
capture conformalpred, command(regress price mpg) seed(1)
assert _rc == 110
drop cp_lower

* no such option / empty command
capture conformalpred, command() seed(1)
assert _rc == 198

display as text "{hline 70}"
display as text "ALL conformalpred TESTS PASSED"
display as text "{hline 70}"
