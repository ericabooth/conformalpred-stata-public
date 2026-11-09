# conformalpred

Split-conformal prediction intervals for Stata's `regress` and `poisson`.

`conformalpred` wraps an ordinary regression and adds prediction intervals
that do not rest on normal or homoskedastic errors. It randomly splits the
estimation sample into a training half and a calibration half, refits the
model on the training half, measures the absolute prediction errors on the
calibration half, and widens every prediction by the calibration quantile of
those errors. The output is two new variables — `cp_lower` and `cp_upper` by
default — holding an interval for every observation the model can predict
for, including observations whose outcome is missing (useful for scoring a
holdout).

The method is split-conformal prediction (Shafer & Vovk 2008). Its coverage
guarantee is exact in finite samples and free of distributional assumptions:
because a new observation drawn like the calibration data is equally likely
to fall at any rank among the calibration errors, an interval of
plus-or-minus the ceil((1-alpha)(n+1))-th smallest calibration error covers
the new outcome with probability at least 1-alpha. The only requirement is
exchangeability — new points drawn like the calibration points.

Version 0.1.1 supports `regress` (intervals around the linear prediction)
and `poisson` (intervals around the predicted count). Intervals have
constant width across observations; `logit` is excluded because a
plus-or-minus band around a predicted probability is not a meaningful
interval for a 0/1 outcome. The split is random, so set `seed()` whenever
you need reproducible bounds.

## Install

From GitHub:

```stata
net install conformalpred, from("https://raw.githubusercontent.com/ericabooth/conformalpred-stata-public/main/") replace force
help conformalpred
```

## Quick start

```stata
sysuse nlsw88, clear
conformalpred, command(regress wage grade tenure) alpha(0.1) seed(20260706)
list wage cp_lower cp_upper in 1/5
display "half-width Q = " r(Q) ", target coverage = " r(coverage_target)
```

Options inside `command()` go after the comma as usual and are passed to
both fits, for example `command(regress wage grade tenure, vce(robust))`.

Options: `alpha(#)` miscoverage rate (default 0.05), `seed(#)` reproducible
split, `split(#)` training fraction (default 0.5), `prefix(name)` stub for
the generated variables (default `cp`).

## Stored results

| Result | Meaning |
| --- | --- |
| `r(Q)` | conformal quantile (interval half-width) |
| `r(alpha)` | miscoverage rate requested |
| `r(n_calib)` | number of calibration observations |
| `r(coverage_target)` | 1 - alpha |
| `r(n_train)` | number of training observations |
| `r(split)` | training fraction requested |
| `r(cmd)` | estimator used (`regress` or `poisson`) |
| `r(depvar)` | dependent variable |
| `r(prefix)` | prefix of the generated bound variables |

After the call, `e()` holds the training-half fit, not a full-sample fit.

## Changelog

- 0.1.1 (2026-11-09): options inside `command()` now work. In 0.1.0 any
  comma in `command()`, such as `vce(robust)` or `exposure()`, failed with
  "option if not allowed" (r(198)) because the training refit appended
  `if` after the options. The poisson help example now uses `nlsw88`
  (the old `dollhill3` example had 10 observations and failed with the
  documented seed). Results for commands without options are unchanged.
- 0.1.0 (2026-07-06): first release.

## License

MIT. Copyright (c) 2026 Eric A. Booth. See `LICENSE`.
