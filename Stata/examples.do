/*==============================================================================
  examples.do
  Exercise the whichDIDshouldIuse package on the four panels in data/.

  This is the driver: it holds NO classification logic. The program lives in
  whichDIDshouldIuse.ado in this same folder, and is loaded by Stata on first use.

  Each block is labelled with the design it is EXPECTED to return, so a
  mismatch is visible when reading the log:

    Moser-Voena      CLA    (336 subclasses all switch in 1919)
    Wolfers          SAD    (states adopt unilateral divorce at varying dates)
    Gentzkow et al.  SFSD   (#newspapers is a non-absorbing count)
    Pierce-Schott    HAD    (common 2001 switch, continuous NTR-gap dose;
                            sub-case quasi-stayers: did_had QS = 6.15, p = 0.14)

  Every dataset uses different variable names, which is why this is four
  explicit blocks rather than a loop over the .dta files in data/.
  (Do NOT write a star-dot-dta glob here: Stata NESTS block comments, so the
  slash-star inside such a glob opens a second comment level and silently
  swallows the rest of the file.)

  Calls pass , detail on purpose. This log IS the test suite, and a regression
  that prints only "DESIGN: SAD" where SFSD was expected tells you WHAT broke
  but not WHY -- the diagnostics table is the evidence. The Moser-Voena block
  additionally runs once WITHOUT detail so the log also carries one sample of
  default output, which is what confirms the gating still works.
==============================================================================*/

clear all
set more off

*adopath + "."
*discard


/*==============================================================================
  Moser-Voena - CLA
==============================================================================*/

use "../data/moser_voena_didtextbook.dta", clear


* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse    patents  subclass  year   twea

*Detail option 
whichDIDshouldIuse    patents  subclass  year   twea, detail 

di as text _n "r(design)    = " as result r(design)
di as text    "r(estimator) = " as result r(estimator)


/*==============================================================================
  Wolfers - SAD
==============================================================================*/

use "../data/wolfers2006_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse div_rate state year udl, detail

di as text _n "r(design)    = " as result r(design)
di as text    "r(estimator) = " as result r(estimator)


/*==============================================================================
  Gentzkow et. al - SFSD
==============================================================================*/

use "../data/gentzkowetal_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse prestout cnty90 year numdailies, detail

di as text _n "r(design)    = " as result r(design)
di as text    "r(estimator) = " as result r(estimator)

di as text _n "SFSD diagnostics:"
di as text    "  r(sfsd_pair)        = " as result r(sfsd_pair)
di as text    "  r(n_baseline_cells) = " as result r(n_baseline_cells)
di as text    "  r(n_sfsd_cells)     = " as result r(n_sfsd_cells)


/*==============================================================================
  Pierce and Schott - HAD (quasi-stayers)

  This file ships WIDE: one row per industry, with time in the variable NAMES
  (lemp1997..lemp2000, delta2001..delta2005). It must be reshaped to a long
  (Y,G,T,D) panel before whichDIDshouldIuse can see it. The block below follows the
  textbook's own prep (ch. 7):

    - lemp2001/2002/2004/2005 are rebuilt from lemp2000 plus the deltas.
      There is no delta2003, so the panel has a GAP at 2003 -- which is exactly
      what whichDIDshouldIuse's t normalization handles: egen group() makes 2005 the
      period immediately after 2004, so Fg-1 is always a real period.
    - ntrgap is a time-INVARIANT cross-sectional dose (0.02 .. 0.64). Setting
      it to 0 for years <= 2000 is what creates the zero baseline and the
      single common switch date at 2001 (China's WTO accession).

  Note this treatment date is ASSERTED by the prep, not discovered in the data.
==============================================================================*/

use "../data/pierce_schott_didtextbook.dta", clear

gen lemp2001 = lemp2000 + delta2001
gen lemp2002 = lemp2000 + delta2002
gen lemp2004 = lemp2000 + delta2004
gen lemp2005 = lemp2000 + delta2005

reshape long lemp, i(indusid) j(year)
replace ntrgap = 0 if year <= 2000

* whichDIDshouldIuse  Y     G        T     D
whichDIDshouldIuse    lemp  indusid  year  ntrgap, detail

di as text _n "r(design)    = " as result r(design)
di as text    "r(estimator) = " as result r(estimator)

di as text _n "SFSD diagnostics:"
di as text    "  r(sfsd_pair)        = " as result r(sfsd_pair)
di as text    "  r(n_baseline_cells) = " as result r(n_baseline_cells)
di as text    "  r(n_sfsd_cells)     = " as result r(n_sfsd_cells)

di as text _n "HAD sub-case (did_had's quasi-stayer test):"
di as text    "  r(had_case)  = " as result r(had_case)
di as text    "  r(qs_stat)   = " as result r(qs_stat)
di as text    "  r(qs_pval)   = " as result r(qs_pval)
