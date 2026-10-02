# whichDIDshouldIuse

A Stata command that looks at a panel and tells you which difference-in-differences
**design** it is, as well as estimator candidates.

You pass it four variables; it reports one of **CLA**, **SAD**, **HAD**, **SFSD**,
or **OTHER**, together with the diagnostics behind that answer.

```stata
adopath + "Stata"
use "data/moser_voena_didtextbook.dta", clear
whichDIDshouldIuse patents subclass year twea
```

```
Groups dropped for treatment never observed: 0  (7248 -> 7248)

----------------------------------------------------------------------
  DESIGN: Classical DID Design (CLA)
----------------------------------------------------------------------
  Binary and absorbing treatment, no variation in treatment
  timing: all 336 treated group(s) experience treatment at
  t=1919 (period 20), and 6912 group(s) never switch.
  Estimator: static / event-study TWFE
  See Chapter 3 of the DID textbook (de Chaisemartin and
  D'Haultfoeuille).
----------------------------------------------------------------------
```

Add `, detail` to also see the panel summary, the missing-treatment breakdown (default
mode), and the full diagnostics table.

Design definitions follow **de Chaisemartin & D'Haultfœuille**.

---

## Repository layout

| Path | What it is |
|---|---|
| **`Stata/whichDIDshouldIuse.ado`** | The command. All classification logic lives here and nowhere else. |
| **`Stata/examples.do`** | The driver: runs `whichDIDshouldIuse` on the four panels in `data/` and prints the result of each. |
| **`Stata/test_had.do`** | Tests the HAD sub-cases on synthetic panels with known QS values. |
| **`Stata/test_missing.do`** | Tests both missing-treatment modes (`strict` and default) against known expected results. |
| **`Stata/make_synthetic.do`** | Builds the panels `test_missing.do` runs against, written to `data/synthetic/`. |
| **`data/`** | Four example panels from the textbook (Moser–Voena, Wolfers, Gentzkow et al., Pierce–Schott). |

---

## Syntax

```stata
whichDIDshouldIuse Y G T D [, detail strict]
```

| Argument | Meaning |
|---|---|
| `Y` | Outcome |
| `G` | Group identifier |
| `T` | **Calendar** time (year, quarter, …) |
| `D` | Treatment |

All four variables are positional and required, in that order. You pass **your own
variable names** — no pre-renaming needed. The command runs inside
`preserve`/`restore`, so your data in memory is unchanged when it finishes.

| Option | Effect |
|---|---|
| `detail` | Also print the input echo, the panel summary, the missing-treatment breakdown (default mode only), and the full `DIAGNOSTICS` block. |
| `strict` | Handle missing treatment by dropping groups instead of applying the default rules below. |

By default you get the classification and nothing else — bar one dropped-group
line (what it reports depends on the mode, see below), which is **never**
suppressed. That line reports groups discarded from your sample, which is a
warning rather than a diagnostic: a run that silently loses 400 groups must not
look like one that loses none.

`detail` controls **display only**. Every `r()` return is set either way, so you
never need it to get at a result — see [Returned values](#returned-values).

### Two modes for missing treatment

`D` missing somewhere other than a group's baseline period used to mean the group
was dropped outright. That is still available as `, strict`. The **default**
(no option) is less strict, modeled on how `did_multiplegt_dyn` treats gaps: a
group is kept whenever its first switch date can still be pinned down, and every
adjustment that could change the answer is reported rather than silently applied.

| | `strict` | default |
|---|---|---|
| Baseline (`d_baseline`) | `D` at `t == 1`, literally; missing there drops the group | `D` at the first period it is observed (entry may be later than `t == 1`) |
| `D` missing before the switch | Drops the group | Read as baseline if it falls between two baseline observations; if the gap sits right before the switch, the group is **demoted** to a control (the exact switch date is unknown) |
| Control that stops being observed | Not applicable — every control is fully observed | Tracked via `end_g` / `Fg_trunc`; the control only counts as a usable never-treated group, or as a usable member of an SFSD pair, while it is still known to be at baseline |
| `D` missing after a switch | Left missing in both modes; the absorbing check rests on observed `D` only | Same |

Without `, detail`, the default mode still prints one unconditional line, "Groups
dropped for treatment never observed: …" — groups where `D` is never observed at
all are dropped in either mode, since there is nothing to classify. With
`, detail`, it additionally prints a breakdown of every other adjustment (late
entrants, filled gaps, demotions, controls that exit early, post-switch gaps),
none of which drop a group — they are why the sample size matches the raw group
count even though some `D` was missing.

`r(strict)` records which mode ran. `Stata/test_missing.do` (with panels built by
`Stata/make_synthetic.do`) exercises both modes against known expected results.

It classifies; it does **not** estimate. There are no fixed effects, weights, or
standard-error options, because nothing is being fitted.

**Dependency:** `distinct` (SSC) — `ssc install distinct`

For HAD panels **without stayers**, the sub-case also needs `did_had` (SSC), which
itself needs `lprobust` (`net install nprobust, from(https://raw.githubusercontent.com/nppackages/nprobust/master/stata)`)
and `gtools` (SSC), plus Stata 16 or later. Without them the design is still
reported as HAD, with `r(had_case) = "undetermined"`.

### Finding the command

`whichDIDshouldIuse.ado` sits in `Stata/`, so add that folder to the search path:

```stata
adopath + "Stata"
```

While editing the `.ado`, also run `discard` first. Stata **caches** `.ado`
programs in memory, so without it an edit is silently ignored and you get results
from the stale version — no error, no warning.

---

## The designs

Ordered from most to least restrictive. They **nest**: CLA ⊂ SAD ⊂ HAD-SQS ⊂ SFSD.
Conditions are checked most-restrictive-first, so you get the tightest design that
holds.

| Design | In words | Estimator |
|---|---|---|
| **CLA** | Binary 0/1, absorbing, everyone switches on the same date, never-treated controls exist, everyone starts untreated | static / event-study TWFE |
| **SAD** | As CLA, but switch dates **vary** across groups | `csdid`, `did_multiplegt_dyn`, `did2s` |
| **HAD** | One common switch date, everyone starts untreated, and the **size** of the change differs and is non-negative (a dose, not an on/off switch) | depends on the sub-case, below |
| **SFSD** | Broadest tested. Permits **non-absorbing** treatment (switching back off) and **heterogeneous baseline** doses | `did_multiplegt_dyn` |
| **OTHER** | None of the above. The output lists, condition by condition, exactly which checks failed for each design. | — |

### HAD sub-cases

Inside HAD, what you can estimate depends on which control group exists at the
common switch date (Chapter 7; de Chaisemartin et al. 2026). `r(had_case)` says which:

| `r(had_case)` | When | What is identified | Estimator |
|---|---|---|---|
| `stayers` | Some groups stay at `D = 0` at the switch | CAS, ATT, WATT at the usual √G rate | `ivregress 2sls Δy (d = 1(d>0))`; `did_multiplegt_stat` |
| `quasi-stayers` | No stayers, and `did_had`'s quasi-untreated test does **not** reject at 5% | WATT, at a slower rate, bias-corrected CIs | `did_had` |
| `none` | No stayers, and the test rejects — or the two lowest doses tie (a mass point at the lowest dose) | Only the **sign** of WATT, and only under BOUND-HET, which pretrends cannot test | `did_had` |
| `undetermined` | No stayers, and `did_had` could not be run (not installed, Stata < 16, or it failed on the data) | — | `did_had` (it runs the test itself) |

The quasi-stayer test is **`did_had`'s own**, not a re-implementation. The command
runs `did_had y g t d, effects(1) graph_off` on the switchers and reads the test
from `e(estimates)`: `QS = D(1) / (D(2) − D(1))` over the doses at the switch, with
p-value `1/(1+QS)`, so it rejects when `QS > 19`. With stayers no test is needed,
and with a tie the statistic is undefined, so `did_had` is not called in either case.

### What makes SFSD different

SFSD asks whether there exist two groups `g ≠ g'` with the **same baseline
treatment** that **first switch at different dates**. That is a *pair-existence*
test, not a variance test — timing variation **within** a shared-baseline cell.
Per `d_baseline` cell, the test is:

```
min(Fg over switchers in the cell)  <  max(Fg_trunc over all groups in the cell)
```

`Fg_trunc` truncates a control's switch date to the last period it is still
*known* to be at baseline (`Fg_trunc = Fg` for switchers and for fully observed
controls — see [Two modes for missing treatment](#two-modes-for-missing-treatment)).
This matters because the later group in the pair must still be a usable
comparison — observably at baseline — when the earlier group switches, not
merely share its baseline value on paper. In `, strict` mode every control is
fully observed, so `Fg_trunc == Fg` everywhere and the test reduces to
`sd(Fg) > 0` within the cell.

A panel whose baseline cells are all singletons fails SFSD no matter how much
overall timing variation it has, because no two groups share a baseline to be
compared. `r(n_baseline_cells)` and `r(n_sfsd_cells)` report how the groups
partition and how many of those cells actually carry identifying variation.

---

## What it does to your data first

Four preparation steps run before anything is classified. Each can drop or adjust
groups, and the command reports what happened — which lines are unconditional
versus gated behind `detail` is covered in
[Two modes for missing treatment](#two-modes-for-missing-treatment).

1. **Balance the panel.** `fillin G T` gives every group a row for every calendar
   period present in the data, so a gap becomes an explicit missing row.
2. **Normalize time.** `t_cal` keeps your calendar values (1918, 1919, …); a new
   `t` numbers periods `1, 2, 3, …`. All logic uses `t`; all messages use `t_cal`.
   This is what makes `Fg-1` always a real period even when calendar years have
   gaps — Pierce–Schott has no 2003, and it still works.
3. **Baseline treatment.** `d_baseline` is `D` at `t == 1` in `, strict` mode —
   *literally* the first period, and a group with missing treatment there is
   dropped. By default, `d_baseline` is `D` at the first period it is actually
   observed (`FD_g`), so a group whose first few periods are missing is kept
   rather than dropped. Either way, a group where `D` is **never** observed at
   all has nothing to check against and is dropped in both modes.
4. **Pre-treatment integrity.** In `, strict` mode a group is dropped if `D` is
   missing or differs from `d_baseline` at any period before its first switch —
   a consistency check on `Fg`, since treatment is flat at baseline before the
   first switch by definition, so a violation means `Fg` was measured wrong. By
   default, a gap in that window is read as baseline (both observed neighbors
   agree), unless the gap sits immediately before the apparent switch — then the
   exact switch date is unknown, and the group is **demoted** to a control known
   at baseline through the last period before the gap.

---

## Returned values

`whichDIDshouldIuse` is `rclass`. Read `r()` **immediately** — the next command
that returns `r()` results wipes it.

### The answer

| Return | Type | Values |
|---|---|---|
| `r(design)` | string | `"CLA"`, `"SAD"`, `"HAD"`, `"SFSD"`, `"OTHER"` |
| `r(estimator)` | string | Recommended estimator (empty if `OTHER`) |
| `r(strict)` | 0/1 | 1 if `, strict` was used, 0 for the default mode |

### Sample sizes

| Return | Meaning |
|---|---|
| `r(n_groups)` | Groups surviving both filters — the sample actually classified |
| `r(n_switchers)` | Groups that change treatment at some point |
| `r(n_never_treated)` | Groups that never change treatment, and are still usable (at baseline) at the earliest switch |
| `r(n_truncated_controls)` | Controls that stop being observed before the end of the panel (default mode only; 0 in `, strict`) |

`r(n_switchers) + r(n_never_treated) = r(n_groups)` only when there are no
truncated controls that drop out *before* the earliest switch; those are excluded
from `r(n_never_treated)` but still counted in `r(n_groups)`.

### Sample adjustments (missing treatment)

Each is a scalar count of groups affected; `.` means "not assessed in this mode"
rather than zero. `strict` sets the drop counters and leaves the default-mode
counters missing; the default mode does the reverse.

| Return | Mode | Meaning |
|---|---|---|
| `r(n_dropped_baseline)` | `strict` | Groups dropped for missing `D` at `t == 1` |
| `r(n_dropped_pretreat)` | `strict` | Groups dropped for a pre-treatment violation |
| `r(n_dropped_alld)` | default | Groups dropped because `D` is never observed |
| `r(n_late_entry)` | default | Groups whose baseline is taken at a later entry date |
| `r(n_missing_at_start)` | default | Groups observed (via `Y`) before `D` is first observed |
| `r(n_filled_pre_gap)` | default | Groups with a pre-switch gap read as baseline |
| `r(n_demoted)` | default | Groups demoted to a control because a gap sits right before the apparent switch |
| `r(n_exit_controls)` | default | Never-switchers whose `D` stops being observed before the end of the panel |
| `r(n_post_gap_switchers)` | both | Switchers with `D` missing after their switch (reported, never dropped, in either mode) |

### Condition flags (all 0/1)

The inputs to the decision; each answers one yes/no question.

| Return | 1 means |
|---|---|
| `r(any_switchers)` | At least one group changes treatment |
| `r(same_Fg)` | All switchers switch at the **same** period |
| `r(is_binary)` | `D` takes only two distinct values — *any* two |
| `r(is_binary01)` | Those two values are exactly 0 and 1 |
| `r(is_absorbing)` | Once switched, `D` never changes again |
| `r(zero_baseline)` | Every group has `d_baseline == 0` |
| `r(common_baseline)` | Every group has the *same* `d_baseline` (not necessarily 0) |
| `r(heterog_dose)` | The size of the first treatment change varies across switchers |
| `r(sfsd_pair)` | Two groups share a baseline and first switch at different dates |

`r(n_baseline_cells)` and `r(n_sfsd_cells)` accompany `r(sfsd_pair)`.

**`is_binary` vs `is_binary01`.** `is_binary` asks "only two values?" — a treatment
in `{4, 9}` passes. `is_binary01` also requires those values to be 0 and 1. The
definitions need a genuine 0 (that is what makes a control group untreated), so
CLA and SAD branch on `is_binary01`. Both are reported so a `{4,9}` coding is
*visible* rather than silently accepted or silently rejected. Seeing
`is_binary = 1` with `is_binary01 = 0` means your treatment needs rescaling.

**`zero_baseline` vs `common_baseline`** is the same relationship: the strict
version the definitions require, and the looser "everyone starts from the same
place, whatever it is." Only the strict one drives the branches.

### HAD sub-case

| Return | Meaning |
|---|---|
| `r(had_case)` | `"stayers"`, `"quasi-stayers"`, `"none"`, `"undetermined"`; empty unless the design is HAD |
| `r(n_stayers)` | Groups still at `D = 0` at the switch date |
| `r(nonneg_dose)` | 1 if no switcher's dose at the switch is negative (required for HAD) |
| `r(had_d_min)` | Lowest positive dose at the switch |
| `r(had_tie)` | 1 if two or more switchers share that lowest dose |
| `r(qs_stat)`, `r(qs_pval)`, `r(qs_n)` | `did_had`'s QS statistic, its p-value, and the number of groups it used; missing unless `did_had` was run |
| `r(qs_reject)` | 1 if quasi-stayers are rejected at 5% (or there is a tie); missing if not assessed |

### Switch dates

| Return | Units |
|---|---|
| `r(common_switch_t)` | normalized — **only meaningful when `r(same_Fg) == 1`** |
| `r(common_switch_cal)` | calendar |
| `r(first_switch_cal)` / `r(last_switch_cal)` | calendar — the range |

---

## Running the tests

```bash
cd Stata
"/c/Program Files/StataNow19/StataSE-64.exe" -e do examples.do
```

`examples.do` loads the panels via `../data/`, so run it from `Stata/`. `-e` runs
batch and writes `examples.log` next to the do-file. **Stata's exit code is not reliable** —
a file that fails to run at all still exits 0, so read the log.

`examples.do` runs one block per panel, each labelled with the design it is
expected to return, so a mismatch is visible when scanning the log. Every call
passes `, detail`: the log is the test suite, and a regression that prints only
`DESIGN: SAD` where `SFSD` was expected tells you *what* broke but not *why* —
the diagnostics table is the evidence. The Moser–Voena block additionally runs
once **without** `detail`, so the log also carries one sample of default output.
Current results:

| Dataset | Design | Why |
|---|---|---|
| Moser–Voena | **CLA** | 336 subclasses all switch in 1919; 6912 never |
| Wolfers | **SAD** | 29 states adopt unilateral divorce 1969–1985 |
| Gentzkow et al. | **SFSD** | #newspapers is a non-absorbing 0–45 count |
| Pierce–Schott | **HAD**, quasi-stayers | Common 2001 switch, continuous NTR-gap dose; `did_had`'s QS = 6.15, p = 0.14 |

`Stata/test_had.do` tests the HAD sub-cases on synthetic panels with known QS
values, and checks that the QS value on Pierce–Schott equals a standalone `did_had`
run. `Stata/test_missing.do` tests both missing-treatment modes against panels
built by `Stata/make_synthetic.do` (written to `data/synthetic/`), each isolating
one kind of gap so `strict` and the default mode give a visibly different — or,
for the guard cases, the same — answer.

Pierce–Schott ships **wide** (time is in the variable names) and is reshaped to a
long panel inside `examples.do`, following the textbook's own prep.

---

## Using the returns in a loop

The point of the `r()` returns is running this across many datasets:

```stata
foreach f in paper1 paper2 paper3 {
    use "`f'.dta", clear
    quietly whichDIDshouldIuse y g year d
    di "`f': " r(design) "  (estimator: " r(estimator) ")"
}
```

`quietly` here suppresses the classification report *and* the unconditional
dropped-group line(s), so the loop prints one line per dataset. Every `r()`
return is set regardless — and regardless of `detail`, which only controls what
is displayed. There is no middle setting that keeps the warnings but hides the
report; if you want the warnings while looping, drop `quietly` and accept the
longer log.

Datasets with different variable names need a per-dataset mapping, which is why
`examples.do` uses four explicit blocks rather than a loop.

---

## Conventions worth knowing before editing

- **`as text` / `as result` for output, never `in red`.** Red is Stata's *error*
  color; the whole program used it once, which made every successful run look
  like a failure. Labels and prose are `as text`, computed values are
  `as result`, and `as error` stays reserved for genuine errors (there are none
  yet). Within a single `di`, a style directive applies to everything after it —
  including across a `///` continuation — so a literal that follows a value must
  re-state `as text`, or it inherits the value's color.
- **The data-manipulation commands are `quietly`.** `gen`, `egen`, `drop`,
  `fillin` and friends otherwise announce every step (`(282,672 missing values
  generated)`), which buried the actual answer once the diagnostics went behind
  `detail`. Keep new ones quiet.
- **Named scalars, not `r()`, in the conditionals.** Every `r(mean)`/`r(min)` is
  captured into a named scalar on the line right after the command that produced
  it; the classification block reads only those names. `r()` is overwritten by the
  next command, and a bare `r(mean)` deep inside nested `if`s is unreadable.
- **Gating idiom: quote *both* sides.** `if ("`detail'" != "")`, never
  `if (`detail' != "")` — unquoted, an absent option expands to `if ( != "")`, a
  syntax error on the default path. The missing-treatment breakdown gates on two
  conditions this way: `if ("`strict'" == "") & ("`detail'" != "")`.
- **The dropped-group line(s) are never gated by `detail`.** They report groups
  discarded from the caller's sample — a safety warning, not a diagnostic — so a
  run that silently loses 400 groups must not look like one that loses none.
  Everything else missing treatment can report (late entries, filled gaps,
  demotions, exits) changes nothing about which groups survive, so it lives
  behind `detail` like the rest of the diagnostics.
- **`set varabbrev off`** for the whole program, restored on exit. Stata otherwise
  resolves an abbreviated name to any variable it uniquely prefixes — `drop t`
  silently deleted `t_cal` and cost a long debugging session.
- **The `keep Y G T D` is load-bearing**, not tidying: the program uses bare scalar
  names (`Tmax`, `n_groups`, …), and Stata resolves a bare name to a *variable*
  before a scalar.
- **`preserve`/`restore`** protect the caller's data, so constructed variables
  (`Fg`, `d_baseline`, `first_change`) do **not** survive the call. Comment out the
  pair to inspect them.
- **`did_had` runs in its own frame.** It calls `preserve`, which cannot nest
  inside ours (r(621)), so the HAD sub-case step copies the switchers into a
  temporary frame and runs it there. It is `eclass`, so the caller's `e()` is held
  and restored around the call. It also has side effects of its own: `mata clear`,
  and global matrices such as `res_XX` and `np_test`.
- **Deliberate edge cases:** `is_absorbing = 0` when there are no post-switch
  observations (not 1), and `same_Fg = 1` when there is a single switcher (one
  switcher trivially has no timing variation).
- **`Fg_trunc`, not `Fg`, bounds a control's usable horizon.** `Fg_trunc =
  min(Fg, end_g + 1)`, where `end_g` is the last period a control is known to be
  at baseline. It equals `Fg` for switchers and for fully observed controls, so
  in `, strict` mode `Fg_trunc == Fg` everywhere and every check that uses it
  (never-treated count, the SFSD pair test) reduces to the pre-missing-treatment
  rule.
- **Never write a `/*`-containing glob inside a block comment.** Stata *nests*
  block comments, so it opens a second level and silently swallows the rest of the
  file — with no error and a zero exit code.
