*! whichDIDshouldIuse 0.2  24sep2026
*! Classify a (Y, G, T, D) panel as CLA, SAD, HAD, or SFSD, with a less strict
*! default for missing treatment and a strict option.

/*==============================================================================
  whichDIDshouldIuse.ado

  Classify a (Y, G, T, D) panel as CLA, SAD, HAD, or SFSD, with two modes for
  handling missing treatment: a less strict default, and a strict option that
  reproduces the original drop-on-any-missing rules exactly.

  SYNTAX
    whichDIDshouldIuse Y G T D [, detail strict]
      Y  outcome
      G  group identifier
      T  the user's CALENDAR time variable (year, quarter, ...)
      D  treatment

    detail  also print the input echo, the panel summary and the full
            DIAGNOSTICS block.
    strict  handle missing treatment by dropping groups (see MISSING
            TREATMENT below).

  MISSING TREATMENT
    strict:
      - baseline is d at t == 1; a group with d missing there is dropped;
      - a group with d missing anywhere in [1, Fg-1] is dropped. For a
        never-switcher (Fg = Tplus1) that window is the whole panel.

    default (less strict, after did_multiplegt_dyn): keep a group whenever
    its first switch date can still be pinned down, and REPORT -- never
    silently fill -- anything that could change the answer. Per group:
      E_g     first period with y or d observed (entry; rows created by
              fillin have both missing)
      FD_g    first period with d observed      LD_g  last such period
      LDBF_g  last period before Fg with d observed
    and then:
      - d never observed                   -> dropped
      - late entry (E_g = FD_g > 1)        -> baseline = d at FD_g
      - missing at start (E_g < FD_g)      -> baseline = d at FD_g, reported
      - gap inside (FD_g, LDBF_g)          -> read as baseline, reported
      - gap right before the switch        -> the switch date is unknown, so
        (LDBF_g < Fg-1)                       the group is DEMOTED to a control
                                              known at baseline through LDBF_g
      - never-switcher exits (LD_g < Tmax) -> control through LD_g
      - gap after the switch               -> left missing (both modes),
                                              reported: the absorbing check
                                              then rests on observed d only

    Controls with an end date: end_g is the last period a control is known
    to be at baseline, and Fg_trunc = min(Fg, end_g + 1) (= Fg for switchers
    and for fully observed never-switchers). A control counts toward
    n_never_treated only if it is still usable at the earliest switch
    (Fg_trunc > first_switch_t), and sfsd_pair is tested against Fg_trunc.
    In strict mode every control is fully observed, so Fg_trunc = Fg and both
    modes reduce to the same rules.

  DISPLAY
    detail gates the DIAGNOSTICS block, the input echo and the panel summary.
    The dropped-group lines and, in default mode, the missing-treatment block
    are NOT gated: they report changes to the caller's sample, which are
    warnings rather than diagnostics.

    Normal output is "as text"; computed values are "as result". "as error"
    is reserved for genuine errors, of which this program has none. Within a
    single di, a style directive applies to everything after it -- including
    across a /// continuation -- so a literal following a value must re-state
    "as text".

  DEPENDENCY
    distinct (SSC):  ssc install distinct

  Coding practice: every classification conditional tests a NAMED SCALAR
  defined where the underlying statistic is computed; each r() value is
  consumed on the line after the command that set it.

  TIME VARIABLES (package convention):
    t_cal  the user's original calendar date, used ONLY for display.
    t      t_cal normalized to consecutive integers 1..Tmax. ALL logic runs
           on this, so Fg-1 is always a real period.
==============================================================================*/

program define whichDIDshouldIuse, rclass
    version 14
    syntax varlist(min=4 max=4 numeric) [, DETail STRict]

    * Turn OFF variable-name abbreviation for the whole program: otherwise
    * "drop t" deletes t_cal when t_cal is the only t* variable.
    local varabbrev_was `c(varabbrev)'
    set varabbrev off

    tokenize `varlist'
    local Yvar "`1'"
    local Gvar "`2'"
    local Tvar "`3'"
    local Dvar "`4'"

    * Gating idiom: quote BOTH sides, or the absent option expands to
    * if ( != "") -- a syntax error on the default path.
    if ("`detail'" != "") {
        di as text _n "{hline 70}"
        di as text    "  whichDIDshouldIuse:  Y=" as result "`Yvar'" ///
                      as text "  G=" as result "`Gvar'" ///
                      as text "  T=" as result "`Tvar'" ///
                      as text "  D=" as result "`Dvar'"
        if ("`strict'" != "") di as text "  missing treatment: strict"
        else                  di as text "  missing treatment: default (less strict)"
        di as text    "{hline 70}"
    }

    preserve

    * LOAD-BEARING: bare scalar names resolve to a VARIABLE first, so no
    * caller variable may survive to shadow one.
    qui keep `Yvar' `Gvar' `Tvar' `Dvar'

    qui rename `Yvar' y
    qui rename `Gvar' g
    qui rename `Tvar' t_cal
    qui rename `Dvar' d

    qui drop if missing(g) | missing(t_cal)

    * ---------------------------------------------------------------------- *
    * 1. Time variables: normalize, and build the calendar crosswalk
    * ---------------------------------------------------------------------- *

    cap drop _fillin
    qui fillin g t_cal

    * Do NOT write "cap drop t" here (see varabbrev note above).
    qui egen t = group(t_cal)               // consecutive integers 1..Tmax

    qui sum t
    scalar Tmax   = r(max)
    scalar Tplus1 = Tmax + 1            // never-switcher sentinel (normalized)

    matrix cal_of_t = J(1, Tmax, .)
    forvalues k = 1/`=Tmax' {
        qui sum t_cal if t == `k'
        matrix cal_of_t[1, `k'] = r(min)
    }

    scalar cal_min = cal_of_t[1, 1]
    scalar cal_max = cal_of_t[1, Tmax]

    order g t t_cal d y
    sort g t

    if ("`detail'" != "") {
        di as text _n "Panel: " as result %4.0f Tmax ///
           as text " periods, calendar " as result %4.0f cal_min ///
           as text " .. " as result %4.0f cal_max
        di as text    "       (t normalized to 1.." as result %4.0f Tmax ///
           as text "; never-switcher sentinel = " as result %4.0f Tplus1 as text ")"
    }

    * ---------------------------------------------------------------------- *
    * 2. Baseline treatment
    * ---------------------------------------------------------------------- *

    qui distinct g
    scalar n_groups_raw = r(ndistinct)

    * Counters that only one mode fills in. Missing (.) means "not assessed
    * in this mode", not zero.
    scalar n_dropped_baseline = .
    scalar n_dropped_pretreat = .
    scalar n_dropped_alld     = .
    scalar n_late_entry       = .
    scalar n_missing_at_start = .
    scalar n_filled_pre_gap   = .
    scalar n_demoted          = .
    scalar n_exit_controls    = .

    if ("`strict'" != "") {
        * Baseline = d at t == 1 literally. egen min() only spreads that
        * single value to every row of the group.
        cap drop d_baseline_temp d_baseline
        qui gen    d_baseline_temp = d if t == 1
        qui bys g: egen d_baseline = min(d_baseline_temp)

        * No treatment observed in period 1 -> no verifiable baseline.
        qui drop if missing(d_baseline)

        qui distinct g
        scalar n_groups_baseline  = r(ndistinct)
        scalar n_dropped_baseline = n_groups_raw - n_groups_baseline

        * NOT gated by detail: groups discarded from the caller's sample.
        di as text "Groups dropped for missing baseline (d at t=1, cal " ///
           as result %4.0f cal_min as text "): " as result n_dropped_baseline ///
           as text "  (" as result n_groups_raw as text " -> " ///
           as result n_groups_baseline as text ")"
    }
    else {
        * Entry date E_g: first period with y OR d observed. Rows created by
        * fillin carry neither, so they never count as the group existing.
        cap drop t_exist_temp E_g t_dobs_temp FD_g LD_g
        qui gen    t_exist_temp = t if !missing(y) | !missing(d)
        qui bys g: egen E_g = min(t_exist_temp)

        * First and last period with d observed.
        qui gen    t_dobs_temp = t if !missing(d)
        qui bys g: egen FD_g = min(t_dobs_temp)
        qui bys g: egen LD_g = max(t_dobs_temp)

        * d never observed -> nothing to classify.
        qui drop if missing(FD_g)

        qui distinct g
        scalar n_groups_baseline = r(ndistinct)
        scalar n_dropped_alld    = n_groups_raw - n_groups_baseline

        * Baseline = d at the first period it is observed.
        cap drop d_baseline_temp d_baseline
        qui gen    d_baseline_temp = d if t == FD_g
        qui bys g: egen d_baseline = min(d_baseline_temp)

        * NOT gated by detail: groups discarded from the caller's sample.
        di as text "Groups dropped for treatment never observed: " ///
           as result n_dropped_alld ///
           as text "  (" as result n_groups_raw as text " -> " ///
           as result n_groups_baseline as text ")"
    }

    * ---------------------------------------------------------------------- *
    * 3. Date of first switch (Fg)
    *
    *    Missing d is never a departure, so Fg is the first OBSERVED departure
    *    from baseline -- valid for either baseline definition.
    * ---------------------------------------------------------------------- *

    cap drop t_d_diff_d_baseline Fg
    qui gen    t_d_diff_d_baseline = t*(d!=. & d!=d_baseline) + Tplus1*(d==. | d==d_baseline)
    qui bys g: egen Fg = min(t_d_diff_d_baseline)

    cap drop first_g
    qui bys g: gen byte first_g = (_n == 1)

    * ---------------------------------------------------------------------- *
    * 4. Missing treatment before the switch
    * ---------------------------------------------------------------------- *

    * end_g: last period a CONTROL is known to be at baseline. Missing for
    * switchers and for controls observed to the end of the panel.
    cap drop end_g
    qui gen end_g = .

    if ("`strict'" != "") {
        * Pre-treatment integrity filter: any missing (or, which cannot happen
        * given how Fg is built, off-baseline) d in [1, Fg-1] drops the group.
        cap drop d_pretreatment_flag_temp d_pretreatment_flag
        qui gen    d_pretreatment_flag_temp = (d==. | d!=d_baseline) if inrange(t, 1, Fg-1)
        qui bys g: egen d_pretreatment_flag = max(d_pretreatment_flag_temp)
        qui drop if d_pretreatment_flag == 1

        qui distinct g
        scalar n_groups           = r(ndistinct)
        scalar n_dropped_pretreat = n_groups_baseline - n_groups

        * NOT gated by detail, for the same reason as the baseline warning.
        di as text "Groups dropped for pre-treatment violations: " ///
           as result n_dropped_pretreat ///
           as text "  (" as result n_groups_baseline as text " -> " ///
           as result n_groups as text ")"
    }
    else {
        * LDBF_g: last period before Fg with d observed. For a never-switcher
        * (Fg = Tplus1) this is LD_g.
        cap drop t_ldbf_temp LDBF_g
        qui gen    t_ldbf_temp = t if !missing(d) & t < Fg
        qui bys g: egen LDBF_g = max(t_ldbf_temp)

        * Gaps strictly between the first observed d and LDBF_g: the observed
        * values on both sides are baseline, so the gap reads as baseline.
        * Counted, not filled -- every flag below already ignores missing d.
        * Measured BEFORE demotion, while LDBF_g still bounds the window.
        cap drop pre_gap_temp pre_gap
        qui gen    pre_gap_temp = missing(d) & t > FD_g & t < LDBF_g
        qui bys g: egen pre_gap = max(pre_gap_temp)

        * Gap right before the switch: the switch happened somewhere in
        * (LDBF_g, Fg], so Fg is unknown. The group is demoted to a control
        * known at baseline through LDBF_g, and its later d is discarded so it
        * does not feed the binary/absorbing checks.
        cap drop demoted
        qui gen byte demoted = (Fg < Tplus1 & LDBF_g < Fg - 1)

        * Original never-switchers end where d stops being observed.
        qui replace end_g = LD_g   if Fg == Tplus1 & LD_g < Tmax
        qui replace end_g = LDBF_g if demoted
        qui replace d     = .      if demoted & t > LDBF_g
        qui replace Fg    = Tplus1 if demoted

        qui count if first_g & FD_g > 1 & E_g == FD_g
        scalar n_late_entry = r(N)
        qui count if first_g & E_g < FD_g
        scalar n_missing_at_start = r(N)
        qui count if first_g & pre_gap == 1
        scalar n_filled_pre_gap = r(N)
        qui count if first_g & demoted
        scalar n_demoted = r(N)
        qui count if first_g & Fg == Tplus1 & !demoted & !missing(end_g)
        scalar n_exit_controls = r(N)

        qui distinct g
        scalar n_groups = r(ndistinct)
    }

    * Treatment at the switch and size of the first change -- after any
    * demotion, so a demoted group carries neither.
    cap drop d_Fg_temp d_Fg
    qui gen    d_Fg_temp = d if t == Fg
    qui bys g: egen d_Fg = min(d_Fg_temp)

    cap drop first_change
    qui gen first_change = d_Fg - d_baseline

    * First period a control is no longer usable. = Fg for switchers and
    * fully observed controls, so in strict mode Fg_trunc == Fg everywhere.
    cap drop Fg_trunc
    qui gen Fg_trunc = cond(Fg == Tplus1 & !missing(end_g), min(Fg, end_g + 1), Fg)

    * Switchers with d missing after the switch. Both modes leave these
    * missing; the absorbing check then rests on observed d only.
    cap drop post_gap_temp post_gap
    qui gen    post_gap_temp = missing(d) & Fg < Tplus1 & t > Fg
    qui bys g: egen post_gap = max(post_gap_temp)
    qui count if first_g & post_gap == 1
    scalar n_post_gap_switchers = r(N)

    * NOT gated by detail: in default mode these groups are in the sample
    * only because of the less strict rules.
    if ("`strict'" == "") {
        di as text "Missing treatment (default rules; use , strict to drop instead):"
        di as text "  late entrants, baseline taken at entry:        " as result n_late_entry
        di as text "  d missing at start, baseline taken later:      " as result n_missing_at_start
        di as text "  pre-switch gaps read as baseline:              " as result n_filled_pre_gap
        di as text "  gap right before switch, demoted to control:   " as result n_demoted
        di as text "  controls leaving the panel early:              " as result n_exit_controls
        di as text "  switchers with d missing after the switch:     " as result n_post_gap_switchers
    }

    * ---------------------------------------------------------------------- *
    * 5. Scalar flags
    *
    *    One row per group (first_g) for anything group-level. Every r() is
    *    consumed immediately. Switcher statistics come first: whether a
    *    truncated control is usable depends on the earliest switch date.
    * ---------------------------------------------------------------------- *

    cap drop first_g
    qui bys g: gen byte first_g = (_n == 1)

    * ---- Switchers ------------------------------------------------------- *
    qui count if first_g & Fg < Tplus1
    scalar n_switchers   = r(N)
    scalar any_switchers = (n_switchers > 0)

    * ---- Variation in treatment timing, AMONG SWITCHERS ------------------ *
    * sd() is missing with a single switcher -> same_Fg = 1 (deliberate).
    cap drop sd_Fg_sw
    qui egen sd_Fg_sw = sd(Fg) if first_g & Fg < Tplus1
    qui sum sd_Fg_sw
    scalar sd_Fg_value = r(mean)
    scalar same_Fg     = cond(missing(sd_Fg_value), 1, sd_Fg_value == 0)

    qui sum Fg if first_g & Fg < Tplus1
    scalar first_switch_t  = cond(r(N) > 0, r(min), .)
    scalar last_switch_t   = cond(r(N) > 0, r(max), .)
    scalar common_switch_t = first_switch_t     // meaningful only if same_Fg == 1

    scalar first_switch_cal  = cond(missing(first_switch_t), ., cal_of_t[1, first_switch_t])
    scalar last_switch_cal   = cond(missing(last_switch_t),  ., cal_of_t[1, last_switch_t])
    scalar common_switch_cal = first_switch_cal

    * ---- Never-treated groups ------------------------------------------- *
    * A control counts only if it is still known at baseline at the earliest
    * switch (Fg_trunc > first_switch_t). With no switchers every control
    * counts. In strict mode Fg_trunc = Tplus1 for all controls, so this is
    * the plain count.
    qui count if first_g & Fg == Tplus1 & (missing(first_switch_t) | Fg_trunc > first_switch_t)
    scalar n_never_treated      = r(N)
    scalar never_treated_groups = (n_never_treated > 0)

    qui count if first_g & Fg == Tplus1 & Fg_trunc < Tplus1
    scalar n_truncated_controls = r(N)

    * ---- Is the treatment binary? ---------------------------------------- *
    qui sum d
    scalar d_min = r(min)
    scalar d_max = r(max)

    cap drop binary_check
    qui gen binary_check = (d == d_min | d == d_max) if !missing(d)
    qui sum binary_check
    scalar is_binary = (r(mean) == 1)

    * Strict {0,1}, kept separate from is_binary so a {4,9} coding is visible.
    scalar is_binary01 = (is_binary == 1 & d_min == 0 & d_max == 1)

    * ---- Is the treatment absorbing? ------------------------------------- *
    cap drop absorbing_check
    qui gen absorbing_check = (d == d_Fg) if Fg < Tplus1 & t >= Fg & !missing(d) & !missing(d_Fg)
    qui sum absorbing_check
    scalar n_absorbing_obs = r(N)
    * No post-switch observations -> NOT absorbing (deliberate).
    scalar is_absorbing = cond(n_absorbing_obs == 0, 0, r(min) == 1)

    * ---- Baseline dose ---------------------------------------------------- *
    qui count if first_g & d_baseline != 0
    scalar n_nonzero_baseline = r(N)
    scalar zero_baseline      = (n_nonzero_baseline == 0)

    cap drop sd_d_baseline
    qui egen sd_d_baseline = sd(d_baseline) if first_g
    qui sum sd_d_baseline
    scalar sd_baseline_value = r(mean)
    scalar common_baseline   = cond(missing(sd_baseline_value), 1, sd_baseline_value == 0)

    * ---- Heterogeneous dose at the switch date ---------------------------- *
    cap drop sd_first_change
    qui egen sd_first_change = sd(first_change) if first_g & Fg < Tplus1
    qui sum sd_first_change
    scalar sd_change_value = r(mean)
    scalar heterog_dose    = cond(missing(sd_change_value), 0, sd_change_value > 0)

    * ---- SFSD: a same-baseline pair with different first-switch dates ------ *
    *
    * There must exist g != g' with D_{g,1} == D_{g',1} and F_g != F_{g'}:
    * a PAIR-EXISTENCE test within a baseline cell. With controls that have
    * an end date the pair must also be usable -- the later group must still
    * be at baseline when the earlier one switches. So, per d_baseline cell:
    *
    *     min(Fg over switchers)  <  max(Fg_trunc over all groups)
    *
    * The max cannot be the earliest switcher itself (its Fg_trunc = Fg), so
    * this is a pair. When Fg_trunc == Fg (strict mode) it holds exactly when
    * sd(Fg) > 0 within the cell -- the test whichDIDshouldIuse uses. A cell
    * with no switchers carries no pair (sfsd_cell missing).
    cap drop Fg_sw_temp min_Fg_sw_cell Fg_trunc_temp max_Fg_trunc_cell sfsd_cell
    qui gen    Fg_sw_temp = Fg if first_g & Fg < Tplus1
    qui bys d_baseline: egen min_Fg_sw_cell = min(Fg_sw_temp)
    qui gen    Fg_trunc_temp = Fg_trunc if first_g
    qui bys d_baseline: egen max_Fg_trunc_cell = max(Fg_trunc_temp)
    qui gen byte sfsd_cell = (min_Fg_sw_cell < max_Fg_trunc_cell) if first_g & !missing(min_Fg_sw_cell)

    qui count if first_g & sfsd_cell == 1
    scalar n_sfsd_groups = r(N)
    scalar sfsd_pair     = (n_sfsd_groups > 0)

    qui distinct d_baseline if first_g
    scalar n_baseline_cells = r(ndistinct)

    scalar n_sfsd_cells = 0
    if (n_sfsd_groups > 0) {
        qui distinct d_baseline if first_g & sfsd_cell == 1
        scalar n_sfsd_cells = r(ndistinct)
    }

    * ---------------------------------------------------------------------- *
    * 6. Diagnostics
    * ---------------------------------------------------------------------- *

    if ("`detail'" != "") {
        di as text _n "{hline 70}"
        di as text    "  DIAGNOSTICS"
        di as text    "{hline 70}"
        di as text    "  n_groups             = " as result n_groups
        di as text    "  n_switchers          = " as result n_switchers
        di as text    "  n_never_treated      = " as result n_never_treated ///
           as text    "   (usable at the earliest switch)"
        di as text    "  n_truncated_controls = " as result n_truncated_controls
        di as text    "  never_treated_groups = " as result never_treated_groups
        di as text    "  any_switchers        = " as result any_switchers
        di as text    "  same_Fg              = " as result same_Fg ///
           as text    "   (sd(Fg|switchers) = " as result sd_Fg_value as text ")"
        di as text    "  switch periods (t)   = " as result %2.0f first_switch_t ///
           as text    " .. " as result %2.0f last_switch_t
        di as text    "  switch dates (t_cal) = " as result %4.0f first_switch_cal ///
           as text    " .. " as result %4.0f last_switch_cal
        di as text    "  is_binary            = " as result is_binary ///
           as text    "   (d in {" as result d_min as text ", " as result d_max as text "})"
        di as text    "  is_binary01          = " as result is_binary01
        di as text    "  is_absorbing         = " as result is_absorbing
        di as text    "  zero_baseline        = " as result zero_baseline ///
           as text    "   (groups with d_baseline!=0: " as result n_nonzero_baseline as text ")"
        di as text    "  common_baseline      = " as result common_baseline
        di as text    "  heterog_dose         = " as result heterog_dose ///
           as text    "   (sd(first_change) = " as result sd_change_value as text ")"
        di as text    "  sfsd_pair            = " as result sfsd_pair ///
           as text    "   (groups in cells with a usable pair: " as result n_sfsd_groups as text ")"
        di as text    "  n_baseline_cells     = " as result n_baseline_cells
        di as text    "  n_sfsd_cells         = " as result n_sfsd_cells ///
           as text    "   (cells carrying timing variation)"
        di as text    "  n_post_gap_switchers = " as result n_post_gap_switchers
        di as text    "{hline 70}"
    }

    * ---------------------------------------------------------------------- *
    * 7. Classification
    *
    *    Designs nest: CLA subset SAD subset HAD-SQS subset SFSD. Checked most
    *    restrictive first. Conditionals read ONLY named scalars.
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

    di as text _n "{hline 70}"

    if ("`design'" == "CLA") {
        di as result "  DESIGN: Classical DID Design (CLA)"
        di as text    "{hline 70}"
        di as text    "  Binary and absorbing treatment, no variation in treatment"
        di as text    "  timing: all " n_switchers " treated group(s) experience treatment at"
        di as text    "  t=" %4.0f common_switch_cal " (period " %2.0f common_switch_t "), and " n_never_treated " group(s) never switch."
        di as text    "  Estimator: `estimator'"
        di as text    "  See Chapter 3 of the DID textbook (de Chaisemartin and"
        di as text    "  D'Haultfoeuille)."
    }
    else if ("`design'" == "SAD") {
        di as result "  DESIGN: Staggered Adoption Design (SAD)"
        di as text    "{hline 70}"
        di as text    "  Binary and absorbing treatment, with variation in treatment"
        di as text    "  timing across the " n_switchers " switching group(s): first switches"
        di as text    "  occur between t=" %4.0f first_switch_cal " and t=" %4.0f last_switch_cal "."
        di as text    "  Estimator: `estimator'"
        di as text    "  See Chapter 6 of the DID textbook."
    }
    else if ("`design'" == "HAD") {
        di as result "  DESIGN: Heterogeneous Adoption Design (HAD)"
        di as text    "{hline 70}"
        di as text    "  All groups untreated at baseline (t=" %4.0f cal_min "); all " n_switchers " treated"
        di as text    "  group(s) experience treatment at t=" %4.0f common_switch_cal ", but the size"
        di as text    "  of that change varies across groups."
        di as text    "  Estimator: `estimator'"
        di as text    "  See Chapter 7 of the DID textbook."
    }
    else if ("`design'" == "SFSD") {
        di as result "  DESIGN: Staggered First-Switch Design (SFSD)"
        di as text    "{hline 70}"
        di as text    "  The panel is not CLA, SAD or HAD, but it does satisfy the"
        di as text    "  staggered first-switch condition: some groups share the same"
        di as text    "  baseline treatment while first switching at different dates."
        di as text    "  First switches occur between t=" %4.0f first_switch_cal " and t=" %4.0f last_switch_cal "."
        di as text    ""
        di as text    "  SFSD is the broadest design tested here. Unlike CLA/SAD it"
        di as text    "  permits NON-ABSORBING treatment (a group may switch more than"
        di as text    "  once, including back to its baseline), and unlike HAD it permits"
        di as text    "  HETEROGENEOUS baseline doses."
        di as text    ""
        di as text    "  Identifying variation: " n_sfsd_cells " of " n_baseline_cells " baseline cell(s) contain"
        di as text    "  groups that first switch at different dates."
        di as text    "  Estimator: `estimator'"
        di as text    "  See Chapter 8 of the DID textbook."
    }
    else {
        di as result "  DESIGN: OTHER"
        di as text    "{hline 70}"
        di as text    "  Your design isn't CLA, SAD, HAD, or SFSD."
        di as text    ""
        di as text    "  Why each was ruled out:"

        * ---- CLA ----
        di as text    "   CLA requires: switchers, binary {0,1}, absorbing, no timing"
        di as text    "                 variation, never-treated groups, zero baseline."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!is_binary01)           di as text "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di as text "     - failed: treatment not absorbing"
        if (!same_Fg)               di as text "     - failed: treatment timing varies"
        if (!never_treated_groups)  di as text "     - failed: no never-treated groups usable at the switch date"
        if (!zero_baseline)         di as text "     - failed: baseline treatment not 0 for all groups"

        * ---- SAD ----
        di as text    "   SAD requires: switchers, binary {0,1}, absorbing, timing variation."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!is_binary01)           di as text "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di as text "     - failed: treatment not absorbing"
        if (same_Fg)                di as text "     - failed: no variation in treatment timing"

        * ---- HAD ----
        di as text    "   HAD requires: switchers, common switch date, zero baseline,"
        di as text    "                 heterogeneous dose at the switch."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!same_Fg)               di as text "     - failed: switch dates differ across groups"
        if (!zero_baseline)         di as text "     - failed: baseline treatment not 0 for all groups"
        if (!heterog_dose)          di as text "     - failed: size of first change does not vary"

        * ---- SFSD ----
        di as text    "   SFSD requires: switchers, and two groups sharing a baseline"
        di as text    "                  treatment value that first switch at different dates."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!sfsd_pair)             di as text "     - failed: no two groups share a baseline treatment value while first switching at different dates"
    }

    * The absorbing verdict ignores unobserved d, so a reversal hidden in a
    * post-switch gap would go unseen. Applies in both modes.
    if (n_post_gap_switchers > 0 & inlist("`design'", "CLA", "SAD")) {
        di as text ""
        di as text "  Note: " as result n_post_gap_switchers ///
           as text " switcher(s) have d missing after their switch; the"
        di as text "  absorbing check rests on observed treatment only."
    }

    di as text "{hline 70}"

    * ---------------------------------------------------------------------- *
    * 9. Return
    * ---------------------------------------------------------------------- *

    * restore BEFORE the returns is safe only because every value below is a
    * scalar or a local, neither of which is part of the dataset.
    restore
    set varabbrev `varabbrev_was'

    return local  design               "`design'"
    return local  estimator            "`estimator'"
    return scalar strict               = ("`strict'" != "")

    return scalar n_groups             = n_groups
    return scalar n_switchers          = n_switchers
    return scalar n_never_treated      = n_never_treated
    return scalar n_truncated_controls = n_truncated_controls

    return scalar any_switchers        = any_switchers
    return scalar same_Fg              = same_Fg
    return scalar is_binary            = is_binary
    return scalar is_binary01          = is_binary01
    return scalar is_absorbing         = is_absorbing
    return scalar zero_baseline        = zero_baseline
    return scalar common_baseline      = common_baseline
    return scalar heterog_dose         = heterog_dose

    return scalar sfsd_pair            = sfsd_pair
    return scalar n_baseline_cells     = n_baseline_cells
    return scalar n_sfsd_cells         = n_sfsd_cells

    return scalar common_switch_t      = common_switch_t
    return scalar common_switch_cal    = common_switch_cal
    return scalar first_switch_cal     = first_switch_cal
    return scalar last_switch_cal      = last_switch_cal

    * Sample changes. Missing (.) = not assessed in this mode.
    return scalar n_dropped_baseline   = n_dropped_baseline
    return scalar n_dropped_pretreat   = n_dropped_pretreat
    return scalar n_dropped_alld       = n_dropped_alld
    return scalar n_late_entry         = n_late_entry
    return scalar n_missing_at_start   = n_missing_at_start
    return scalar n_filled_pre_gap     = n_filled_pre_gap
    return scalar n_demoted            = n_demoted
    return scalar n_exit_controls      = n_exit_controls
    return scalar n_post_gap_switchers = n_post_gap_switchers

end
