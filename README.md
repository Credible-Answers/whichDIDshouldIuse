# whichdidshouldiuse

[![Stata](https://img.shields.io/badge/Stata-16%2B-blue)](https://www.stata.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Tell me which difference-in-differences design my panel is, and which estimator to use.**

You pass four variables; the command reports one of **CLA**, **SAD**, **HAD**, **SFSD**
or **OTHER**, names a suitable estimator, and points you at the relevant chapter of
de Chaisemartin & D'Haultfoeuille's DID textbook.

It classifies; it does **not** estimate. There are no fixed effects, weights or
standard-error options, because nothing is being fitted.

Stata 16 or later. Earlier versions classify every design correctly but cannot reach the
HAD quasi-stayer sub-case, which runs `did_had` inside a frame; there those panels are
still reported as HAD, with `r(had_case) = "undetermined"`.

```stata
use "moser_voena_didtextbook.dta", clear
whichdidshouldiuse patents subclass year twea
```

```
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

---

## Installation

```stata
ssc install whichdidshouldiuse, replace
```

Or install straight from this repository:

```stata
net install whichdidshouldiuse, replace ///
    from("https://raw.githubusercontent.com/Credible-Answers/whichDIDshouldIuse/main/Stata")
```

Either way, `replace` upgrades an existing install.

### The example datasets

The command and its help file are all you need to run `whichdidshouldiuse` on your own
data. The four textbook panels used in the help file's examples ship with the package as
**ancillary files**, which Stata does not install automatically — ask for them
explicitly, and they land in your current working directory:

```stata
net get whichdidshouldiuse, replace
```

That delivers:

| File | Panel | Design |
|---|---|---|
| `moser_voena_didtextbook.dta` | Moser–Voena (2012), patents | `CLA` |
| `wolfers2006_didtextbook.dta` | Wolfers (2006), divorce rates | `SAD` |
| `pierce_schott_didtextbook.dta` | Pierce–Schott, employment (ships **wide**) | `HAD`, quasi-stayers |
| `gentzkowetal_didtextbook.dta` | Gentzkow et al., newspapers | `SFSD` |

With those in place, every example in `help whichdidshouldiuse` runs as written:

```stata
use moser_voena_didtextbook.dta, clear
whichdidshouldiuse patents subclass year twea
```

**Dependency:** `distinct` (SSC). HAD panels without stayers additionally use `did_had`,
`lprobust` (in `nprobust`) and `gtools`. You do not need to install any of these
yourself — the command installs what is missing on first use.

<details>
<summary>Alternative: clone the repository (for development)</summary>

```bash
git clone https://github.com/Credible-Answers/whichDIDshouldIuse.git
```

```stata
adopath + "whichDIDshouldIuse/Stata"
```

When editing the `.ado`, run `discard` first. Stata caches `.ado` programs in memory,
so otherwise an edit is silently ignored and you get results from the stale version —
no error, no warning.

</details>

---

## Syntax

```stata
whichdidshouldiuse Y G T D [if] [in] [, detail strict]
```

| Argument | Meaning |
|---|---|
| `Y` | Outcome |
| `G` | Group identifier |
| `T` | **Calendar** time (year, quarter, …) |
| `D` | Treatment |

All four are positional and required, in that order. You pass **your own variable
names** — no pre-renaming needed. The command runs inside `preserve`/`restore`, so your
data in memory is unchanged when it finishes.

| Option | Effect |
|---|---|
| `detail` | Also print the input echo, the panel summary, the missing-treatment breakdown and the full `DIAGNOSTICS` block. |
| `strict` | Drop groups with missing treatment instead of applying the default repairs. |

By default you get the classification and nothing else — bar a dropped-group line, which
is **never** suppressed. That line reports groups discarded from your sample: a run that
silently loses 400 groups must not look like one that loses none.

`detail` controls **display only**. Every `r()` return is set either way.

`if` and `in` are not options but sample qualifiers, and they do more here than remove
rows: both are applied to your data before the panel is balanced, so a restriction on
time renumbers the periods and moves the baseline — which can change the reported
design. A restriction on a group-level variable is the clean case.

---

## The designs

They **nest** — CLA ⊂ SAD ⊂ HAD-SQS ⊂ SFSD — and are checked most-restrictive-first, so
you get the tightest design that holds.

| Design | In words | Estimator | Chapter |
|---|---|---|---|
| **CLA** | Binary 0/1, absorbing, everyone switches on the same date, never-treated controls exist, everyone starts untreated | static / event-study TWFE | 3 |
| **SAD** | As CLA, but switch dates **vary** across groups | `csdid`, `did_multiplegt_dyn`, `did2s` | 6 |
| **HAD** | Everyone starts untreated and switches on the **same** date, but the **dose** varies | `did_had`, `did_multiplegt_stat` | 7 |
| **SFSD** | Groups share a baseline treatment and first switch at **different** dates. Allows non-absorbing treatment and heterogeneous baseline doses | `did_multiplegt_dyn` | 8 |
| **OTHER** | None of the above | — | 8.5.2 |

### HAD sub-cases

When the design is HAD, `r(had_case)` says which control group exists at the common
switch date — which decides what is identified:

| `r(had_case)` | Meaning | Consequence |
|---|---|---|
| `stayers` | Some groups keep `D = 0` at the switch | ATT and WATT identified, estimable at the usual √G rate |
| `quasi-stayers` | No stayers, but `did_had`'s test does not reject that some doses are close to 0 | WATT identified using quasi-stayers as controls; estimated nonparametrically with bias-corrected CIs |
| `none` | No stayers and no quasi-stayers | Only the **sign** of the WATT is identified, and only under an assumption on treatment-effect heterogeneity |
| `undetermined` | `did_had` could not be run; `r(had_why)` says why | Design is still HAD — only the sub-case is unknown |

The quasi-stayer test is `did_had`'s own. `did_had` itself runs on Stata 12+, but
**this command needs Stata 16 or later to reach that sub-case**: `did_had` calls
`preserve`, which cannot nest inside the one `whichdidshouldiuse` already holds, so it
is run inside a [frame](https://www.stata.com/features/overview/multiple-datasets-in-memory/)
— and frames arrived in Stata 16. On Stata 14 or 15 the design is still reported as HAD,
with `r(had_case) = "undetermined"`. Any other failure yields `undetermined` too, rather
than an error.

### SFSD sub-cases

| `r(sfsd_case)` | Meaning |
|---|---|
| `shared-baseline` | The usual condition: a pair of groups share a baseline value and first switch at different dates |
| `continuous-baseline` | No two groups share a baseline — the signature of a continuously distributed treatment at period one. This is the textbook's §8.3.5.1 extension; estimate with `did_multiplegt_dyn`'s `continuous()` option |

`r(design)` is `"SFSD"` either way.

---

## Preparing your data

Four things to check before running:

1. **`T` is calendar time.** Gaps are fine — the command normalizes internally, so a
   panel missing 2003 still has a well-defined "period before the switch".
2. **The panel is long**, one row per group-period. Wide data must be reshaped first.
3. **`D` is coded so that 0 means untreated.** The design definitions need a genuine
   zero: a treatment coded `{4, 9}` is binary but has no untreated state. `r(is_binary)`
   with `r(is_binary01) = 0` tells you a rescaling is needed.
4. **Pre-period treatment is filled in**, not left missing, where you know it is zero.

---

## Missing treatment

`D` missing outside a group's baseline period could mean the group is unusable. Two
modes handle this.

**Default** (no option), modeled on `did_multiplegt_dyn`: a group is kept whenever its
first switch date can still be pinned down, and every adjustment that could change the
answer is reported rather than silently applied.

**`strict`**: drop any group with missing treatment at baseline or before its switch.

| | `strict` | default |
|---|---|---|
| Baseline | `D` at `t == 1` literally; missing there drops the group | `D` at the first period it is observed |
| Missing before the switch | Drops the group | Read as baseline if bracketed by baseline observations; if the gap sits right before the switch, the group is **demoted** to a control |
| Control stops being observed | Not applicable | Counts as a usable never-treated group only while still known to be at baseline |
| Missing after a switch | Left missing; the absorbing check rests on observed `D` only | Same |

Demotion is the one default repair that can change the answer. A group is demoted to a
control when its treatment is missing in the period immediately before its first apparent
switch: the switch date cannot be pinned down, so the group is kept only as a control.

Suppose the design is heterogeneous adoption, some groups taking a dose of 1 and others a
dose of 2 at a common date. If every dose-2 group has treatment missing in the period
right before that date, all of them are demoted, the survivors share a dose of 1, and the
panel is reported as classical DID — no error, because the designs nest and the tightest
one that holds is the one reported. If demotion removes every switcher the command reports
`OTHER` rather than inventing a design, but it will not warn you when it merely removes
the switchers that distinguished one design from another. `r(n_demoted)` counts them;
agreement between the default and `, strict` is evidence the repairs are not driving the
classification.

---

## Returned values

`whichdidshouldiuse` is `rclass`. Read `r()` **immediately** — the next command that
returns `r()` results wipes it.

### Macros

| Return | Values |
|---|---|
| `r(design)` | `"CLA"`, `"SAD"`, `"HAD"`, `"SFSD"`, `"OTHER"` |
| `r(estimator)` | Recommended estimator (empty if `OTHER`) |
| `r(had_case)` | HAD sub-case; empty unless the design is HAD |
| `r(had_why)` | Why the quasi-stayer test could not run; set only when `had_case` is `"undetermined"` |
| `r(sfsd_case)` | SFSD sub-case; empty unless the design is SFSD |

### Scalars â the `strict` option

| Return | Meaning |
|---|---|
| `r(strict)` | 1 if `, strict` was used |

### Sample sizes

| Return | Meaning |
|---|---|
| `r(n_groups)` | The sample actually classified |
| `r(n_switchers)` | Groups that change treatment at some point |
| `r(n_never_treated)` | Groups that never change treatment and are still usable at the earliest switch |
| `r(n_truncated_controls)` | Controls that stop being observed before the panel ends (default mode only) |

### Condition flags (all 0/1)

The inputs to the decision; each answers one yes/no question.

| Return | 1 means |
|---|---|
| `r(any_switchers)` | At least one group changes treatment |
| `r(same_Fg)` | All switchers switch at the **same** period |
| `r(is_binary)` | `D` takes only two distinct values — *any* two |
| `r(is_binary01)` | Those two values are exactly 0 and 1 |
| `r(is_absorbing)` | Once switched, `D` never changes again |
| `r(zero_baseline)` | Every group has baseline treatment 0 |
| `r(common_baseline)` | Every group has the *same* baseline (not necessarily 0) |
| `r(heterog_dose)` | The size of the first treatment change varies across switchers |
| `r(sfsd_pair)` | Two groups share a baseline and first switch at different dates |

`is_binary` / `is_binary01` and `common_baseline` / `zero_baseline` are loose/strict
pairs. Only the strict member drives a branch; the loose one exists so that a `{4,9}`
coding is *visible* rather than silently handled.

### HAD sub-case

| Return | Meaning |
|---|---|
| `r(n_stayers)` | Groups still at `D = 0` at the switch date |
| `r(had_d_min)` | Lowest positive dose at the switch |
| `r(had_tie)` | 1 if two or more switchers share that lowest dose |
| `r(n_at_d_min)` | Groups at the lowest dose |
| `r(n_above_d_min)` | Groups with a dose above the lowest positive dose |
| `r(qs_stat)` | `did_had`'s QS statistic; missing unless it ran |
| `r(qs_pval)` | Its p-value; missing unless it ran |
| `r(qs_n)` | Its N; missing unless it ran |
| `r(qs_reject)` | 1 if quasi-stayers are rejected at 5% |

### SFSD sub-case

| Return | Meaning |
|---|---|
| `r(n_baseline_cells)` | Distinct baseline values |
| `r(n_sfsd_cells)` | How many of those contain an SFSD pair |

### Switch dates

| Return | Units |
|---|---|
| `r(common_switch_t)` | normalized — **only meaningful when `r(same_Fg) == 1`** |
| `r(common_switch_cal)` | calendar |
| `r(first_switch_cal)` | Earliest first switch, calendar |
| `r(last_switch_cal)` | Latest first switch, calendar |

### Sample adjustments

Each is a count of groups affected. `.` means "not assessed in this mode", not zero.

| Return | Mode | Meaning |
|---|---|---|
| `r(n_dropped_baseline)` | `strict` | Dropped for missing `D` at the first period |
| `r(n_dropped_pretreat)` | `strict` | Dropped for a pre-treatment violation |
| `r(n_dropped_alld)` | default | Dropped because `D` is never observed |
| `r(n_late_entry)` | default | Baseline taken at a later entry date |
| `r(n_missing_at_start)` | default | Observed via `Y` before `D` is first observed |
| `r(n_filled_pre_gap)` | default | Pre-switch gap read as baseline |
| `r(n_demoted)` | default | Demoted to a control — **the one that can change the design** |
| `r(n_exit_controls)` | default | Never-switchers whose `D` stops being observed early |
| `r(n_post_gap_switchers)` | both | Switchers with `D` missing after their switch |

---

## Using the returns across many datasets

```stata
foreach f in paper1 paper2 paper3 {
    use "`f'.dta", clear
    quietly whichdidshouldiuse y g year d
    di "`f': " r(design) "  (estimator: " r(estimator) ")"
}
```

`quietly` suppresses the report *and* the dropped-group warnings, so the loop prints one
line per dataset. Every `r()` return is set regardless. There is no middle setting that
keeps the warnings but hides the report.

---

## Worked examples

[`Stata/examples.do`](Stata/examples.do) runs the command across every
design and sub-case. **It is repo-only** — it is not part of the installed package, so
clone or download this repository to use it. Run it from `Stata/`, since it loads its
panels via `../data/`; it writes `examples.log` beside itself.

| Section | Panel | Result |
|---|---|---|
| 1a | Moser–Voena | `CLA` |
| 1b | Wolfers | `SAD` |
| 1c | Gentzkow et al. | `SFSD`, shared baseline |
| 1d | Pierce–Schott | `HAD`, quasi-stayers |
| 2 | Gentzkow, discrete vs. continuous treatment | `SFSD`, both sub-cases |
| 3 | Synthetic | `HAD`, all four sub-cases |
| 4 | Synthetic | `OTHER` |

Each block is labelled with the design it is expected to return, so a regression shows up
as a mismatch when reading the log.

Pierce–Schott ships **wide** and is reshaped inside the do-file, following the textbook's
prep. Sections 3 and 4 build their panels inline, so they need no data files at all.

### Where the data lives

Two copies of the four textbook panels are in this repository, and they are not
interchangeable:

| Location | Contents | Ships to users? |
|---|---|---|
| [`Stata/`](Stata/) | The four textbook panels, trimmed to the variables the examples use | **Yes** — declared as ancillary files in `whichdidshouldiuse.pkg`, retrieved with `net get` |
| [`data/`](data/) | The same four panels at full size, plus `had_data1.dta` and `had_data2.dta` (the two HAD panels from the `did_had` repository, used by section 3) | No — repo-only |

`examples.do` reads from `data/` because it needs `had_data1`/`had_data2`, which are not
part of the package. The trimmed copies in `Stata/` are what `net get` delivers, and they
reproduce the same classification for every example in the help file.

---

## References

The design definitions and estimator recommendations follow:

> de Chaisemartin, C. and D'Haultfoeuille, X. (2026). *Causal Inference with
> Differences-in-Differences: Credible Answers to Hard Questions.* Princeton University
> Press.

The four example panels:

> Moser, P. and Voena, A. (2012). [Replication data for "Compulsory Licensing: Evidence
> from the Trading with the Enemy Act"](https://doi.org/10.3886/E112497V1). Nashville, TN:
> American Economic Association. Ann Arbor, MI: Inter-university Consortium for Political
> and Social Research.

> Wolfers, J. (2006). [Replication data for "Did Unilateral Divorce Laws Raise Divorce
> Rates? A Reconciliation and New Results"](https://doi.org/10.3886/E116250V1). Nashville,
> TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for
> Political and Social Research.

> Gentzkow, M., Shapiro, J. M. and Sinkinson, M. (2011). [Replication data for "The Effect
> of Newspaper Entry and Exit on Electoral Politics"](https://doi.org/10.3886/E112472V1).
> Nashville, TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium
> for Political and Social Research.

> Pierce, J. R. and Schott, P. K. (2016). [Replication data for "The Surprisingly Swift
> Decline of US Manufacturing Employment"](https://doi.org/10.3886/E112965V1). Nashville,
> TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for
> Political and Social Research.

---

## Authors

- Alberto Trelles, Sciences Po, France.
- Clément de Chaisemartin, Economics Department, Sciences Po, France.
- Anzony Quispe, Brown University, USA.

---

## License

MIT — see [LICENSE](LICENSE).
