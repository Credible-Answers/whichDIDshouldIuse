/*==============================================================================
  make_synthetic.do
  Build the synthetic panels used by test_missing.do, one .dta per case,
  written to ../data/synthetic/.

  Every panel runs over 2001..2006 (t = 1..6) with variables y g year d. Each
  case isolates ONE kind of missing treatment, chosen so that the strict and
  the default (less strict) handling in whichDIDshouldIuse.ado give a
  visibly different answer -- or, for the guard cases, the same answer.

  Two kinds of "missing" are deliberately distinguished:
    - a row that is ABSENT (the group is not in the panel that year): fillin
      recreates it with y and d both missing;
    - a row that is PRESENT with y observed but d missing: the group exists,
      its treatment is unknown.

  Expected results are listed in test_missing.do, next to each check.
==============================================================================*/

clear all
set more off

cap mkdir "../data/synthetic"


/*------------------------------------------------------------------------------
  1. late_entry -- g3 enters in 2003 (rows for 2001-2002 absent)
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 1 0
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 0
2 2004 2 1
2 2005 2 1
2 2006 2 1
3 2003 1 0
3 2004 1 0
3 2005 1 0
3 2006 1 0
end
save "../data/synthetic/late_entry.dta", replace


/*------------------------------------------------------------------------------
  2. missing_at_start -- g3 exists from 2001 (y observed) but d is missing
     in 2001-2002
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 1 0
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 0
2 2004 2 1
2 2005 2 1
2 2006 2 1
3 2001 1 .
3 2002 1 .
3 2003 1 0
3 2004 1 0
3 2005 1 0
3 2006 1 0
end
save "../data/synthetic/missing_at_start.dta", replace


/*------------------------------------------------------------------------------
  3. pre_gap_switcher -- g2 switches in 2005, d missing in 2003, but observed
     at baseline again in 2004 = Fg-1, so Fg is still pinned down
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 .
2 2004 1 0
2 2005 2 1
2 2006 2 1
3 2001 1 0
3 2002 1 0
3 2003 1 0
3 2004 1 0
3 2005 1 0
3 2006 1 0
end
save "../data/synthetic/pre_gap_switcher.dta", replace


/*------------------------------------------------------------------------------
  4. gap_before_switch -- g2 first observed off baseline in 2005, d missing
     in 2004 = Fg-1: the switch could have been in 2004 or 2005. Default mode
     demotes g2 to a control truncated at 2003 (still usable at g1's 2003
     switch).
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 0
2 2004 1 .
2 2005 2 1
2 2006 2 1
end
save "../data/synthetic/gap_before_switch.dta", replace


/*------------------------------------------------------------------------------
  5. demote_too_early (guard) -- like case 4, but g2's known-baseline window
     ends in 2001, before g1's 2005 switch: the truncated control is NOT
     usable, so both modes must return OTHER
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 1 0
1 2004 1 0
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 .
2 2003 1 .
2 2004 1 .
2 2005 2 1
2 2006 2 1
end
save "../data/synthetic/demote_too_early.dta", replace


/*------------------------------------------------------------------------------
  6. control_exit -- the only never-switcher g2 leaves the panel after 2004
     (rows for 2005-2006 absent)
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 0
2 2004 1 0
end
save "../data/synthetic/control_exit.dta", replace


/*------------------------------------------------------------------------------
  7. control_interior_gap -- the only never-switcher g2 has d missing in 2003
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 .
2 2004 1 0
2 2005 1 0
2 2006 1 0
end
save "../data/synthetic/control_interior_gap.dta", replace


/*------------------------------------------------------------------------------
  8. post_switch_gap (guard) -- g1 switches in 2003, d missing in 2004.
     Post-switch gaps are tolerated by both modes: SAD either way.
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 .
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 1 0
2 2004 1 0
2 2005 2 1
2 2006 2 1
3 2001 1 0
3 2002 1 0
3 2003 1 0
3 2004 1 0
3 2005 1 0
3 2006 1 0
end
save "../data/synthetic/post_switch_gap.dta", replace


/*------------------------------------------------------------------------------
  9. all_d_missing (guard) -- g4 exists (y observed) but d is never observed.
     Dropped by both modes: CLA either way.
------------------------------------------------------------------------------*/
clear
input g year y d
1 2001 1 0
1 2002 1 0
1 2003 2 1
1 2004 2 1
1 2005 2 1
1 2006 2 1
2 2001 1 0
2 2002 1 0
2 2003 2 1
2 2004 2 1
2 2005 2 1
2 2006 2 1
3 2001 1 0
3 2002 1 0
3 2003 1 0
3 2004 1 0
3 2005 1 0
3 2006 1 0
4 2001 1 .
4 2002 1 .
4 2003 1 .
4 2004 1 .
4 2005 1 .
4 2006 1 .
end
save "../data/synthetic/all_d_missing.dta", replace
