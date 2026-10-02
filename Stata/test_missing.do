/*==============================================================================
  test_missing.do
  Tests for the two missing-treatment modes of whichDIDshouldIuse.ado.

  Run make_synthetic.do first (it writes ../data/synthetic/). Working
  directory must be Stata/. Stata's exit code is NOT reliable: read the log,
  and look at the PASS/FAIL tally at the end.

  Part A -- synthetic cases. Each is run two ways:
    whichDIDshouldIuse, strict  (drop-on-any-missing rules)
    whichDIDshouldIuse          (default, less strict rules)
  and the design plus the relevant counter are checked against the values
  expected by construction (see make_synthetic.do).

  Part B -- regression on the four real panels. None has missing treatment
  that either mode acts on, so both calls must return the same design and
  the same core r() scalars.
==============================================================================*/

clear all
set more off
discard

global n_pass 0
global n_fail 0

* check label got expected -- string comparison, so it works for designs and
* for numbers passed through a local.
cap program drop check
program define check
    args label got expected
    if ("`got'" == "`expected'") {
        di as text "PASS  `label'  (" as result "`got'" as text ")"
        global n_pass = $n_pass + 1
    }
    else {
        di as error "FAIL  `label'  got `got', expected `expected'"
        global n_fail = $n_fail + 1
    }
end

* runcase file exp_strict exp_default [cnt exp_cnt [cnt2 exp_cnt2 [scnt exp_scnt]]]
*   cnt, cnt2  counters checked on the DEFAULT run
*   scnt       counter checked on the STRICT run
cap program drop runcase
program define runcase
    args file exp_strict exp_default cnt exp_cnt cnt2 exp_cnt2 scnt exp_scnt

    di as text _n "{hline 70}" _n "CASE: `file'" _n "{hline 70}"
    use "../data/synthetic/`file'.dta", clear
    list g year y d, sepby(g) noobs

    di as text _n "--- whichDIDshouldIuse, strict ---"
    whichDIDshouldIuse y g year d, strict
    local d_strict "`r(design)'"
    if ("`scnt'" != "") local v_scnt = r(`scnt')

    di as text _n "--- whichDIDshouldIuse (default) ---"
    whichDIDshouldIuse y g year d, detail
    local d_def "`r(design)'"
    if ("`cnt'"  != "") local v_cnt  = r(`cnt')
    if ("`cnt2'" != "") local v_cnt2 = r(`cnt2')

    di as text ""
    check "`file': strict design"          "`d_strict'" "`exp_strict'"
    check "`file': default design"         "`d_def'"    "`exp_default'"
    if ("`cnt'"  != "") check "`file': default `cnt'"  "`v_cnt'"  "`exp_cnt'"
    if ("`cnt2'" != "") check "`file': default `cnt2'" "`v_cnt2'" "`exp_cnt2'"
    if ("`scnt'" != "") check "`file': strict `scnt'"  "`v_scnt'" "`exp_scnt'"
end

* regcheck label Y G T D [designonly]
*   strict vs default on a real panel. With designonly, default is held
*   only to the same design -- for a panel whose missing treatment the
*   default rules legitimately keep.
cap program drop regcheck
program define regcheck
    args label Y G T D designonly
    local S n_groups n_switchers n_never_treated same_Fg is_binary is_binary01 ///
            is_absorbing zero_baseline common_baseline heterog_dose sfsd_pair  ///
            n_baseline_cells n_sfsd_cells first_switch_cal last_switch_cal

    qui whichDIDshouldIuse `Y' `G' `T' `D', strict
    local s_design "`r(design)'"
    foreach s of local S {
        local s_`s' = r(`s')
    }
    qui whichDIDshouldIuse `Y' `G' `T' `D'
    local n_design "`r(design)'"
    foreach s of local S {
        local n_`s' = r(`s')
    }

    di as text _n "--- regression: `label' (strict design: " as result "`s_design'" as text ") ---"
    check "`label': default design" "`n_design'" "`s_design'"
    foreach s of local S {
        if ("`designonly'" == "") check "`label': `s' default" "`n_`s''" "`s_`s''"
    }
end


/*==============================================================================
  Part A -- synthetic cases
==============================================================================*/

*       file                  strict  default  default counter(s)                    strict counter
runcase late_entry            OTHER   CLA      n_late_entry 1
runcase missing_at_start      OTHER   CLA      n_missing_at_start 1
runcase pre_gap_switcher      CLA     SAD      n_filled_pre_gap 1
runcase gap_before_switch     OTHER   CLA      n_demoted 1          n_never_treated 1
runcase demote_too_early      OTHER   OTHER    n_demoted 1          n_never_treated 0
runcase control_exit          OTHER   CLA      n_exit_controls 1    n_never_treated 1
runcase control_interior_gap  OTHER   CLA      n_filled_pre_gap 1
runcase post_switch_gap       SAD     SAD      n_post_gap_switchers 1 n_groups 3     n_post_gap_switchers 1
runcase all_d_missing         CLA     CLA      n_dropped_alld 1     n_groups 3       n_dropped_baseline 1


/*==============================================================================
  Part B -- regression on the real panels
==============================================================================*/

use "../data/moser_voena_didtextbook.dta", clear
regcheck "Moser-Voena" patents subclass year twea

use "../data/wolfers2006_didtextbook.dta", clear
regcheck "Wolfers" div_rate state year udl

* Gentzkow is NOT gap-free: d is missing exactly where y is, i.e. counties
* not yet (or no longer) in the panel. The current rules drop the 456 counties
* absent in 1868 (1195 -> 739); the default rules keep them as late entrants.
* So default is held to the same design, and its sample to the values below.
use "../data/gentzkowetal_didtextbook.dta", clear
regcheck "Gentzkow" prestout cnty90 year numdailies designonly

qui whichDIDshouldIuse prestout cnty90 year numdailies
foreach s in n_groups n_late_entry n_missing_at_start n_filled_pre_gap ///
             n_demoted n_exit_controls n_post_gap_switchers {
    local g_`s' = r(`s')
}
check "Gentzkow: default n_groups"             "`g_n_groups'"             "1195"
check "Gentzkow: default n_late_entry"         "`g_n_late_entry'"         "456"
check "Gentzkow: default n_missing_at_start"   "`g_n_missing_at_start'"   "0"
check "Gentzkow: default n_filled_pre_gap"     "`g_n_filled_pre_gap'"     "13"
check "Gentzkow: default n_demoted"            "`g_n_demoted'"            "12"
check "Gentzkow: default n_exit_controls"      "`g_n_exit_controls'"      "1"
check "Gentzkow: default n_post_gap_switchers" "`g_n_post_gap_switchers'" "25"

* Same prep as examples.do (the file ships wide).
use "../data/pierce_schott_didtextbook.dta", clear
gen lemp2001 = lemp2000 + delta2001
gen lemp2002 = lemp2000 + delta2002
gen lemp2004 = lemp2000 + delta2004
gen lemp2005 = lemp2000 + delta2005
reshape long lemp, i(indusid) j(year)
replace ntrgap = 0 if year <= 2000
regcheck "Pierce-Schott" lemp indusid year ntrgap


/*==============================================================================
  Tally
==============================================================================*/

di as text _n "{hline 70}"
di as text "TESTS: " as result $n_pass as text " passed, " as result $n_fail as text " failed"
di as text "{hline 70}"
