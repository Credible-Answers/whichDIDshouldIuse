*! whichdidshouldiuse 1.0.0  19oct2026
*! Classify a (Y, G, T, D) panel as CLA, SAD, HAD, or SFSD, with a less strict
*! default for missing treatment and a strict option.

/*==============================================================================
  whichdidshouldiuse.ado

  Classify a (Y, G, T, D) panel as CLA, SAD, HAD, or SFSD, with two modes for
  handling missing treatment: a less strict default, and a strict option that
  reproduces the original drop-on-any-missing rules exactly.

  SYNTAX
    whichdidshouldiuse Y G T D [if] [in] [, detail strict]
      Y  outcome
      G  group identifier
      T  the user's CALENDAR time variable (year, quarter, ...)
      D  treatment

    if/in  restrict the sample. Applied to the CALLER's data, before the
           panel is reduced to the four analysis variables, so the condition
           may name any variable in the data under its original name. -in-
           is applied BEFORE -if- so its row numbers mean what the user saw
           (see section 0a). The restriction also precedes -fillin-, so one
           that removes periods renumbers t and MOVES the baseline period:
           see sessions/ifin_fillin_explained.pdf.
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
    A default run prints the classification and nothing else -- that is the
    point of the default run. Everything else lives in section 8a, AFTER the
    report, behind detail: the input echo, the panel summary, the full
    sample-change accounting, the missing-treatment breakdown and the
    DIAGNOSTICS block.

    The one exception is a "Groups dropped ..." line, which prints ABOVE the
    report WHEN IT IS NONZERO even without detail. Dropping groups changes
    the caller's sample, so it is a warning rather than a diagnostic and has
    to be visible to someone reading only the top of a log. At zero it says
    nothing, so it is left to the appendix, which reports the count either
    way.

    Normal output is "as text"; computed values are "as result". "as error"
    is reserved for genuine errors, of which this program has none. Within a
    single di, a style directive applies to everything after it -- including
    across a /// continuation -- so a literal following a value must re-state
    "as text".

  HAD SUB-CASES
    When the design is HAD, r(had_case) says which control group exists at
    the common switch date F (Chapter 7; de Chaisemartin et al. 2026):
      stayers        some groups keep D = 0 at F (never-switchers)
      quasi-stayers  no stayers, and did_had's quasi-untreated (QS) test
                     does not reject at 5%
      none           no stayers, and the QS test rejects -- or the two
                     lowest doses tie (a mass point), where the test
                     statistic is undefined. In the tie case the report
                     suggests a 2SLS with 1(D > d_min) as instrument;
                     r(n_at_d_min) and r(n_above_d_min) give that
                     instrument's two arms, and the smaller one binds.
      undetermined   no stayers, and did_had could not be run
    The QS test is did_had's own, read from e(estimates). did_had runs in a
    separate frame (Stata 16+), because it calls preserve and this program
    already holds one; the caller's e() is held and restored around it.

  SFSD SUB-CASES
    When the design is SFSD, r(sfsd_case) says which route reached it
    (Chapter 8):
      shared-baseline       the usual condition: a pair of groups sharing a
                            baseline treatment value first switch at
                            different dates (sfsd_pair = 1)
      continuous-baseline   no two groups share a baseline, so sfsd_pair is
                            0, but first-switch timing varies. This is the
                            8.3.5.1 extension (Continuous treatment at
                            period one): sharing a baseline is NOT an
                            essential condition, and a continuously
                            distributed D at t == 1 cannot satisfy it.
                            Estimated with did_multiplegt_dyn's continuous()
                            option. Section 7a, checked only once every
                            other design has been ruled out.
    r(design) is "SFSD" either way, so a caller comparing against "SFSD"
    needs no change; r(sfsd_case) separates the two.

  DEPENDENCY
    Missing packages are installed on demand rather than reported, so a fresh
    Stata needs no setup step.
      distinct (SSC)  used on every path; section 0 installs it, and a
                      FAILED install is the one fatal dependency error.
      did_had (SSC), lprobust (in nprobust, net install -- NOT on SSC) and
                      gtools (SSC)  needed only for the HAD quasi-stayer
                      test; section 7b installs them. Only an install that
                      still leaves a package missing -- no network, a
                      read-only PLUS directory -- leaves the sub-case
                      "undetermined". The classification itself never
                      depends on them.

  Coding practice: every classification conditional tests a NAMED SCALAR
  defined where the underlying statistic is computed; each r() value is
  consumed on the line after the command that set it.

  TIME VARIABLES (package convention):
    t_cal  the user's original calendar date, used ONLY for display.
    t      t_cal normalized to consecutive integers 1..Tmax. ALL logic runs
           on this, so Fg-1 is always a real period.
==============================================================================*/

* The public command is a thin wrapper whose only job is to own the
* varabbrev setting. The classification itself lives in the worker below.
*
* Why the split: the worker must run with abbreviation OFF (otherwise
* "drop t" deletes t_cal -- see section 1), and the setting is GLOBAL to the
* session, so it has to be put back on every exit path. -preserve- unwinds
* itself; -set varabbrev- does not. A restore at the foot of the worker only
* covers the paths the author anticipated: any unexpected error, or a user
* pressing Break, would leave the caller's session with abbreviation
* silently switched off. Wrapping the worker in -capture noisily- is what
* makes the restore unconditional.
*
* -capture- clears r(), so -return add- is load-bearing: it forwards the
* worker's 40-odd returns to the caller. It must come AFTER the restore and
* BEFORE the exit.
program define whichdidshouldiuse, rclass
    version 14

    local varabbrev_was `c(varabbrev)'
    set varabbrev off

    capture noisily _whichdidshouldiuse `0'
    local rc = _rc

    set varabbrev `varabbrev_was'
    return add

    if (`rc') exit `rc'
end

program define _whichdidshouldiuse, rclass
    version 14
    syntax varlist(min=4 max=4 numeric) [if] [in] [, DETail STRict]

    * ---------------------------------------------------------------------- *
    * 0. Dependency. distinct is used on every path, so it is checked before
    *    any work is done -- a failure here costs nothing. It is installed
    *    rather than reported; only an install that still leaves it missing
    *    is an error, and that one IS genuine, hence "as error" and the exit.
    * ---------------------------------------------------------------------- *

    qui capture which distinct
    if (_rc) {
        di as text "Installing " as result "distinct" as text " from SSC ..."
        capture noisily ssc install distinct, replace
        qui capture which distinct
        if (_rc) {
            di as error "whichdidshouldiuse requires distinct, and it could not be installed."
            di as error "Install it by hand with:  ssc install distinct"
            exit 601
        }
    }

    * Variable-name abbreviation is already OFF: the wrapper above turns it
    * off and restores it, so every exit path from here is covered. It must
    * stay off for the whole worker -- otherwise "drop t" deletes t_cal when
    * t_cal is the only t* variable.

    tokenize `varlist'
    local Yvar "`1'"
    local Gvar "`2'"
    local Tvar "`3'"
    local Dvar "`4'"

    * The input echo that used to stand here is printed in section 8a, below
    * the report, so the classification comes first.

    preserve

    * ---------------------------------------------------------------------- *
    * 0a. The if/in sample
    *
    *    Applied HERE -- after -preserve-, before the -keep- below -- so the
    *    condition may name any variable in the caller's data, under its
    *    original name, and -in- row numbers refer to the caller's own data
    *    order. Both go through -keep-, as did_multiplegt_dyn does, rather
    *    than a -touse- tempvar: the -keep- on the next line would delete a
    *    tempvar anyway, and adding one to that -keep- would put a variable
    *    back into the dataset, which is exactly what the shadowing note
    *    below warns against.
    *
    *    -in- FIRST, then -if-. -keep- renumbers the rows it keeps, so
    *    -if- first would make the user's row numbers refer to a dataset they
    *    never saw. Stata's own semantics are that if and in both restrict
    *    the ORIGINAL data and are intersected -- what -marksample- gives
    *    every built-in -- and only this order reproduces that.
    *
    *    NOTE: did_multiplegt_dyn applies -if- first. That is a latent bug,
    *    not a convention to copy; it only hides because the two qualifiers
    *    are rarely combined. Do not "fix" this back.
    *    Reasoning in full: sessions/ifin_fillin_explained.pdf
    * ---------------------------------------------------------------------- *

    if ("`in'" != "") qui keep `in'
    if ("`if'" != "") qui keep `if'

    * An if/in that empties the data is a genuine error -- there is no panel
    * left to classify. Caught here because the failure would otherwise
    * surface far from its cause: -fillin- on an empty dataset leaves Tmax
    * missing, and the -forvalues k = 1/.- in section 1 then silently does
    * not execute.
    * -preserve- unwinds on its own, and the wrapper restores varabbrev on
    * every exit path, so this exit needs no cleanup of its own.
    if (_N == 0) {
        di as error "no observations; the if/in condition selected nothing"
        exit 2000
    }

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

    * The panel summary that used to stand here is printed in section 8a.

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

        * Printed here, above the report, ONLY when it actually fires: groups
        * discarded from the caller's sample are a warning, and a warning
        * belongs above the answer. At zero it says nothing, so it is left to
        * the appendix (section 8a), which reports the count either way and
        * keeps a clean panel's default output down to the verdict alone.
        if (n_dropped_baseline > 0) {
            di as text "Groups dropped for missing baseline (d at t=1, cal " ///
               as result cal_min as text "): " as result n_dropped_baseline ///
               as text "  (" as result n_groups_raw as text " -> " ///
               as result n_groups_baseline as text ")"
        }
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

        * Above the report only when it fires -- see the strict branch.
        if (n_dropped_alld > 0) {
            di as text "Groups dropped for treatment never observed: " ///
               as result n_dropped_alld ///
               as text "  (" as result n_groups_raw as text " -> " ///
               as result n_groups_baseline as text ")"
        }
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

        * Above the report only when it fires -- see the baseline warning.
        if (n_dropped_pretreat > 0) {
            di as text "Groups dropped for pre-treatment violations: " ///
               as result n_dropped_pretreat ///
               as text "  (" as result n_groups_baseline as text " -> " ///
               as result n_groups as text ")"
        }
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

    * The breakdown of the default-rule adjustments is printed in section 8a
    * with the rest of the detail output. Nothing here is discarded from the
    * sample, so it is a diagnostic, not a safety warning.

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

    * ---- HAD: sign of the dose, stayers, lowest dose ---------------------- *
    * Read from d at t == Fg (one row per switcher), not d_Fg, so a tie test
    * is not blurred by d_Fg's float storage.
    qui sum d if t == Fg & Fg < Tplus1
    scalar min_dose_Fg = r(min)
    scalar nonneg_dose = cond(r(N) == 0, 0, r(min) >= 0)

    * Stayers: groups still at D = 0 at the switch date. Under same_Fg and
    * zero_baseline these are exactly the usable never-switchers.
    scalar n_stayers = n_never_treated

    * Lowest positive dose at the switch, and whether two switchers share it.
    * A tie makes did_had's QS statistic D(1)/(D(2)-D(1)) undefined.
    qui sum d if t == Fg & Fg < Tplus1 & d > 0
    scalar had_d_min = cond(r(N) > 0, r(min), .)

    * The two arms of the 1(d > had_d_min) instrument the tie branch suggests:
    * groups sitting AT the lowest positive dose (the comparison arm, i.e. the
    * mass point) and groups strictly above it (the treated arm). The SMALLER
    * arm governs whether that 2SLS is informative, so both are reported --
    * a large mass point with one group above it is a weak instrument, and
    * counting only one arm would hide that.
    *
    * When had_d_min is missing (no positive dose at all) both comparisons are
    * false for every row, so both counts are 0 and had_tie is 0, as before.
    qui count if t == Fg & Fg < Tplus1 & d == had_d_min
    scalar n_at_d_min    = r(N)
    qui count if t == Fg & Fg < Tplus1 & d > had_d_min
    scalar n_above_d_min = r(N)
    scalar had_tie       = (n_at_d_min >= 2)

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
    * sd(Fg) > 0 within the cell -- the test whichdidshouldiuse uses. A cell
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
    * 6. Diagnostics -- printed in section 8a, after the report, so that the
    *    classification comes first. The number is kept so sections 7..9 and
    *    the comments that cite them do not shift.
    * ---------------------------------------------------------------------- *

    * ---------------------------------------------------------------------- *
    * 7. Classification
    *
    *    Designs nest: CLA subset SAD subset HAD-SQS subset SFSD. Checked most
    *    restrictive first. Conditionals read ONLY named scalars.
    * ---------------------------------------------------------------------- *

    local design    "OTHER"
    local estimator ""
    local sfsd_case ""

    if (any_switchers & is_binary01 & is_absorbing & same_Fg & never_treated_groups & zero_baseline) {
        local design    "CLA"
        local estimator "static / event-study TWFE"
    }
    else if (any_switchers & is_binary01 & is_absorbing & !same_Fg) {
        local design    "SAD"
        local estimator "csdid, did_multiplegt_dyn, or did2s"
    }
    else if (any_switchers & same_Fg & zero_baseline & heterog_dose & nonneg_dose) {
        local design    "HAD"
        local estimator "did_had"
    }
    else if (any_switchers & sfsd_pair) {
        local design    "SFSD"
        local estimator "did_multiplegt_dyn"
        local sfsd_case "shared-baseline"
    }

    * ---------------------------------------------------------------------- *
    * 7a. SFSD fallback: continuously distributed baseline treatment
    *
    *    The summary calls SFSD condition (i) -- a PAIR of groups sharing a
    *    baseline value -- NOT essential. The book relaxes it in 8.3.5.1
    *    (Continuous treatment at period one, in 8.3.5 Extensions) to a
    *    continuously distributed D at t == 1, where by construction no two
    *    groups share a baseline, every d_baseline cell is a singleton, and
    *    sfsd_pair is 0 for that reason ALONE. Condition (ii), variation in
    *    when groups first switch, is the essential one -- and it is exactly
    *    !same_Fg, i.e. V(Fg) > 0 over switchers.
    *
    *    So a panel that reached OTHER while having timing variation is an
    *    SFSD under 8.3.5.1, and did_multiplegt_dyn can estimate it with the
    *    continuous() option.
    *
    *    Deliberately NOT a fifth branch of the chain above: this is a
    *    RELAXATION of the SFSD branch, not a further step in the
    *    most-restrictive-first nesting, and it must fire only once every
    *    other design has been ruled out. Hence the guard on design.
    *
    *    same_Fg is 1 when sd(Fg) is missing (a single switcher), so a lone
    *    switcher correctly does not reach here: one group cannot satisfy
    *    condition (ii).
    * ---------------------------------------------------------------------- *

    if ("`design'" == "OTHER") {
        if (any_switchers & !same_Fg) {
            local design    "SFSD"
            local estimator "did_multiplegt_dyn, with the continuous() option"
            local sfsd_case "continuous-baseline"
        }
    }

    * ---------------------------------------------------------------------- *
    * 7b. HAD sub-case: stayers, quasi-stayers, or neither
    *
    *    Stayers are observed directly. Without them, the quasi-stayer
    *    question is answered by did_had's own QS test (effect 1, i.e. the
    *    dose at F), read back from e(estimates): col 8 = T, col 9 = p-value.
    *    did_had calls preserve, which cannot nest inside ours, so it runs in
    *    a separate frame -- hence the Stata 16 requirement.
    * ---------------------------------------------------------------------- *

    local had_case ""
    local had_why  ""
    scalar qs_stat   = .
    scalar qs_pval   = .
    scalar qs_n      = .
    scalar qs_reject = .

    if ("`design'" == "HAD") {
        if (n_stayers > 0) {
            local had_case  "stayers"
            local estimator "ivregress 2sls or did_multiplegt_stat"
        }
        else if (had_tie) {
            * D(2) - D(1) = 0: did_had would return T = p = missing. A mass
            * point at the lowest dose is not a quasi-stayer.
            local had_case  "none"
            local estimator "did_had"
            scalar qs_reject = 1
        }
        else {
            * Install what is missing rather than giving up on the sub-case.
            * lprobust ships inside nprobust, which is NOT on SSC -- it needs
            * the net install, exactly as did_had.ado itself does it. The
            * re-check after each install is what separates "was missing,
            * fixed" from "still missing", and it is what keeps had_missing
            * meaningful: only a package that survives its own install lands
            * there. "capture noisily" so no network failure can stop the
            * program, while the install output stays visible.
            local had_missing ""
            foreach cmd in did_had lprobust gtools {
                qui capture which `cmd'
                if (_rc) {
                    di as text "Installing " as result "`cmd'" as text ///
                       " for the HAD quasi-stayer test ..."
                    if ("`cmd'" == "lprobust") {
                        capture noisily net install nprobust, replace ///
                            from(https://raw.githubusercontent.com/nppackages/nprobust/master/stata)
                    }
                    else {
                        capture noisily ssc install `cmd', replace
                    }
                    qui capture which `cmd'
                    if (_rc) local had_missing "`had_missing' `cmd'"
                }
            }

            if (c(stata_version) < 16) {
                local had_why "running did_had here needs Stata 16 or later (frames)"
            }
            else if ("`had_missing'" != "") {
                local had_why "not installed:`had_missing'"
            }
            else {
                * Switchers only, observed d only: did_had reads a missing d
                * as a treatment change. Switchers have d at F-1 and F.
                tempname had_fr had_hold had_est
                version 16: frame put y g t d if Fg < Tplus1 & !missing(d), into(`had_fr')

                * did_had is eclass: hold the caller's e(), and clear it so
                * a stale e(estimates) cannot pass for a result. did_had
                * exits with rc 0 on some failures, hence the confirm below.
                _estimates hold `had_hold', restore nullok
                ereturn clear
                version 16: capture frame `had_fr': did_had y g t d, effects(1) graph_off _no_updates
                local had_rc = _rc
                capture confirm matrix e(estimates)
                if (`had_rc' == 0 & _rc == 0) {
                    matrix `had_est' = e(estimates)
                    scalar qs_n    = `had_est'[1, 5]
                    scalar qs_stat = `had_est'[1, 8]
                    scalar qs_pval = `had_est'[1, 9]
                }
                _estimates unhold `had_hold'
                version 16: frame drop `had_fr'

                if (missing(qs_pval)) {
                    local had_why "did_had did not return a QS test (rc = `had_rc')"
                }
            }

            local estimator "did_had"
            if (missing(qs_pval)) {
                local had_case "undetermined"
            }
            else {
                scalar qs_reject = (qs_pval < 0.05)
                local had_case = cond(qs_reject, "none", "quasi-stayers")
            }
        }
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
        di as text    "  t=" common_switch_cal " (period " common_switch_t "), and " n_never_treated " group(s) never switch."
        di as text    ""
        di as text    "  Estimator: `estimator'"
        di as text    ""
        di as text    "  See Chapter 3 of the DID textbook (de Chaisemartin and"
        di as text    "  D'Haultfoeuille)."
    }
    else if ("`design'" == "SAD") {
        di as result "  DESIGN: Staggered Adoption Design (SAD)"
        di as text    "{hline 70}"
        di as text    "  Binary and absorbing treatment, with variation in treatment"
        di as text    "  timing across the " n_switchers " switching group(s): first switches"
        di as text    "  occur between t=" first_switch_cal " and t=" last_switch_cal "."
        di as text    ""
        di as text    "  Estimator: `estimator'"
        di as text    ""
        di as text    "  See Chapter 6 of the DID textbook."
    }
    else if ("`design'" == "HAD") {
        di as result "  DESIGN: Heterogeneous Adoption Design (HAD)"
        di as text    "{hline 70}"
        di as text    "  All groups untreated at baseline (t=" cal_min "); all " n_switchers " treated"
        di as text    "  group(s) experience treatment at t=" common_switch_cal ", but the treatment dose varies"
        di as text    "  across treated groups."
        di as text    ""
		
        if ("`had_case'" == "stayers") {
            di as text "  Sub-case: " as result "stayers" as text " -- " as result n_stayers ///
               as text " group(s) stay untreated at t=" as result common_switch_cal ///
               as text "."
            di as text ""
            di as text "  ATT and WATT are identified; they can be estimated at the usual"
            di as text "  sqrt(G) rate."
            di as text ""
            di as text "  Estimator: WATT by ivregress 2sls dY (d = 1(d>0));"
            di as text "             ATT and WATT by did_multiplegt_stat."
            di as text ""
            di as text "  See Chapter 7 of the DID textbook."
        }
        else if ("`had_case'" == "quasi-stayers") {
            di as text "  Sub-case: " as result "quasi-stayers" as text " -- no group remains untreated,"
            di as text "  but did_had's test does not reject the null that some doses are"
            di as text "  close to 0 (p-value = " as result %5.3f qs_pval as text ")."
            di as text ""
            di as text "  The WATT parameter is identified, using the quasi-stayers as"
            di as text "  controls; it can be estimated nonparametrically, with"
            di as text "  bias-corrected CIs."
            di as text ""
            di as text "  Estimator: `estimator'"
            di as text ""
            di as text "  See Chapter 7 of the DID textbook; de Chaisemartin et al. (2026)."
        }
        else if ("`had_case'" == "none") {
            di as text "  Sub-case: " as result "no stayers or quasi-stayers" as text " -- the lowest treatment dose"
            di as text "  is not close to 0. It is still possible to identify the sign of the"
            di as text "  WATT, if one is willing to make an assumption on treatment effect"
            di as text "  heterogeneity (on top of the usual parallel-trends and"
            di as text "  no-anticipation assumptions)."
            * The two routes here differ only in what can be estimated: a mass
            * point at the lowest dose gives a usable 1(d > d_min) instrument,
            * a rejected QS test does not.
            * The blank line is printed once, BEFORE the branch, so the gap
            * above Estimator is identical on both routes.
            di as text ""
            if (had_tie) {
                di as text "  Estimator: ivregress 2sls dY (d = 1(d>" as result had_d_min as text "))"
            }
            else {
                di as text "  Estimator: `estimator'"
            }
            di as text ""
            di as text "  See Chapter 7 of the DID textbook; de Chaisemartin et al. (2026)."
        }
        else {
            di as text "  Sub-case: " as result "no stayers" as text " -- the quasi-stayer test could not be run."
            di as text "  The reason why the quasi-stayer test could not be run is stored in"
            di as text "  r(had_why)."
            di as text ""
            * Only reachable when section 7b tried to install and the package
            * is STILL missing -- no network, a read-only PLUS directory. On a
            * normal run the install repairs it and this never prints.
            if ("`had_missing'" != "") {
                di as text "  Automatic installation failed. Install by hand with:"
                di as text "    ssc install did_had"
                di as text "    ssc install gtools"
                di as text "    net install nprobust, from(https://raw.githubusercontent.com/nppackages/nprobust/master/stata)"
            }
            di as text ""
            di as text "  See Chapter 7 of the DID textbook; de Chaisemartin et al. (2026)."
        }
    }
    else if ("`sfsd_case'" == "continuous-baseline") {
        di as result "  DESIGN: Staggered First Switch Design (SFSD)"
        di as text    "{hline 70}"
        di as text    "  The design is not a classical DID design, a staggered adoption"
        di as text    "  design, or an heterogeneous adoption design. On the other hand, it"
        di as text    "  is a staggered first switch design: some groups experience their"
        di as text    "  first treatment switch at different dates."
        di as text    ""
        di as text    "  First switches occur between t=" first_switch_cal " and t=" last_switch_cal "."
        di as text    ""
        di as text    "  Estimator: `estimator'"
        di as text    ""
        di as text    "  As the period-one treatment is continuously distributed (all groups"
        di as text    "  have different period-one treatment), the did_multiplegt_dyn package"
        di as text    "  needs to be used with the continuous option."
        di as text    ""
        di as text    "  See Chapter 8 of the DID textbook. In particular, see section"
        di as text    "  8.3.5.1 for details on the continuous option."
    }
    else if ("`design'" == "SFSD") {
        di as result "  DESIGN: Staggered First Switch Design (SFSD)"
        di as text    "{hline 70}"
        di as text    "  The design is not a classical DID design, a staggered adoption"
        di as text    "  design, or an heterogeneous adoption design. On the other hand, it"
        di as text    "  is a staggered first switch design: some groups share the same"
        di as text    "  baseline treatment but experience their first treatment switch at"
        di as text    "  different dates."
        di as text    ""
        di as text    "  First switches occur between t=" first_switch_cal " and t=" last_switch_cal "."
        di as text    ""
        di as text    "  Estimator: `estimator'"
        di as text    ""
        di as text    "  See Chapter 8 of the DID textbook."
    }
    else {
        di as result "  DESIGN: Other Design"
        di as text    "{hline 70}"
        di as text    "  Your design does not fit into any of the designs studied in the DID"
        di as text    "  textbook."
        di as text    ""
        di as text    "  Why each design was ruled out:"

        * ---- CLA ----
        di as text    ""
        di as text    "   CLA requires: switchers, binary {0,1}, absorbing, no timing"
        di as text    "                 variation, never-treated groups, zero baseline."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!is_binary01)           di as text "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di as text "     - failed: treatment not absorbing"
        if (!same_Fg)               di as text "     - failed: treatment timing varies"
        if (!never_treated_groups)  di as text "     - failed: no never-treated groups usable at the switch date"
        if (!zero_baseline)         di as text "     - failed: baseline treatment not 0 for all groups"

        * ---- SAD ----
        di as text    ""
        di as text    "   SAD requires: switchers, binary {0,1}, absorbing, timing variation."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!is_binary01)           di as text "     - failed: treatment not binary {0,1}"
        if (!is_absorbing)          di as text "     - failed: treatment not absorbing"
        if (same_Fg)                di as text "     - failed: no variation in treatment timing"

        * ---- HAD ----
        di as text    ""
        di as text    "   HAD requires: switchers, common switch date, zero baseline,"
        di as text    "                 heterogeneous, non-negative dose at the switch."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!same_Fg)               di as text "     - failed: switch dates differ across groups"
        if (!zero_baseline)         di as text "     - failed: baseline treatment not 0 for all groups"
        if (!heterog_dose)          di as text "     - failed: size of first change does not vary"
        if (any_switchers & !nonneg_dose) di as text "     - failed: some doses at the switch are negative"

        * ---- SFSD ----
        di as text    ""
        di as text    "   SFSD requires: switchers, and two groups sharing a baseline"
        di as text    "                  treatment value that first switch at"
        di as text    "                  different dates."
        if (!any_switchers)         di as text "     - failed: no switchers"
        if (!sfsd_pair) {
            di as text "     - failed: no two groups share a baseline treatment value while"
            di as text "               first switching at different dates"
        }

        di as text    ""
        di as text    "  See Section 8.5.2 of the DID textbook for possible estimation"
        di as text    "  strategies in such cases."
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
    * 8a. Detail appendix
    *
    *    The input echo (was section 1), the panel summary (was section 1) and
    *    the diagnostics dump (was section 6), all gated behind -detail-.
    *    Printed HERE, below the report, so the classification is the first
    *    thing the user sees and the scalars behind it read as supporting
    *    evidence rather than a preamble.
    *
    *    Pure display, so position cannot affect any result: every name below
    *    is a local or a named scalar, each assigned once earlier and never
    *    reassigned. Scalars and locals are not part of the dataset, so they
    *    would survive -restore- too.
    *
    *    NOT here, deliberately: the dropped-group and missing-treatment
    *    lines. Those report groups discarded from the caller's sample -- a
    *    warning, not a diagnostic -- so they are ungated and stay ABOVE the
    *    report, where someone skimming the top of a log will see them.
    *
    *    Gating idiom: quote BOTH sides, or the absent option expands to
    *    if ( != "") -- a syntax error on the default path.
    * ---------------------------------------------------------------------- *

    if ("`detail'" != "") {
        di as text _n "{hline 70}"
        di as text    "  whichdidshouldiuse:  Y=" as result "`Yvar'" ///
                      as text "  G=" as result "`Gvar'" ///
                      as text "  T=" as result "`Tvar'" ///
                      as text "  D=" as result "`Dvar'"
        * Compound double quotes throughout: an if condition can itself
        * contain " (if a caller variable is a string), which would otherwise
        * close the local's expansion early and break the -di-.
        if (`"`if'`in'"' != "") {
            di as text "  sample: " as result `"`if' `in'"'
        }
        if ("`strict'" != "") di as text "  missing treatment: strict"
        else                  di as text "  missing treatment: default (less strict)"
        di as text    "{hline 70}"

        di as text _n "Panel: " as result Tmax ///
           as text " periods, calendar " as result cal_min ///
           as text " .. " as result cal_max
        di as text    "       (t normalized to 1.." as result Tmax ///
           as text "; never-switcher sentinel = " as result Tplus1 as text ")"

        * Sample changes. Above the report these print only when nonzero, so
        * repeat them here unconditionally: under -detail- the full accounting
        * should be visible even when nothing was dropped.
        di as text _n "Groups dropped:"
        if ("`strict'" != "") {
            di as text "  missing baseline (d at t=1, cal " ///
               as result cal_min as text "):          " ///
               as result n_dropped_baseline
            di as text "  pre-treatment violations:              " ///
               as result n_dropped_pretreat
        }
        else {
            di as text "  treatment never observed:              " ///
               as result n_dropped_alld
        }
        di as text    "  groups retained:                       " as result n_groups ///
           as text    " of " as result n_groups_raw

        if ("`strict'" == "") {
            di as text _n "Missing treatment (default rules; use , strict to drop instead):"
            di as text "  late entrants, baseline taken at entry:        " as result n_late_entry
            di as text "  d missing at start, baseline taken later:      " as result n_missing_at_start
            di as text "  pre-switch gaps read as baseline:              " as result n_filled_pre_gap
            di as text "  gap right before switch, demoted to control:   " as result n_demoted
            di as text "  controls leaving the panel early:              " as result n_exit_controls
            di as text "  switchers with d missing after the switch:     " as result n_post_gap_switchers
        }

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
        di as text    "  switch periods (t)   = " as result first_switch_t ///
           as text    " .. " as result last_switch_t
        di as text    "  switch dates (t_cal) = " as result first_switch_cal ///
           as text    " .. " as result last_switch_cal
        di as text    "  is_binary            = " as result is_binary ///
           as text    "   (d in {" as result d_min as text ", " as result d_max as text "})"
        di as text    "  is_binary01          = " as result is_binary01
        di as text    "  is_absorbing         = " as result is_absorbing
        di as text    "  zero_baseline        = " as result zero_baseline ///
           as text    "   (groups with d_baseline!=0: " as result n_nonzero_baseline as text ")"
        di as text    "  common_baseline      = " as result common_baseline
        di as text    "  heterog_dose         = " as result heterog_dose ///
           as text    "   (sd(first_change) = " as result sd_change_value as text ")"
        di as text    "  nonneg_dose          = " as result nonneg_dose ///
           as text    "   (min dose at the switch = " as result min_dose_Fg as text ")"
        di as text    "  n_stayers            = " as result n_stayers
        di as text    "  had_d_min            = " as result had_d_min ///
           as text    "   (lowest positive dose at the switch)"
        di as text    "  had_tie              = " as result had_tie
        di as text    "  n_at_d_min           = " as result n_at_d_min ///
           as text    "   (groups at the lowest dose)"
        di as text    "  n_above_d_min        = " as result n_above_d_min ///
           as text    "   (groups above it)"
        di as text    "  sfsd_pair            = " as result sfsd_pair ///
           as text    "   (groups in cells with a usable pair: " as result n_sfsd_groups as text ")"
        di as text    "  n_baseline_cells     = " as result n_baseline_cells
        di as text    "  n_sfsd_cells         = " as result n_sfsd_cells ///
           as text    "   (cells carrying timing variation)"
        di as text    "  n_post_gap_switchers = " as result n_post_gap_switchers
        di as text    "{hline 70}"
    }

    * ---------------------------------------------------------------------- *
    * 9. Return
    * ---------------------------------------------------------------------- *

    * restore BEFORE the returns is safe only because every value below is a
    * scalar or a local, neither of which is part of the dataset.
    restore

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

    * HAD sub-case. had_case is empty unless the design is HAD; the qs_*
    * scalars are missing unless did_had's test was run.
    return local  had_case             "`had_case'"
    return local  had_why              "`had_why'"
    return scalar nonneg_dose          = nonneg_dose
    return scalar n_stayers            = n_stayers
    return scalar had_d_min            = had_d_min
    return scalar had_tie              = had_tie
    return scalar n_at_d_min           = n_at_d_min
    return scalar n_above_d_min        = n_above_d_min
    return scalar qs_stat              = qs_stat
    return scalar qs_pval              = qs_pval
    return scalar qs_n                 = qs_n
    return scalar qs_reject            = qs_reject

    return scalar sfsd_pair            = sfsd_pair
    return scalar n_baseline_cells     = n_baseline_cells
    return scalar n_sfsd_cells         = n_sfsd_cells

    * SFSD sub-case. sfsd_case is empty unless the design is SFSD; it says
    * which route got there -- "shared-baseline" for the usual pair test, or
    * "continuous-baseline" for the 8.3.5.1 extension, where sfsd_pair is 0
    * because a continuous D at period one leaves every baseline distinct.
    return local  sfsd_case            "`sfsd_case'"

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
