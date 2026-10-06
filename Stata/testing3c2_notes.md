# Building a HAD panel that reaches `had_case = "none"` via QS rejection

Goal: a synthetic panel where the design is HAD, there is no mass point
(`had_tie = 0`), and `did_had`'s quasi-stayer test actually runs **and rejects**,
so `had_case = "none"` is reached through the test rather than through the
tie short-circuit.

Target state:

| Scalar | Needed | Why |
|---|---|---|
| `design` | `HAD` | else 7b never runs |
| `n_stayers` | `0` | else the cascade stops at `"stayers"` |
| `had_tie` | `0` | else `"none"` via the mass-point short-circuit (that is case 3c-i) |
| `qs_pval` | `< 0.05` | else `"quasi-stayers"`; missing gives `"undetermined"` |

`QS = D(1) / (D(2) - D(1))` over the positive doses at the switch, rejecting
when `QS > 19` (equivalently `p = 1/(1+QS) < 0.05`).

---

## Attempts before this file (in conversation, 6-group panels)

### Attempt 0a — 6 groups, 4 periods, switch at the last period

Doses `{10, 10.5, 12, 15, 18, 22}`, switch at `t = 2004` with nothing after it.

**Result:** `had_case = "undetermined"`, `did_had` exited with **r(3301)**
(Mata subscript invalid).

**Diagnosis offered at the time:** no post-switch period, so `effects(1)` has
nothing to estimate. **This was wrong** — see 0b.

### Attempt 0b — same doses, 5 periods, switch at `t = 2003`

Added two post-switch periods so `effects(1)` had somewhere to land.

**Result:** identical. Still r(3301), still `"undetermined"`.

So the post-period theory was disproved. A direct `did_had` call on the same
panel also gave r(3301), which located the failure inside `did_had` rather than
in how `whichDIDshouldIuse` hands off to it.

### Reading `did_had.ado`

Found the failing line (`did_had.ado:507-508`):

```stata
mata: D_2_np = sort(select(D_2, D_2 :> 0), 1)
mata: T = D_2_np[1,1]/(D_2_np[2,1] - D_2_np[1,1])
```

`D_2_np[2,1]` needs at least two positive doses in whatever the inner routine
`did_had_est` receives. Reading forward from the source did **not** resolve why
6 distinct positive doses were not enough — three separate hypotheses
(post-periods, `treatment_XX` being overwritten, the `effect_1` row filter) all
failed to explain it.

### What actually resolved it: looking at the working dataset

`had_data1.dta` is the shipped example that *does* produce a QS test:

```
groups:   1000
periods:  10
doses:    continuous on [0, 1), mean 0.49, sd 0.29 at the switch
switch:   t = 6, common to all groups
```

**1000 groups, not 6.** `did_had` is nonparametric — it calls `lprobust` to fit
a local polynomial in the dose. Six points cannot support that fit, and the
failure surfaces downstream as the Mata subscript error. No rearrangement of a
6-group panel would ever have worked.

---

## Attempt 1 — 1000 groups, doses `U(10, 11)` — **SUCCEEDED**

Copy `had_data1`'s shape exactly (1000 groups, 10 periods, common switch at
`t = 6`) and move only the dose support away from zero.

```stata
set obs 1000
gen g = _n
gen double dose = 10 + runiform()
expand 10
bys g: gen t = _n
gen double d = cond(t >= 6, dose, 0)
```

Reasoning: with 1000 draws on an interval of width 1, consecutive order
statistics are about 0.001 apart while `D(1) ≈ 10`, so
`QS ≈ 10/0.001 = 10000`, far past 19.

**Result — all targets met:**

```
r(design)    = HAD
r(had_case)  = none
r(had_tie)   = 0          (no mass point: n_at_d_min = 1)
r(n_stayers) = 0
r(qs_stat)   = 40175.525
r(qs_pval)   = .00002489
had_d_min    = 10.00005
```

The report prints the QS line and the BOUND-HET warning, which is the branch
this case exists to exercise.

**Residual nit:** `QS = 4.0e+04` in the report — the format is `%6.3f`, which
falls back to scientific notation at that magnitude. Not a bug, but it reads
poorly, and it motivated attempt 2.

---

## Attempt 2 — marginal rejection, `QS ≈ 20` — **SUCCEEDED**

A QS of 40,000 is overwhelming rather than illustrative. Better to show the test
deciding near the threshold.

Rather than fight the order statistics of a random draw, pin the two smallest
doses by hand and scatter the rest well above them:

```stata
gen double dose = 5 + 5*runiform()
replace dose = 2.00 if g == 1
replace dose = 2.10 if g == 2
```

`QS = 2.00 / (2.10 - 2.00) = 20`, `p = 1/21 ≈ 0.048`.

**Result:**

```
QS = 20.000, p = 0.048  (N = 1000, reject at 5% if QS > 19)
r(design)   = HAD
r(had_case) = none
r(had_tie)  = 0
had_d_min   = 2
n_at_d_min  = 1
```

Exactly the predicted value, and a rejection that is visibly a decision rather
than a landslide. **This is the version to use as the 3c-ii example.**

---

## What made the difference

Two things, in order of importance:

1. **Panel size.** `did_had` needs enough groups for `lprobust` to fit. 6 fails
   with r(3301); 1000 works. The shipped `had_data1` has 1000, and copying that
   shape was what unblocked this. Anything much smaller should be assumed
   suspect until tested.
2. **Dose placement.** Rejection needs the two smallest positive doses close
   together *relative to the smallest*. Pinning them by hand gives an exact,
   reproducible QS instead of whatever the draw happens to produce.

Both attempts avoided the two traps that would have sent the cascade elsewhere:
no never-switchers (`n_stayers = 0`, else `"stayers"`), and no duplicate lowest
dose (`had_tie = 0`, else the mass-point branch).

## Note on running this file

`-e do testing3c2.do` opens `testing3c2.log` itself, so the do-file must **not**
contain its own `log using testing3c2` — that collides and fails with r(608).
The first run of this file hit exactly that.
