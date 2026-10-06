*Compare whichDIDshouldIuse SFSD classification when condition (1) fails due to a continuous treatment distribution at baseline
clear all
set more off
discard

cap log close
log using test_sfsd_continuous_fail, replace text


/*------------------------------------------------------------------------------
  BLOCK 1 -- raw numdailies (control)
------------------------------------------------------------------------------*/

di as text _n "{hline 78}"
di as text "BLOCK 1 -- Gentzkow et al., raw numdailies (control)"
di as text "{hline 78}"

use "../data/gentzkowetal_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G      T    D
whichDIDshouldIuse prestout cnty90 year numdailies, detail


/*------------------------------------------------------------------------------
  BLOCK 2 -- continuous baseline

  Same panel, same Fg's, continuous d_baseline.
------------------------------------------------------------------------------*/

di as text _n(2) "{hline 78}"
di as text "BLOCK 2 -- same panel, baseline made continuously distributed"
di as text "{hline 78}"

* County-constant shift in [0,1). numdailies is an integer count, so a shifted
* baseline stays inside its own unit interval and cannot collide with a county
* that had a different raw baseline.
*
* NOTE -- d_cont is deliberately FLOAT, not double. The program builds
* d_baseline with an untyped -gen-/-egen- (section 2), so d_baseline is float.
* A double d would then be compared against a float copy of itself in
*     d != d_baseline        (section 3)
* and the low bits would differ, making EVERY period look like a departure
* from baseline: every county becomes a switcher, the switch window shifts,
* and sd(first_change) collapses to 0. The 1006_noedit log shows exactly that
* (n_switchers 1149 -> 1195, switch periods 2..16 -> 1..14, heterog_dose 0).
* float keeps d and d_baseline bit-identical, so only the baseline CELLS
* change and the comparison with Block 1 stays clean.
set seed 90210
bys cnty90: gen byte first_g = (_n == 1)
gen float u = runiform() if first_g
bys cnty90: egen float u_g = max(u)
gen float d_cont = numdailies + u_g	//add a continuous variable u ~ U(0,1)

* Show the baseline really is all-distinct: one value per county.
di as text _n "--- is the baseline continuous? ---"
di as text "  distinct counties:"
distinct cnty90
di as text "  distinct baseline values at the first period of each county:"
distinct d_cont if first_g
di as text "  (the two counts should match: every county its own baseline)"

di as text _n "--- whichDIDshouldIuse on the continuous baseline ---"
whichDIDshouldIuse prestout cnty90 year d_cont, detail

*they don't all switch at the same time bc the same u ~ U(0,1) is being added to each treatment within each group. So if D1 = D2 for some group g, that group hasn't yet switched

di as text _n "  r(design)    = " as result "`r(design)'"    as text "   expected SFSD"
di as text    "  r(sfsd_case) = " as result "`r(sfsd_case)'" as text "   expected continuous-baseline"
di as text    "  r(sfsd_pair) = " as result r(sfsd_pair)     as text "   expected 0"
di as text    "  r(same_Fg)   = " as result r(same_Fg)       as text "   expected 0  (this is what carries the design)"


/*------------------------------------------------------------------------------
  BLOCK 3 -- negative control: continuous baseline, NO timing variation

  The fallback must not fire on everything. Here every baseline is distinct
  (so sfsd_pair = 0, same as Block 2) but all three switchers move at the
  SAME date t = 3, so same_Fg = 1 and condition (ii) fails too. There is no
  design left: expect OTHER.

  This is what separates "the fallback works" from "the fallback fires
  always". Without it Block 2 alone cannot tell the two apart.
------------------------------------------------------------------------------*/

di as text _n(2) "{hline 78}"
di as text "BLOCK 3 -- negative control: distinct baselines, common switch date"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 1.1
1 2002 11 1.1
1 2003 12 2.6
1 2004 13 2.6
2 2001 20 2.2
2 2002 21 2.2
2 2003 22 3.7
2 2004 23 3.7
3 2001 30 3.3
3 2002 31 3.3
3 2003 32 4.8
3 2004 33 4.8
end

whichDIDshouldIuse y g year d, detail

di as text _n "  r(design)    = " as result "`r(design)'"    as text "   expected OTHER"
di as text    "  r(sfsd_case) = " as result "`r(sfsd_case)'" as text "   expected empty"
di as text    "  r(sfsd_pair) = " as result r(sfsd_pair)     as text "   expected 0"
di as text    "  r(same_Fg)   = " as result r(same_Fg)       as text "   expected 1  (blocks the fallback)"
di as text _n "  The OTHER report above must print BOTH SFSD failure reasons:"
di as text    "  the baseline-pair one AND the new 'no variation in first-switch"
di as text    "  timing either' line."

log close





