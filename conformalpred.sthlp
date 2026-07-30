{smcl}
{* *! version 0.1.0  2026-07-06}{...}
{viewerjumpto "Syntax" "conformalpred##syntax"}{...}
{viewerjumpto "Description" "conformalpred##description"}{...}
{viewerjumpto "Why it works" "conformalpred##why"}{...}
{viewerjumpto "Options" "conformalpred##options"}{...}
{viewerjumpto "Stored results" "conformalpred##results"}{...}
{viewerjumpto "Examples" "conformalpred##examples"}{...}
{viewerjumpto "Remarks" "conformalpred##remarks"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:conformalpred} {hline 2}}Split-conformal prediction intervals for {cmd:regress} and {cmd:poisson}{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:conformalpred} {cmd:,} {cmd:command(}{it:estimation command}{cmd:)} [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{cmd:command(}{it:string}{cmd:)}}the model to wrap, e.g. {cmd:command(regress y x1 x2)}; must begin with {cmd:regress} or {cmd:poisson}; required{p_end}
{synopt :{cmd:alpha(}{it:#}{cmd:)}}miscoverage rate; target coverage is 1-{it:#}; default {cmd:alpha(0.05)}{p_end}
{synopt :{cmd:seed(}{it:#}{cmd:)}}seed for the random training/calibration split; set it for reproducible bounds{p_end}
{synopt :{cmd:split(}{it:#}{cmd:)}}fraction of the estimation sample used for training; default {cmd:split(0.5)}{p_end}
{synopt :{cmd:prefix(}{it:name}{cmd:)}}stub for the two generated variables, {it:name}{cmd:_lower} and {it:name}{cmd:_upper}; default {cmd:prefix(cp)}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:conformalpred} adds distribution-free prediction intervals to an
ordinary {help regress} or {help poisson} fit.  It randomly splits the
estimation sample into a training half and a calibration half, refits the
model on the training half, measures how wrong those predictions are on the
calibration half, and then widens every prediction by the calibration
quantile of those errors.  The result is a pair of new variables,
{cmd:cp_lower} and {cmd:cp_upper} (or your {cmd:prefix()}), holding an
interval for every observation the model can predict for {hline 2} including
observations with a missing outcome, which makes out-of-sample scoring easy.

{pstd}
Unlike the textbook prediction interval from {cmd:predict, stdf}, the
conformal interval does not assume normal, homoskedastic errors.  Its
coverage guarantee holds in finite samples for {it:any} error distribution,
so long as the new observations are exchangeable with (drawn like) the
calibration data.  This is the split-conformal method described in the
Shafer and Vovk (2008) tutorial.


{marker why}{...}
{title:Why the calibration quantile guarantees coverage}

{pstd}
Suppose you have 99 calibration observations and one new observation, all
drawn from the same population.  Compute the absolute prediction error for
each of the 100.  Because the new point is statistically indistinguishable
from the calibration points, its error is equally likely to land at any rank
among the 100 {hline 2} rank 1, rank 50, or rank 100.  So the chance that
the new error exceeds the 90th-smallest calibration error is at most about
10 percent, {it:whatever} the error distribution looks like.  Turning that
around: an interval of plus-or-minus the ceil((1-alpha)(n+1))-th smallest
calibration error covers the new outcome with probability at least 1-alpha.
No normality, no symmetry, no variance formula {hline 2} only the ranking
argument, which is why the guarantee is exact in finite samples and free of
distributional assumptions.


{marker options}{...}
{title:Options}

{phang}{cmd:command(}{it:string}{cmd:)} is the estimation command to wrap.
It must begin with {cmd:regress} (abbreviations of three or more letters
accepted) or {cmd:poisson}, followed by a dependent variable and any
covariates or options, e.g. {cmd:command(regress wage educ exper, vce(robust))}.
It may not contain {cmd:if} or {cmd:in}; restrict the data in memory first.
{cmd:conformalpred} runs the command once on the full sample to fix the
estimation sample, then refits on the training half.{p_end}

{phang}{cmd:alpha(}{it:#}{cmd:)} sets the miscoverage rate, strictly between
0 and 1.  {cmd:alpha(0.1)} targets 90 percent coverage.  Small alphas need
enough calibration observations: the exact guarantee requires
ceil((1-alpha)(n+1)) <= n; otherwise the maximum residual is used and a
note is shown.{p_end}

{phang}{cmd:seed(}{it:#}{cmd:)} seeds Stata's random-number generator before
the split.  Without it the split {hline 2} and therefore the bounds
{hline 2} change on every run.  Always set it in reproducible work.{p_end}

{phang}{cmd:split(}{it:#}{cmd:)} is the expected fraction of the estimation
sample assigned to training, strictly between 0 and 1; the remainder
calibrates.  The default 0.5 is the usual choice: more training sharpens the
point predictions, more calibration steadies the quantile.{p_end}

{phang}{cmd:prefix(}{it:name}{cmd:)} names the generated variables
{it:name}{cmd:_lower} and {it:name}{cmd:_upper}.  They must not already
exist.  Default is {cmd:cp}.{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:conformalpred} stores in {cmd:r()}:{p_end}
{synoptset 20 tabbed}{...}
{synopt :{cmd:r(Q)}}the conformal quantile (interval half-width){p_end}
{synopt :{cmd:r(alpha)}}the miscoverage rate requested{p_end}
{synopt :{cmd:r(n_calib)}}number of calibration observations{p_end}
{synopt :{cmd:r(coverage_target)}}1 - alpha{p_end}
{synopt :{cmd:r(n_train)}}number of training observations{p_end}
{synopt :{cmd:r(split)}}training fraction requested{p_end}
{synopt :{cmd:r(cmd)}}estimator used ({cmd:regress} or {cmd:poisson}){p_end}
{synopt :{cmd:r(depvar)}}dependent variable{p_end}
{synopt :{cmd:r(prefix)}}prefix of the generated bound variables{p_end}
{p2colreset}{...}

{pstd}
After {cmd:conformalpred} runs, {cmd:e()} holds the training-half fit of the
wrapped command, not a full-sample fit.  Refit on the full sample if you
need full-sample coefficients afterwards.


{marker examples}{...}
{title:Examples}

{pstd}90 percent intervals around a wage regression:{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. conformalpred, command(regress wage grade tenure) alpha(0.1) seed(20260706)}{p_end}
{phang2}{cmd:. list wage cp_lower cp_upper in 1/5}{p_end}
{phang2}{cmd:. display r(Q)}{p_end}

{pstd}A count outcome via {cmd:poisson}, custom prefix and a 70/30 split:{p_end}
{phang2}{cmd:. webuse dollhill3, clear}{p_end}
{phang2}{cmd:. conformalpred, command(poisson deaths smokes i.agecat) ///}{p_end}
{phang2}{cmd:      alpha(0.1) seed(20260706) split(0.7) prefix(pi)}{p_end}
{phang2}{cmd:. list deaths pi_lower pi_upper in 1/5}{p_end}

{pstd}Score coverage on a fresh holdout (outcome set to missing keeps the
holdout out of the fit, but predictions and bounds are still generated):{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 6000}{p_end}
{phang2}{cmd:. set seed 20260706}{p_end}
{phang2}{cmd:. generate x = runiform()}{p_end}
{phang2}{cmd:. generate ytrue = 2 + 3*x + (0.5 + x)*rnormal()}{p_end}
{phang2}{cmd:. generate y = ytrue if _n <= 4000}{p_end}
{phang2}{cmd:. conformalpred, command(regress y x) alpha(0.1) seed(12345)}{p_end}
{phang2}{cmd:. generate covered = inrange(ytrue, cp_lower, cp_upper) if _n > 4000}{p_end}
{phang2}{cmd:. summarize covered}{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:What the interval means.}  For {cmd:regress} the interval is centered on
the linear prediction; for {cmd:poisson} it is centered on the predicted
count (the conditional mean, {cmd:predict, n}) and brackets the observed
count.  Both use symmetric absolute-error scores, so intervals have constant
width across observations in v0.1.0; locally adaptive widths (normalized
scores) are a possible extension.  {cmd:logit} is deliberately excluded:
a plus-or-minus band around a predicted probability is not a meaningful
interval for a 0/1 outcome, and honest conformal treatment of binary
outcomes needs conformal {it:sets}, not intervals.

{pstd}
{bf:Randomness.}  The split is random, so Q and the bounds vary across runs
unless you set {cmd:seed()}.  The coverage guarantee holds on average over
splits either way, but reproducible work should fix the seed.

{pstd}
{bf:Reference.}  Shafer, G., and V. Vovk. 2008.  A tutorial on conformal
prediction.  {it:Journal of Machine Learning Research} 9: 371-421.


{title:Author}

{pstd}
Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com), 2026.  MIT-licensed.
