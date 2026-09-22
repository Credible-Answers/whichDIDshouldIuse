*! whichDIDshouldIuse 0.1  15sep2026
*! Classify a (Y, G, T, D) panel as CLA, SAD, HAD, or SFSD.

/*==============================================================================
  whichDIDshouldIuse.ado

  Classify a (y, g, t, d) panel as CLA, SAD, HAD, or SFSD.

  Definitions follow docs/did-designs-summary.md (authoritative).
  Scope: CLA, SAD, HAD, SFSD. No SSD yet.

  SYNTAX
    whichDIDshouldIuse Y G T D
      Y  outcome
      G  group identifier
      T  the user's CALENDAR time variable (year, quarter, ...)
      D  treatment

  All four are positional and required. The caller passes their OWN variable
  names; no pre-renaming is needed. The program runs inside preserve/restore,
  so the caller's data is unchanged on exit -- which also means the constructed
  variables (Fg, d_baseline, first_change, ...) do NOT survive the call.

  DEPENDENCY
    distinct (SSC):  ssc install distinct

  Coding practice: every classification conditional tests a NAMED SCALAR
  (is_binary, same_Fg, never_treated_groups, ...) defined at the point where
  the underlying statistic is computed. No r(mean)/r(min)/r(max) is read
  inside the classification block -- each r() value is consumed immediately,
  on the line after the command that set it, into a scalar with a meaningful
  name. This keeps nested conditionals readable on their own.

  Baseline treatment is d at the FIRST period of the panel (t == 1), NOT the
  first non-missing value of d. Designs impose conditions on baseline
  treatment, so a group whose treatment is missing in period 1 has no
  verifiable baseline and is dropped. A path like (., ., 0, 0, 1, 1, 1) is
  therefore not valid CLA.

  TIME VARIABLES (package convention):
    t_cal  the user's original calendar date (year, quarter, ...), preserved
           untouched and used ONLY for display.
    t      t_cal normalized to consecutive integers 1..Tmax. ALL operations,
           checks and comparisons run on this.
  Normalizing makes "the period before the switch" exactly Fg-1 regardless of
  gaps in the calendar. Results are translated back to calendar dates for
  display via the cal_of_t crosswalk built in section 1.
==============================================================================*/

program define whichDIDshouldIuse, rclass
    version 14
    syntax varlist(min=4 max=4 numeric)

    * Turn OFF variable-name abbreviation for the whole program. Stata would
    * otherwise resolve a short name to any variable it uniquely prefixes --
    * e.g. "drop t" deletes t_cal when t_cal is the only t* variable, which is
    * exactly the kind of silent data loss this program must not risk.
    local varabbrev_was `c(varabbrev)'
    set varabbrev off

    * The user passes their own variable names; map them onto y g t d.
    tokenize `varlist'
    local Yvar "`1'"
    local Gvar "`2'"
    local Tvar "`3'"
    local Dvar "`4'"

    di in red _n "{hline 70}"
    di in red    "  whichDIDshouldIuse:  Y=`Yvar'  G=`Gvar'  T=`Tvar'  D=`Dvar'"
    di in red    "{hline 70}"

    * Work on a copy: the caller's data is restored on exit.
    preserve

    * This keep is LOAD-BEARING, not just tidying: the program uses bare scalar
    * names (Tmax, n_groups, same_Fg, ...), and Stata resolves a bare name to a
    * VARIABLE before a scalar. Dropping every other variable first guarantees
    * no variable in the caller's data can shadow one of those scalars.
    keep `Yvar' `Gvar' `Tvar' `Dvar'

    * Rename one at a time: the grouped "rename (a b) (c d)" form needs Stata
    * 14+, and under an older version statement it parses as the old
    * single-variable syntax and fails. Renaming individually always works.
    rename `Yvar' y
    rename `Gvar' g
    rename `Tvar' t_cal
    rename `Dvar' d

    drop if missing(g) | missing(t_cal)

    * ---------------------------------------------------------------------- *
    * 1. Time variables: normalize, and build the calendar crosswalk
    * ---------------------------------------------------------------------- *

    * Balance the panel over g x t_cal BEFORE normalizing, so that every group
    * has a row for every calendar period actually present in the data.
    cap drop _fillin
    fillin g t_cal

    * NOTE: do NOT write "cap drop t" here. Stata abbreviates variable names,
    * and since t_cal is the only variable beginning with "t", both "drop t"
    * and "confirm variable t" resolve to t_cal and silently delete it.
    * set varabbrev off makes every name match exactly.
    egen t = group(t_cal)               // consecutive integers 1..Tmax

    qui sum t
    scalar Tmax   = r(max)
    scalar Tplus1 = Tmax + 1            // never-switcher sentinel (normalized)

    * Crosswalk: normalized period -> calendar date. cal_of_t[1,k] is the
    * calendar value of period k, so any result computed in normalized time
    * can be reported as a real date. Read straight off the data rather than
    * via levelsof, which would build a macro holding every distinct calendar
    * value and can hit the macro length limit on a long panel. Each period k
    * maps to exactly one calendar value, so r(min) is that value.
    matrix cal_of_t = J(1, Tmax, .)
    forvalues k = 1/`=Tmax' {
        qui sum t_cal if t == `k'
        matrix cal_of_t[1, `k'] = r(min)
    }

    scalar cal_min = cal_of_t[1, 1]
    scalar cal_max = cal_of_t[1, Tmax]

    order g t t_cal d y
    sort g t

    di in red _n "Panel: " %4.0f Tmax " periods, calendar " %4.0f cal_min " .. " %4.0f cal_max
    di in red    "       (t normalized to 1.." %4.0f Tmax "; never-switcher sentinel = " %4.0f Tplus1 ")"

    * ---------------------------------------------------------------------- *
    * 2. Baseline treatment, and dropping groups without a verifiable baseline
    * ---------------------------------------------------------------------- *

    qui distinct g
    scalar n_groups_raw = r(ndistinct)

    * Baseline = d in the first panel period, t == 1 (literally -- not the
    * first non-missing value). egen min() just spreads that single value to
    * every row of the group; it is NOT a minimum over the path.
    cap drop d_baseline_temp d_baseline
    gen    d_baseline_temp = d if t == 1
    bys g: egen d_baseline = min(d_baseline_temp)

    * No treatment observed in period 1 -> no verifiable baseline -> unusable.
    drop if missing(d_baseline)

    qui distinct g
    scalar n_groups_baseline  = r(ndistinct)
    scalar n_dropped_baseline = n_groups_raw - n_groups_baseline

    di in red "Groups dropped for missing baseline (d at t=1, cal " %4.0f cal_min "): " ///
              n_dropped_baseline "  (" n_groups_raw " -> " n_groups_baseline ")"

    * ---------------------------------------------------------------------- *
    * 3. Date of first switch (Fg), treatment at the switch, size of change
    * ---------------------------------------------------------------------- *

    cap drop t_d_diff_d_baseline Fg
    gen    t_d_diff_d_baseline = t*(d!=. & d!=d_baseline) + Tplus1*(d==. | d==d_baseline)
    bys g: egen Fg = min(t_d_diff_d_baseline)

    cap drop d_Fg_temp d_Fg
    gen    d_Fg_temp = d if t == Fg
    bys g: egen d_Fg = min(d_Fg_temp)

    cap drop first_change
    gen first_change = d_Fg - d_baseline

    * ---------------------------------------------------------------------- *
    * 4. Pre-treatment integrity filter
    *
    *    By construction D_{g,t} = D_{g,1} for all t < F_g, so a group whose
    *    treatment is missing or departs from baseline before Fg has a
    *    MISMEASURED Fg. This is a consistency check on Fg, not an extra
    *    design restriction.
    *
    *    It also protects the identifying comparison: a control g' with
    *    D_{g',1} = D_{g,1} and F_{g'} > F_g is only a valid control if both
    *    histories are genuinely flat and fully observed before the switch.
    *
    *    NOTE for SFSD: because Fg IS the first departure from baseline, this
    *    flag can only ever fire on MISSING d, never on a genuine departure.
    *    SFSD's non-absorbing allowance is entirely POST-Fg, which this filter
    *    never touches -- so no relaxation is needed to admit SFSD panels.
    * ---------------------------------------------------------------------- *

    * Because t is normalized, inrange(t, 1, Fg-1) is exactly "every period
    * from the start of the panel up to the one before the switch" -- Fg-1 is
    * always a real period, which would NOT hold with gappy calendar dates.
    cap drop d_pretreatment_flag_temp d_pretreatment_flag
    gen    d_pretreatment_flag_temp = (d==. | d!=d_baseline) if inrange(t, 1, Fg-1)
    bys g: egen d_pretreatment_flag = max(d_pretreatment_flag_temp)
    drop if d_pretreatment_flag == 1

    qui distinct g
    scalar n_groups           = r(ndistinct)
    scalar n_dropped_pretreat = n_groups_baseline - n_groups

    di in red "Groups dropped for pre-treatment violations: " n_dropped_pretreat ///
              "  (" n_groups_baseline " -> " n_groups ")"

    * ---------------------------------------------------------------------- *
    * 5. Scalar flags
    *
    *    One row per group (first_g) for anything group-level, so that groups
    *    are not weighted by panel length. Every r() is consumed immediately.
    * ---------------------------------------------------------------------- *

    cap drop first_g
    bys g: gen byte first_g = (_n == 1)

    * ---- Never-treated groups ------------------------------------------- *
    qui count if first_g & Fg == Tplus1
    scalar n_never_treated      = r(N)
    scalar never_treated_groups = (n_never_treated > 0)

    * ---- Switchers ------------------------------------------------------- *
    qui count if first_g & Fg < Tplus1
    scalar n_switchers   = r(N)
    scalar any_switchers = (n_switchers > 0)

    * ---- Variation in treatment timing, AMONG SWITCHERS ------------------ *
    * sd() is missing with a single observation; a lone switcher trivially has
    * no timing variation, so missing -> same_Fg = 1 (deliberate).
    cap drop sd_Fg_sw
    egen sd_Fg_sw = sd(Fg) if first_g & Fg < Tplus1
    qui sum sd_Fg_sw
    scalar sd_Fg_value = r(mean)
    scalar same_Fg     = cond(missing(sd_Fg_value), 1, sd_Fg_value == 0)

    * Switch dates in NORMALIZED time. Take min/max rather than a mean: when
    * same_Fg == 1 the min IS the exact shared period, whereas a mean could
    * land between periods.
    qui sum Fg if first_g & Fg < Tplus1
    scalar first_switch_t  = cond(r(N) > 0, r(min), .)
    scalar last_switch_t   = cond(r(N) > 0, r(max), .)
    scalar common_switch_t = first_switch_t     // meaningful only if same_Fg == 1

    * ... and their calendar equivalents, for display only.
    scalar first_switch_cal  = cond(missing(first_switch_t), ., cal_of_t[1, first_switch_t])
    scalar last_switch_cal   = cond(missing(last_switch_t),  ., cal_of_t[1, last_switch_t])
    scalar common_switch_cal = first_switch_cal

    * ---- Is the treatment binary? ---------------------------------------- *
    qui sum d
    scalar d_min = r(min)
    scalar d_max = r(max)

    cap drop binary_check
    gen binary_check = (d == d_min | d == d_max) if !missing(d)
    qui sum binary_check
    scalar is_binary = (r(mean) == 1)

    * Strict {0,1}: the summary's CLA/SAD require D_g in {0,1}, min 0, max 1.
    * Kept separate from is_binary so a {4,9}-style rescaling stays visible
    * rather than being silently accepted.
    scalar is_binary01 = (is_binary == 1 & d_min == 0 & d_max == 1)

    * ---- Is the treatment absorbing? ------------------------------------- *
    * d must equal d_Fg from the switch date onward, for switchers.
    cap drop absorbing_check
    gen absorbing_check = (d == d_Fg) if Fg < Tplus1 & t >= Fg & !missing(d) & !missing(d_Fg)
    qui sum absorbing_check
    scalar n_absorbing_obs = r(N)
    * No post-switch observations -> NOT absorbing. (Deliberately the opposite
    * of sketchdid.ado, which defaults this to 1 and calls such designs
    * absorbing.)
    scalar is_absorbing = cond(n_absorbing_obs == 0, 0, r(min) == 1)

    * ---- Baseline dose ---------------------------------------------------- *
    * HAD requires D_{g,t} = 0 for all g and all t <= T_0.
    qui count if first_g & d_baseline != 0
    scalar n_nonzero_baseline = r(N)
    scalar zero_baseline      = (n_nonzero_baseline == 0)

    * Common (but not necessarily zero) baseline -- displayed for contrast.
    cap drop sd_d_baseline
    egen sd_d_baseline = sd(d_baseline) if first_g
    qui sum sd_d_baseline
    scalar sd_baseline_value = r(mean)
    scalar common_baseline   = cond(missing(sd_baseline_value), 1, sd_baseline_value == 0)

    * ---- Heterogeneous dose at the switch date ---------------------------- *
    * HAD requires Var(D_{T0+1} | D_{T0+1} > 0) > 0, i.e. the size of the first
    * treatment change varies across switchers. Used directly, rather than via
    * a "not binary at the switch date" proxy.
    cap drop sd_first_change
    egen sd_first_change = sd(first_change) if first_g & Fg < Tplus1
    qui sum sd_first_change
    scalar sd_change_value = r(mean)
    scalar heterog_dose    = cond(missing(sd_change_value), 0, sd_change_value > 0)

    * ---- SFSD: a same-baseline pair with different first-switch dates ------ *
    *
    * The SFSD condition is that there exist g != g' with
    *   (i)  D_{g,1} == D_{g',1}   -- same period-1 treatment, and
    *   (ii) F_g     != F_{g'}     -- different first-switch dates.
    *
    * This is a PAIR-EXISTENCE test, not a variance test. It is NOT
    * sd(d_baseline) > 0, and it is NOT the global sd(Fg) > 0 computed above:
    * it is timing variation WITHIN a baseline cell. A panel whose baseline
    * cells are all singletons fails SFSD however much overall timing
    * variation it has, because no two groups share a baseline to be compared.
    *
    * Never-switchers participate. Fg == Tplus1 is the summary's own
    * convention for "never switches", so a switcher matched to a
    * same-baseline never-switcher genuinely satisfies (i) and (ii) -- and
    * that is precisely the comparison did_multiplegt_dyn exploits. Taking
    * sd(Fg) over the whole cell includes them automatically.
    *
    * sd() is missing in a singleton cell; that is the correct reading (one
    * group can supply no pair), and max() below ignores it.
    cap drop sd_Fg_within
    bys d_baseline: egen sd_Fg_within = sd(Fg) if first_g
    qui sum sd_Fg_within
    scalar max_sd_Fg_within = r(max)
    scalar sfsd_pair        = cond(missing(max_sd_Fg_within), 0, max_sd_Fg_within > 0)

    * How the groups partition, and how many of those cells actually carry
    * identifying variation -- diagnostics for HOW MUCH SFSD variation exists,
    * not merely whether any does.
    qui distinct d_baseline if first_g
    scalar n_baseline_cells = r(ndistinct)

    qui distinct d_baseline if first_g & sd_Fg_within > 0 & !missing(sd_Fg_within)
    scalar n_sfsd_cells = r(ndistinct)

    * ---------------------------------------------------------------------- *
    * 6. Diagnostics -- the full state driving the classification
    * ---------------------------------------------------------------------- *

    di in red _n "{hline 70}"
    di in red    "  DIAGNOSTICS"
    di in red    "{hline 70}"
    di in red    "  n_groups             = " n_groups
    di in red    "  n_switchers          = " n_switchers
    di in red    "  n_never_treated      = " n_never_treated
    di in red    "  never_treated_groups = " never_treated_groups
    di in red    "  any_switchers        = " any_switchers
    di in red    "  same_Fg              = " same_Fg      "   (sd(Fg|switchers) = " sd_Fg_value ")"
    di in red    "  switch periods (t)   = " %2.0f first_switch_t " .. " %2.0f last_switch_t
    di in red    "  switch dates (t_cal) = " %4.0f first_switch_cal " .. " %4.0f last_switch_cal
    di in red    "  is_binary            = " is_binary    "   (d in {" d_min ", " d_max "})"
    di in red    "  is_binary01          = " is_binary01
    di in red    "  is_absorbing         = " is_absorbing
    di in red    "  zero_baseline        = " zero_baseline "   (groups with d_baseline!=0: " n_nonzero_baseline ")"
    di in red    "  common_baseline      = " common_baseline
    di in red    "  heterog_dose         = " heterog_dose "   (sd(first_change) = " sd_change_value ")"
    di in red    "  sfsd_pair            = " sfsd_pair    "   (max sd(Fg) within a baseline cell = " max_sd_Fg_within ")"
    di in red    "  n_baseline_cells     = " n_baseline_cells
    di in red    "  n_sfsd_cells         = " n_sfsd_cells "   (cells carrying timing variation)"
    di in red    "{hline 70}"

    * ---------------------------------------------------------------------- *
    * 7. Classification
    *
    *    Designs nest: CLA subset SAD subset HAD-SQS subset SFSD. Checked most
    *    restrictive first, so the reported design is the most restrictive one
    *    that holds, and SFSD only catches what the others did not.
    *    Conditionals below read ONLY named scalars.
    * ---------------------------------------------------------------------- *

    local design    "OTHER"
    local estimator ""

    if (any_switchers & is_binary01 & is_absorbing & same_Fg & never_treated_groups & zero_baseline) {
        local design    "CLA"
        local estimator "static / event-study TWFE"
    }
    else if (any_switchers & is_binary01 & is_absorbing & !same_Fg) {
        local design    "SAD"
        local estimator "csdid, did_multiplegt_dyn, or did2s"
    }
    else if (any_switchers & same_Fg & zero_baseline & heterog_dose) {
        local design    "HAD"
        local estimator "did_had"
    }
    else if (any_switchers & sfsd_pair) {
        local design    "SFSD"
        local estimator "did_multiplegt_dyn"
    }

    * ---------------------------------------------------------------------- *
    * 8. Report
    * ---------------------------------------------------------------------- *

    di in red _n "{hline 70}"

    if ("`design'" == "CLA") {
        di as result "  DESIGN: Classical DID Design (CLA)"
        di in red    "{hline 70}"
        di in red    "  Binary and absorbing treatment, no variation in treatment"
        di in red    "  timing: all " n_switchers " treated group(s) experience treatment at"
        di in red    "  t=" %4.0f common_switch_cal " (period " %2.0f common_switch_t "), and " n_never_treated " group(s) never switch."
        di in red    "  Estimator: `estimator'"
        di in red    "  See Chapter 3 of the DID textbook (de Chaisemartin and"
        di in red    "  D'Haultfoeuille)."
    }
    else if ("`design'" == "SAD") {
        di as result "  DESIGN: Staggered Adoption Design (SAD)"
        di in red    "{hline 70}"
        di in red    "  Binary and absorbing treatment, with variation in treatment"
        di in red    "  timing across the " n_switchers " switching group(s): first switches"
        di in red    "  occur between t=" %4.0f first_switch_cal " and t=" %4.0f last_switch_cal "."
        di in red    "  Estimator: `estimator'"
        di in red    "  See Chapter 6 of the DID textbook."
    }
    else if ("`design'" == "HAD") {
        di as result "  DESIGN: Heterogeneous Adoption Design (HAD)"
        di in red    "{hline 70}"
        di in red    "  All groups untreated at baseline (t=" %4.0f cal_min "); all " n_switchers " treated"
        di in red    "  group(s) experience treatment at t=" %4.0f common_switch_cal ", but the size"
        di in red    "  of that change varies across groups."
        di in red    "  Estimator: `estimator'"
        di in red    "  See Chapter 7 of the DID textbook."
    }
    else if ("`design'" == "SFSD") {
        di as result "  DESIGN: Staggered First-Switch Design (SFSD)"
        di in red    "{hline 70}"
        di in red    "  The panel is not CLA, SAD or HAD, but it does satisfy the"
        di in red    "  staggered first-switch condition: some groups share the same"
        di in red    "  baseline treatment while first switching at different dates."
        di in red    "  First switches occur between t=" %4.0f first_switch_cal " and t=" %4.0f last_switch_cal "."
        di in red    ""
        di in red    "  SFSD is the broadest design tested here. Unlike CLA/SAD it"
        di in red    "  permits NON-ABSORBING treatment (a group may switch more than"
        di in red    "  once, including back to its baseline), and unlike HAD it permits"
        di in red    "  HETEROGENEOUS baseline doses."
        di in red    ""
        di in red    "  Identifying variation: " n_sfsd_cells " of " n_baseline_cells " baseline cell(s) contain"
        di in red    "  groups that first switch at different dates."
        di in red    "  Estimator: `estimator'"
        di in red    "  See Chapter 8 of the DID textbook."
    }
    else {
        di as result "  DESIGN: OTHER"
        di in red    "{hline 70}"
        di in red    "  Your design isn't CLA, SAD, HAD, or SFSD."
        di in red    ""
        di in red    "  Why each was ruled out:"

        * ---- CLA ----
        di in red    "   CLA requires: switchers, binary {0,1}, absorbing, no timing"
        di in red    "                 variation, never-treated groups, zero baseline."
        if (!any_switchers)         di in red "     - failed: no switchers"
        if (!is_binary01)           di in red "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di in red "     - failed: treatment not absorbing"
        if (!same_Fg)               di in red "     - failed: treatment timing varies"
        if (!never_treated_groups)  di in red "     - failed: no never-treated groups"
        if (!zero_baseline)         di in red "     - failed: baseline treatment not 0 for all groups"

        * ---- SAD ----
        di in red    "   SAD requires: switchers, binary {0,1}, absorbing, timing variation."
        if (!any_switchers)         di in red "     - failed: no switchers"
        if (!is_binary01)           di in red "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di in red "     - failed: treatment not absorbing"
        if (same_Fg)                di in red "     - failed: no variation in treatment timing"

        * ---- HAD ----
        di in red    "   HAD requires: switchers, common switch date, zero baseline,"
        di in red    "                 heterogeneous dose at the switch."
        if (!any_switchers)         di in red "     - failed: no switchers"
        if (!same_Fg)               di in red "     - failed: switch dates differ across groups"
        if (!zero_baseline)         di in red "     - failed: baseline treatment not 0 for all groups"
        if (!heterog_dose)          di in red "     - failed: size of first change does not vary"

        * ---- SFSD ----
        di in red    "   SFSD requires: switchers, and two groups sharing a baseline"
        di in red    "                  treatment value that first switch at different dates."
        if (!any_switchers)         di in red "     - failed: no switchers"
        if (!sfsd_pair)             di in red "     - failed: no two groups share a baseline treatment value while first switching at different dates"

        di in red    ""
        di in red    "  SSD is not tested by this version."
    }

    di in red "{hline 70}"

    * ---------------------------------------------------------------------- *
    * 9. Return
    * ---------------------------------------------------------------------- *

    * restore BEFORE the returns is deliberate and safe: every value below
    * lives in a scalar or a local, neither of which is part of the dataset, so
    * both survive restore. (If any of these were ever changed to a VARIABLE,
    * it would be wiped here and the return would silently break.)
    restore
    set varabbrev `varabbrev_was'

    return local  design            "`design'"
    return local  estimator         "`estimator'"

    return scalar n_groups          = n_groups
    return scalar n_switchers       = n_switchers
    return scalar n_never_treated   = n_never_treated

    return scalar any_switchers     = any_switchers
    return scalar same_Fg           = same_Fg
    return scalar is_binary         = is_binary
    return scalar is_binary01       = is_binary01
    return scalar is_absorbing      = is_absorbing
    return scalar zero_baseline     = zero_baseline
    return scalar common_baseline   = common_baseline
    return scalar heterog_dose      = heterog_dose

    return scalar sfsd_pair         = sfsd_pair
    return scalar n_baseline_cells  = n_baseline_cells
    return scalar n_sfsd_cells      = n_sfsd_cells

    return scalar common_switch_t   = common_switch_t
    return scalar common_switch_cal = common_switch_cal
    return scalar first_switch_cal  = first_switch_cal
    return scalar last_switch_cal   = last_switch_cal

end
