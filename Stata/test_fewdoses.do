/*==============================================================================
  test_fewdoses.do
  What happens to whichDIDshouldIuse (and to did_had underneath it) when the
  HAD panel has FEWER THAN TWO POSITIVE DOSES at the switch date.

  Working directory must be Stata/. Stata's exit code is NOT reliable: read
  the log. There is no PASS/FAIL tally here -- each case prints what it got
  next to what is expected, and you compare by eye.

  ---------------------------------------------------------------------------
  Why this case is special
  ---------------------------------------------------------------------------
  did_had's quasi-stayer statistic uses the two smallest POSITIVE doses at
  the switch date,

        QS = D_(1) / ( D_(2) - D_(1) ),

  so it needs at least two of them. The package already intercepts the
  D_(1) == D_(2) tie before calling did_had (scalar had_tie, section 7b) and
  returns had_case = "none". It does NOT intercept the case where D_(2) does
  not exist at all: with exactly one positive dose had_tie is 0 (only one
  group matches the minimum, not two), so control reaches the else-branch and
  did_had is called. Inside did_had, Mata subscripts D_2_np[2,1] on a
  one-row vector -- a subscript error (r(3301)), not a silent missing.

  The package wraps that call in -capture- and then -confirm matrix
  e(estimates)-, so the failure is absorbed: qs_pval stays missing and
  had_case becomes "undetermined". This file checks that this is what
  actually happens, and lets you judge whether "undetermined" is the answer
  we want -- with one positive dose and no stayers there is, by definition,
  no quasi-stayer, so arguably had_case should be "none" for the same reason
  the tie case is.

  ---------------------------------------------------------------------------
  Cases (all panels: 2001..2006, common switch date 2004, zero baseline)
  ---------------------------------------------------------------------------
    A  one switcher, one positive dose, no stayers  -> did_had errors inside;
                                                       expect "undetermined"
    B  one positive dose but stayers present        -> short-circuits on
                                                       n_stayers > 0; expect
                                                       "stayers"
    C  no positive dose at all (negative doses)     -> had_d_min missing;
                                                       should not be HAD
    D  two DISTINCT positive doses                  -> minimum viable QS test
                                                       (control, must work)
    E  two TIED lowest positive doses               -> already-handled path;
                                                       expect "none"

  C, D and E are controls: they pin the boundaries that are already covered,
  so a surprise in A is isolated to the missing-D_(2) case.
==============================================================================*/

clear all
set more off
discard


/*------------------------------------------------------------------------------
  CASE A -- one switcher, one positive dose, no stayers

  Note on the construction: any group sitting at d = 0 ON the switch date is
  a STAYER, which short-circuits section 7b before did_had is reached. So the
  only panel that genuinely has one positive dose and no stayers is a panel
  with a SINGLE switcher: g1 leaves baseline, g2 and g3 never switch at all
  and are therefore dropped as never-switchers rather than counted as
  stayers.

  Expected: design HAD, had_case "undetermined", qs_pval missing,
            did_had itself failing with r(3301).
  If instead the design comes back as something other than HAD, this path is
  unreachable in practice and the gap is moot -- that is a useful answer too.
------------------------------------------------------------------------------*/
di as text _n "{hline 78}"
di as text "CASE A -- one switcher, one positive dose, no stayers"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 0
1 2002 10 0
1 2003 10 0
1 2004 13 -3
1 2005 13 -3
1 2006 13 -3
2 2001 10 0
2 2002 10 0
2 2003 10 0
2 2004 10 0
2 2005 10 0
2 2006 10 0
3 2001 11 0
3 2002 11 0
3 2003 11 0
3 2004 11 0
3 2005 11 0
3 2006 11 0
end

* Reference: what does did_had do on its own? Expect a Mata subscript error
* (r(3301)), or an exit leaving no e(estimates).
di as text _n "--- did_had on its own ---"
capture noisily did_had y g year d, effects(1) graph_off _no_updates
di as text "did_had rc = " as result _rc
capture confirm matrix e(estimates)
if (_rc == 0) matrix list e(estimates)
else di as text "e(estimates) does NOT exist"

di as text _n "--- whichDIDshouldIuse ---"
whichDIDshouldIuse y g year d, detail
di as text _n "  r(design)    = " as result "`r(design)'"   as text "   expected HAD"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   expected undetermined"
di as text    "  r(n_stayers) = " as result r(n_stayers)
di as text    "  r(had_tie)   = " as result r(had_tie)      as text "   expected 0"
di as text    "  r(had_d_min) = " as result r(had_d_min)
di as text    "  r(qs_stat)   = " as result r(qs_stat)      as text "   expected missing"
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   expected missing"


/*------------------------------------------------------------------------------
  CASE B -- one positive dose, but stayers present

  g1 and g4 switch; g2 and g3 stay at d = 0 throughout with d observed. If
  they register as stayers, section 7b takes the first branch and did_had is
  never called.

  Expected: had_case "stayers", qs_pval missing (never computed).
------------------------------------------------------------------------------*/
di as text _n(2) "{hline 78}"
di as text "CASE B -- one positive dose, stayers present"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 0
1 2002 10 0
1 2003 10 0
1 2004 13 3
1 2005 13 3
1 2006 13 3
2 2001 10 0
2 2002 10 0
2 2003 10 0
2 2004 11 0
2 2005 11 0
2 2006 11 0
3 2001 11 0
3 2002 11 0
3 2003 11 0
3 2004 12 0
3 2005 12 0
3 2006 12 0
4 2001 12 0
4 2002 12 0
4 2003 12 0
4 2004 16 4
4 2005 16 4
4 2006 16 4
end

whichDIDshouldIuse y g year d, detail
di as text _n "  r(design)    = " as result "`r(design)'"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   expected stayers"
di as text    "  r(n_stayers) = " as result r(n_stayers)    as text "   expected > 0"
di as text    "  r(had_d_min) = " as result r(had_d_min)
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   expected missing"


/*------------------------------------------------------------------------------
  CASE C -- no positive dose at all

  Every group leaves baseline downward (d: 0 -> negative). had_d_min is
  summed over d > 0 only, so r(N) == 0 and had_d_min is missing. This also
  trips nonneg_dose, so the panel should not reach HAD in the first place.

  Expected: design NOT HAD, nonneg_dose 0, had_d_min missing, had_case empty.
------------------------------------------------------------------------------*/
di as text _n(2) "{hline 78}"
di as text "CASE C -- no positive dose (negative doses only)"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 0
1 2002 10 0
1 2003 10 0
1 2004 8 -2
1 2005 8 -2
1 2006 8 -2
2 2001 10 0
2 2002 10 0
2 2003 10 0
2 2004 7 -3
2 2005 7 -3
2 2006 7 -3
3 2001 11 0
3 2002 11 0
3 2003 11 0
3 2004 7 -4
3 2005 7 -4
3 2006 7 -4
end

whichDIDshouldIuse y g year d, detail
di as text _n "  r(design)     = " as result "`r(design)'"
di as text    "  r(had_case)   = " as result "`r(had_case)'" as text "   expected empty"
di as text    "  r(nonneg_dose)= " as result r(nonneg_dose)  as text "   expected 0"
di as text    "  r(had_d_min)  = " as result r(had_d_min)    as text "   expected missing"


/*------------------------------------------------------------------------------
  CASE D -- two DISTINCT positive doses (control: minimum viable test)

  Doses at the switch: {1, 4, 6, 7, 9}. D_(1) = 1, D_(2) = 4, so
  QS = 1/(4-1) = 0.333 and p = 1/(1+QS) = 0.75 -> do not reject -> the null
  (quasi-stayers exist) stands -> had_case = "quasi-stayers".

  did_had needs enough groups for lprobust to choose a bandwidth. If this
  case fails with a bandwidth error rather than a classification mismatch,
  that is a did_had small-sample limit, not a package bug -- the log will
  say which.
------------------------------------------------------------------------------*/
di as text _n(2) "{hline 78}"
di as text "CASE D -- two distinct positive doses (control)"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 0
1 2002 10 0
1 2003 10 0
1 2004 11 1
1 2005 11 1
1 2006 11 1
2 2001 10 0
2 2002 10 0
2 2003 10 0
2 2004 14 4
2 2005 14 4
2 2006 14 4
3 2001 11 0
3 2002 11 0
3 2003 11 0
3 2004 20 9
3 2005 20 9
3 2006 20 9
4 2001 12 0
4 2002 12 0
4 2003 12 0
4 2004 18 6
4 2005 18 6
4 2006 18 6
5 2001 9 0
5 2002 9 0
5 2003 9 0
5 2004 16 7
5 2005 16 7
5 2006 16 7
end

di as text _n "--- did_had on its own ---"
capture noisily did_had y g year d, effects(1) graph_off _no_updates
di as text "did_had rc = " as result _rc
capture confirm matrix e(estimates)
if (_rc == 0) {
    matrix ref = e(estimates)
    di as text "did_had QS = " as result ref[1,8] as text ", p = " as result ref[1,9]
}

di as text _n "--- whichDIDshouldIuse ---"
whichDIDshouldIuse y g year d, detail
di as text _n "  r(design)    = " as result "`r(design)'"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   expected quasi-stayers"
di as text    "  r(had_tie)   = " as result r(had_tie)      as text "   expected 0"
di as text    "  r(qs_stat)   = " as result r(qs_stat)      as text "   expected ~0.333"
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   expected ~0.75"


/*------------------------------------------------------------------------------
  CASE E -- two TIED lowest positive doses (control: already handled)

  Doses at the switch: {2, 2, 5, 7}. D_(1) = D_(2) = 2, so had_tie = 1,
  did_had is never called, and had_case must be "none" with qs_pval left
  missing and qs_reject = 1.
------------------------------------------------------------------------------*/
di as text _n(2) "{hline 78}"
di as text "CASE E -- two tied lowest positive doses (already handled)"
di as text "{hline 78}"

clear
input g year y d
1 2001 10 0
1 2002 10 0
1 2003 10 0
1 2004 12 2
1 2005 12 2
1 2006 12 2
2 2001 10 0
2 2002 10 0
2 2003 10 0
2 2004 12 2
2 2005 12 2
2 2006 12 2
3 2001 11 0
3 2002 11 0
3 2003 11 0
3 2004 18 7
3 2005 18 7
3 2006 18 7
4 2001 12 0
4 2002 12 0
4 2003 12 0
4 2004 17 5
4 2005 17 5
4 2006 17 5
end

whichDIDshouldIuse y g year d, detail
di as text _n "  r(design)    = " as result "`r(design)'"   as text "   expected HAD"
di as text    "  r(had_case)  = " as result "`r(had_case)'" as text "   expected none"
di as text    "  r(had_tie)   = " as result r(had_tie)      as text "   expected 1"
di as text    "  r(had_d_min) = " as result r(had_d_min)    as text "   expected 2"
di as text    "  r(qs_pval)   = " as result r(qs_pval)      as text "   expected missing"
di as text    "  r(qs_reject) = " as result r(qs_reject)    as text "   expected 1"


/*------------------------------------------------------------------------------
  How to read the log
------------------------------------------------------------------------------*/
di as text _n(2) "{hline 78}"
di as text "CASE A is the one to read closely. Its expected values encode the"
di as text "CURRENT behaviour (undetermined), not necessarily the DESIRED one."
di as text ""
di as text "If A gives had_case = undetermined with did_had rc = 3301, the"
di as text "uncovered path is confirmed: a single positive dose reaches did_had"
di as text "and fails there, instead of being intercepted the way had_tie"
di as text "intercepts the tie. The fix would be a count of distinct positive"
di as text "doses alongside had_tie in section 7b."
di as text ""
di as text "If A does not classify as HAD at all, the path is unreachable in"
di as text "practice and no fix is needed."
di as text "{hline 78}"
