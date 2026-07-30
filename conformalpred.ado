*! version 0.1.0  2026-07-06  Eric A. Booth, Sr Researcher, Texas 2036
*! conformalpred: split-conformal prediction intervals for regress and poisson
*! Distribution-free finite-sample prediction intervals (Shafer & Vovk 2008).
program define conformalpred, rclass
    version 16.0
    // version 16.0: needs only long-stable features (syntax, tempvar,
    // predict, inline Mata); 16 is the floor the book supports.

    syntax , COMMand(string asis) [ Alpha(real 0.05)          ///
        SEED(numlist integer max=1 >=0) SPLit(real 0.5)       ///
        PREfix(name) ]

    * ---- validate options -------------------------------------------------
    if `alpha' <= 0 | `alpha' >= 1 {
        display as error "alpha() must be strictly between 0 and 1"
        exit 198
    }
    if `split' <= 0 | `split' >= 1 {
        display as error "split() must be strictly between 0 and 1"
        exit 198
    }
    if "`prefix'" == "" local prefix "cp"
    if strlen("`prefix'") > 26 {
        display as error "prefix() must be 26 characters or fewer" ///
            " (so `prefix'_lower fits in a variable name)"
        exit 198
    }
    confirm new variable `prefix'_lower
    confirm new variable `prefix'_upper

    * ---- validate the estimation command ----------------------------------
    local cmdline : copy local command
    gettoken cmd rest : cmdline
    local cmd = strtrim("`cmd'")
    local supported ""
    if strpos("regress", "`cmd'") == 1 & strlen("`cmd'") >= 3 {
        local supported "regress"
    }
    else if "`cmd'" == "poisson" {
        local supported "poisson"
    }
    if "`supported'" == "" {
        display as error "command() must begin with {bf:regress} or " ///
            "{bf:poisson}; received {bf:`cmd'}"
        display as error "conformalpred v0.1.0 supports estimators whose" ///
            " default predict is the conditional mean of the outcome"
        exit 198
    }
    if strlen("`rest'") == 0 {
        display as error "command() must name a dependent variable"
        exit 198
    }
    if strpos(" `rest' ", " if ") > 0 | strpos(" `rest' ", " in ") > 0 {
        display as error "command() may not contain if or in;" ///
            " restrict the data in memory before calling conformalpred"
        exit 198
    }

    * ---- seed for a reproducible split ------------------------------------
    if "`seed'" != "" set seed `seed'

    * ---- fit once on the full sample to fix the estimation sample ---------
    quietly `supported' `rest'
    local depvar "`e(depvar)'"
    tempvar esample train
    quietly generate byte `esample' = e(sample)
    quietly count if `esample' == 1
    local n_est = r(N)

    * ---- random split: training vs calibration ----------------------------
    quietly generate byte `train' = (runiform() < `split') if `esample' == 1
    quietly count if `train' == 1
    local n_train = r(N)
    quietly count if `train' == 0
    local n_calib = r(N)
    if `n_train' == 0 | `n_calib' == 0 {
        display as error "the split produced an empty training or" ///
            " calibration set (n = `n_est'); use more data or adjust split()"
        exit 2001
    }

    * ---- refit on the training half only ----------------------------------
    quietly `supported' `rest' if `train' == 1

    * ---- calibration scores: absolute residuals off-sample ----------------
    tempvar yhat resid
    quietly predict double `yhat'
    quietly generate double `resid' = abs(`depvar' - `yhat') if `train' == 0
    quietly count if `train' == 0 & !missing(`resid')
    local n_calib = r(N)
    if `n_calib' == 0 {
        display as error "no usable calibration observations"
        exit 2001
    }
    tempvar calmark
    quietly generate byte `calmark' = (`train' == 0 & !missing(`resid'))

    * ---- conformal quantile: k-th order statistic, k=ceil((1-a)(n+1)) -----
    local k = ceil((1 - `alpha') * (`n_calib' + 1))
    if `k' > `n_calib' {
        display as text "note: calibration set too small for the exact" ///
            " (1-alpha) guarantee; using the maximum residual." ///
            " Increase the sample or raise alpha()."
        local k = `n_calib'
    }
    tempname sQ
    mata: st_numscalar(st_local("sQ"), ///
        _conformalpred_q("`resid'", "`calmark'", `alpha'))

    * ---- interval bounds for every observation predict can reach ----------
    quietly generate double `prefix'_lower = `yhat' - `sQ'
    quietly generate double `prefix'_upper = `yhat' + `sQ'
    local pctlab = strofreal(100 * (1 - `alpha'), "%9.4g")
    label variable `prefix'_lower "Conformal lower bound (`pctlab'% target)"
    label variable `prefix'_upper "Conformal upper bound (`pctlab'% target)"

    * ---- report ------------------------------------------------------------
    display as text ""
    display as text "Split-conformal prediction intervals"
    display as text "{hline 52}"
    display as text "  model             : " as result "`supported' `rest'"
    display as text "  training obs      : " as result `n_train'
    display as text "  calibration obs   : " as result `n_calib'
    display as text "  target coverage   : " as result %5.3f (1 - `alpha')
    display as text "  conformal quantile: " as result %9.0g `sQ'
    display as text "  bounds written to : " ///
        as result "`prefix'_lower, `prefix'_upper"
    display as text "{hline 52}"
    display as text "note: e() now holds the training-half fit of" ///
        " {bf:`supported'}."

    * ---- stored results ----------------------------------------------------
    return scalar Q               = `sQ'
    return scalar alpha           = `alpha'
    return scalar n_calib         = `n_calib'
    return scalar coverage_target = 1 - `alpha'
    return scalar n_train         = `n_train'
    return scalar split           = `split'
    return local  cmd    "`supported'"
    return local  depvar "`depvar'"
    return local  prefix "`prefix'"
end

version 16.0
mata:
real scalar _conformalpred_q(string scalar rvar, string scalar tousev,
                             real scalar alpha)
{
    real colvector r
    real scalar    n, k

    r = st_data(., rvar, tousev)
    r = sort(r, 1)
    n = rows(r)
    k = ceil((1 - alpha) * (n + 1))
    if (k > n) k = n
    return(r[k])
}
end
