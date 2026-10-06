*Compare whichDIDshouldIuse SFSD classification when condition (1) fails due to a continuous treatment distribution at baseline
clear all
set more off
discard

cap log close
log using test_sfsd_continuous_success, replace text


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
* that had a different raw baseline. double storage keeps the values distinct.
set seed 90210
bys cnty90: gen byte first_g = (_n == 1)	
gen double u = runiform() if first_g
bys cnty90: egen double u_g = max(u)
gen double d_cont = numdailies + u_g	//add a continuous variable u ~ U(0,1)

* Show the baseline really is all-distinct: one value per county.
di as text _n "--- is the baseline continuous? ---"
di as text "  distinct counties:"
distinct cnty90
di as text "  distinct baseline values at the first period of each county:"
distinct d_cont if first_g
di as text "  (the two counts should match: every county its own baseline)"

di as text _n "--- whichDIDshouldIuse on the continuous baseline ---"
whichDIDshouldIuse prestout cnty90 year d_cont, detail





