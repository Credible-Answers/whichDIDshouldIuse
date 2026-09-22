# whichDIDshouldIuse

A Stata command that looks at a panel and tells you which difference-in-differences
**design** it is — and therefore which estimator applies.

You pass it four variables; it reports one of **CLA**, **SAD**, **HAD**, **SFSD**,
or **OTHER**, together with the diagnostics behind that answer.

```stata
adopath + "Stata"
use "data/moser_voena_didtextbook.dta", clear
whichDIDshouldIuse patents subclass year twea
```

```
  DESIGN: Classical DID Design (CLA)
  Binary and absorbing treatment, no variation in treatment
  timing: all 336 treated group(s) experience treatment at
  t=1919 (period 20), and 6912 group(s) never switch.
  Estimator: static / event-study TWFE
```

Design definitions follow **de Chaisemartin & D'Haultfœuille**.

---

## Repository layout

| Path | What it is |
|---|---|
| **`Stata/whichDIDshouldIuse.ado`** | The command. All classification logic lives here and nowhere else. |
| **`Stata/examples.do`** | The driver: runs `whichDIDshouldIuse` on the four panels in `data/` and prints the result of each. |
| **`data/`** | Four example panels from the textbook (Moser–Voena, Wolfers, Gentzkow et al., Pierce–Schott). |

---

## Syntax

```stata
whichDIDshouldIuse Y G T D
```

| Argument | Meaning |
|---|---|
| `Y` | Outcome |
| `G` | Group identifier |
| `T` | **Calendar** time (year, quarter, …) |
| `D` | Treatment |

All four are positional and required, in that order. You pass **your own variable
names** — no pre-renaming needed. The command runs inside `preserve`/`restore`, so
your data in memory is unchanged when it finishes.

It classifies; it does **not** estimate. There are no fixed effects, weights, or
standard-error options, because nothing is being fitted.

**Dependency:** `distinct` (SSC) — `ssc install distinct`

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
| **HAD** | One common switch date, everyone starts untreated, but the **size** of the change differs (a dose, not an on/off switch) | `did_had` |
| **SFSD** | Broadest tested. Permits **non-absorbing** treatment (switching back off) and **heterogeneous baseline** doses | `did_multiplegt_dyn` |
| **OTHER** | None of the above. The output lists, condition by condition, exactly which checks failed for each design. | — |

**SSD is not implemented yet.**

### What makes SFSD different

SFSD asks whether there exist two groups `g ≠ g'` with the **same baseline
treatment** that **first switch at different dates**. That is a *pair-existence*
test, not a variance test — timing variation **within** a shared-baseline cell:

```stata
bys d_baseline: egen sd_Fg_within = sd(Fg) if first_g
```

A panel whose baseline cells are all singletons fails SFSD no matter how much
overall timing variation it has, because no two groups share a baseline to be
compared. `r(n_baseline_cells)` and `r(n_sfsd_cells)` report how the groups
partition and how many of those cells actually carry identifying variation.

---

## What it does to your data first

Four preparation steps run before anything is classified. Each can drop groups,
and the command reports how many.

1. **Balance the panel.** `fillin G T` gives every group a row for every calendar
   period present in the data, so a gap becomes an explicit missing row.
2. **Normalize time.** `t_cal` keeps your calendar values (1918, 1919, …); a new
   `t` numbers periods `1, 2, 3, …`. All logic uses `t`; all messages use `t_cal`.
   This is what makes `Fg-1` always a real period even when calendar years have
   gaps — Pierce–Schott has no 2003, and it still works.
3. **Baseline treatment.** `d_baseline` is `D` in period 1 — *literally* period 1,
   not the first period where `D` happens to be observed. **Groups with missing
   treatment in period 1 are dropped**: every design imposes a condition on
   baseline treatment, and there is nothing to check if it was never observed.
4. **Pre-treatment integrity.** A group is dropped if `D` is missing or differs
   from `d_baseline` at any period before its first switch. Treatment is flat at
   baseline before the first switch by definition, so a violation means the switch
   date `Fg` was measured wrong. This is a consistency check on `Fg`, not an extra
   design restriction.

---

## Returned values

`whichDIDshouldIuse` is `rclass`. Read `r()` **immediately** — the next command
that returns `r()` results wipes it.

### The answer

| Return | Type | Values |
|---|---|---|
| `r(design)` | string | `"CLA"`, `"SAD"`, `"HAD"`, `"SFSD"`, `"OTHER"` |
| `r(estimator)` | string | Recommended estimator (empty if `OTHER`) |

### Sample sizes

| Return | Meaning |
|---|---|
| `r(n_groups)` | Groups surviving both filters — the sample actually classified |
| `r(n_switchers)` | Groups that change treatment at some point |
| `r(n_never_treated)` | Groups that never change treatment |

`r(n_switchers) + r(n_never_treated) = r(n_groups)`.

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

### Switch dates

| Return | Units |
|---|---|
| `r(common_switch_t)` | normalized — **only meaningful when `r(same_Fg) == 1`** |
| `r(common_switch_cal)` | calendar |
| `r(first_switch_cal)` / `r(last_switch_cal)` | calendar — the range |

---

## Running the tests

```bash
"/c/Program Files/StataNow19/StataSE-64.exe" -e do Stata/examples.do
```

`-e` runs batch and writes `examples.log`. **Stata's exit code is not reliable** —
a file that fails to run at all still exits 0, so read the log.

`examples.do` runs one block per panel, each labelled with the design it is
expected to return, so a mismatch is visible when scanning the log. Current
results:

| Dataset | Design | Why |
|---|---|---|
| Moser–Voena | **CLA** | 336 subclasses all switch in 1919; 6912 never |
| Wolfers | **SAD** | 29 states adopt unilateral divorce 1969–1985 |
| Gentzkow et al. | **SFSD** | #newspapers is a non-absorbing 0–45 count |
| Pierce–Schott | **HAD** | Common 2001 switch, continuous NTR-gap dose |

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

Note `quietly` to suppress the diagnostics. Datasets with different variable names
need a per-dataset mapping, which is why `examples.do` uses four explicit blocks
rather than a loop.

---

## Conventions worth knowing before editing

- **Named scalars, not `r()`, in the conditionals.** Every `r(mean)`/`r(min)` is
  captured into a named scalar on the line right after the command that produced
  it; the classification block reads only those names. `r()` is overwritten by the
  next command, and a bare `r(mean)` deep inside nested `if`s is unreadable.
- **`set varabbrev off`** for the whole program, restored on exit. Stata otherwise
  resolves an abbreviated name to any variable it uniquely prefixes — `drop t`
  silently deleted `t_cal` and cost a long debugging session.
- **The `keep Y G T D` is load-bearing**, not tidying: the program uses bare scalar
  names (`Tmax`, `n_groups`, …), and Stata resolves a bare name to a *variable*
  before a scalar.
- **`preserve`/`restore`** protect the caller's data, so constructed variables
  (`Fg`, `d_baseline`, `first_change`) do **not** survive the call. Comment out the
  pair to inspect them.
- **Deliberate edge cases:** `is_absorbing = 0` when there are no post-switch
  observations (not 1), and `same_Fg = 1` when there is a single switcher (one
  switcher trivially has no timing variation).
- **Never write a `/*`-containing glob inside a block comment.** Stata *nests*
  block comments, so it opens a second level and silently swallows the rest of the
  file — with no error and a zero exit code.
