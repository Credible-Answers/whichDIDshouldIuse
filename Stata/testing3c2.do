/*==============================================================================
  testing3c2.do
  Build a synthetic panel that reaches HAD sub-case "none" via the QS-REJECTED
  route: had_tie = 0 (no mass point) and did_had's quasi-stayer test rejects.

  Working directory must be Stata/. Read the log; Stata's exit code lies.

  Target state:
      design      = HAD
      n_stayers   = 0          (else -> "stayers")
      had_tie     = 0          (else -> "none" via the mass-point short-circuit,
                                which is case 3c-i, not what we want here)
      qs_pval < 0.05           (else -> "quasi-stayers")
      had_case    = "none"

  QS = D(1) / (D(2) - D(1)) over the positive doses at the switch; rejects when
  QS > 19, i.e. p = 1/(1+QS) < 0.05. So we need the two smallest positive doses
  CLOSE TOGETHER relative to the smallest one -- doses bounded away from 0 and
  densely packed.

  Reference: had_data1.dta, which does produce a QS test, has 1000 groups,
  10 periods, doses ~U(0,1) continuous. Small panels (6 groups) fail inside
  did_had with r(3301) because lprobust cannot fit a local polynomial.
==============================================================================*/

clear all
set more off
discard



/*------------------------------------------------------------------------------
  ATTEMPT 1 -- 1000 groups, doses U(10, 11), switch at t=6 of 10
  Mirrors had_data1's shape exactly; only the dose support moves away from 0.
  With 1000 draws on an interval of width 1, consecutive order statistics are
  ~0.001 apart while D(1) ~ 10, so QS ~ 10/0.001 = 10000 >> 19.
------------------------------------------------------------------------------*/

di as text _n "{hline 78}"
di as text "ATTEMPT 1 -- 1000 groups, doses U(10,11), switch t=6"
di as text "{hline 78}"

clear
set seed 20261006
set obs 1000
gen g = _n
gen double dose = 10 + runiform()          // positive, bounded away from 0
expand 10
bys g: gen t = _n
gen double d = cond(t >= 6, dose, 0)
gen double y = g/100 + t + rnormal()

whichDIDshouldIuse y g t d, detail

di as text _n "  r(design)    = " as result "`r(design)'"   as text "   want HAD"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   want none"
di as text    "  r(had_tie)   = " as result r(had_tie)      as text "   want 0"
di as text    "  r(n_stayers) = " as result r(n_stayers)    as text "   want 0"
di as text    "  r(qs_stat)   = " as result r(qs_stat)      as text "   want > 19"
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   want < 0.05"


/*------------------------------------------------------------------------------
  ATTEMPT 2 -- same shape, but a MARGINAL rejection

  Attempt 1 works but is extreme: QS ~ 4.0e+04, printed in scientific notation
  by the report's %6.3f. A panel that rejects just past the 5% line is a better
  example -- it shows the test deciding rather than being overwhelmed.

  QS = D(1)/(D(2)-D(1)), so to land near 19 we need the gap between the two
  smallest doses to be about D(1)/19. Rather than fight the order statistics of
  a random draw, set the two lowest doses BY HAND and scatter the rest well
  above them:
        D(1) = 2.00, D(2) = 2.10  ->  QS = 2.00/0.10 = 20,  p = 1/21 = 0.048
------------------------------------------------------------------------------*/

di as text _n(2) "{hline 78}"
di as text "ATTEMPT 2 -- 1000 groups, two lowest doses pinned for QS ~ 20"
di as text "{hline 78}"

clear
set seed 20261006
set obs 1000
gen g = _n
* bulk of the groups sit well above the two lowest doses
gen double dose = 5 + 5*runiform()
* pin the two smallest positive doses
replace dose = 2.00 if g == 1
replace dose = 2.10 if g == 2
expand 10
bys g: gen t = _n
gen double d = cond(t >= 6, dose, 0)
gen double y = g/100 + t + rnormal()

whichDIDshouldIuse y g t d, detail

di as text _n "  r(design)    = " as result "`r(design)'"   as text "   want HAD"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   want none"
di as text    "  r(had_tie)   = " as result r(had_tie)      as text "   want 0"
di as text    "  r(n_stayers) = " as result r(n_stayers)    as text "   want 0"
di as text    "  r(qs_stat)   = " as result r(qs_stat)      as text "   want ~20"
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   want ~0.048"

