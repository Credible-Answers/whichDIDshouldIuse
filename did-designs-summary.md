# Difference-in-Differences Designs: CLA, SAD, HAD, SFSD, SSD

A summary of five nested treatment-assignment designs used in the heterogeneity-robust DiD literature (de Chaisemartin & D'Haultfœuille framework), ordered from most to least restrictive.

---

## 1. CLA — Classical DID Design

**Setup:** Binary, absorbing treatment; **no variation in treatment timing**.

$$D_{g,t} = \mathbf{1}\{t > T_0\} D_g, \quad T_0 \geq 1,\ D_g \in \{0,1\}$$

with $\min_g D_g = 0$ and $\max_g D_g = 1$.

- $D_g = 1$: treatment group; $D_g = 0$: control group.
- All treatment groups switch on at the **same** date, $T_0+1$, and stay treated forever after.
- Control groups never switch.
- Requires at least one pre-period ($T_0 \geq 1$) and at least one treatment and one control group.
- Fully verifiable from observed data (unlike assumptions on potential outcomes).

**Key feature:** a single treatment date shared by every treated unit — the textbook two-group, two-period (or multi-period) setup.

---

## 2. SAD — Staggered Adoption Design

**Setup:** Still binary and absorbing, but treatment timing now **varies across groups**.

$$D_{g,t} = \mathbf{1}\{t \geq F_g\}$$

- $F_g$ = first period group $g$ becomes treated; treatment is absorbing (stays on afterward).
- If $g$ is never treated, set $F_g = T+1$.
- $F_g$ can equal 1 (always-treated group).
- Condition: $\min_{g: F_g>1} F_g < \max_{g: F_g \leq T} F_g$ — i.e., not all "switching" groups turn on at the same date (otherwise it collapses back to CLA).

**Key feature:** generalizes CLA by allowing different adoption dates.

---

## 3. HAD — Heterogeneous Adoption Design (general $T > 2$ case)

**Setup:** Treatment is no longer binary — it can be a **continuous/multi-valued dose** — and the design now spans any number of periods $T > 2$, not just two.

Two conditions define it:
1. **Common start, common baseline:** every group is untreated up through some period $T_0 \geq 1$, and every group that ever receives a positive dose first does so at the *same* date, $T_0+1$:
$$D_{g,t} = 0 \quad \text{for all } g,\ t \leq T_0.$$
2. **Heterogeneous dose at the switch date:** at $t = T_0+1$, doses are non-negative, with some units treated and heterogeneity among them:
$$D_{T_0+1} \geq 0, \quad \mathbb{E}_u(D_{T_0+1}) > 0, \quad \text{Var}_u(D_{T_0+1} \mid D_{T_0+1} > 0) > 0.$$

**No absorption requirement:** unlike CLA/SAD, treatment need not stay in place after $T_0+1$. For $t > T_0+1$, $D_{g,t}$ is unrestricted — a group's dose can rise, fall, or return all the way to baseline (0). In other words, "treated" only describes what happens strictly after the baseline periods; it does not need to persist.

### HAD-SQS (HAD with Stayers or Quasi-Stayers)
Adds the requirement that the support of $D_{T_0+1}$ includes 0, which covers two cases:
1. **Stayers:** a strictly positive share of groups have $D_{T_0+1} = 0$ (their treatment doesn't change at the switch date — they "stay" untreated).
2. **Quasi-stayers:** no group has exactly $D_{T_0+1} = 0$, but there are groups with dose arbitrarily close to zero (e.g., $D_{T_0+1}$ has a continuous density that is strictly positive at 0).

**Key feature:** introduces continuous/variable treatment intensity at a single common adoption date, plus the stayer/quasi-stayer concept used to construct clean comparisons — and, in its general form, drops the absorbing-treatment assumption entirely, so post-adoption dynamics (including reversion to untreated) are allowed.

---

## 4. SFSD — Staggered First Switch Design

**Setup:** Very general — allows **non-absorbing** treatment (multiple switches) and heterogeneous starting doses.

Define $F_g = \min\{t \geq 2 : D_{g,t} \neq D_{g,t-1}\}$ — the date of a group's **first** treatment switch (with $F_g = T+1$ if it never switches). In a staggered adoption design with everyone untreated at $t=1$, this reduces to the usual "first treatment date."

**Condition:** there exist $g \neq g'$ such that:
- (i) $D_{g,1} = D_{g',1}$ (same period-1 treatment), and
- (ii) $F_g \neq F_{g'}$ (they first switch at different dates).

- Condition (i) is not essential — later relaxed to designs where period-1 treatment is continuously distributed (so no two units share the same value).
- Condition (ii) is essential: it requires heterogeneity in *when* groups first switch.

**Key feature:** nests CLA, SAD, and HAD-SQS as special cases, while also allowing non-absorbing treatments and heterogeneous initial doses — the broadest design in this list.

---

## 5. SSD — Switchers and Stayers Design

**Setup:** Defined **locally**, around a single pair of consecutive periods, rather than over the whole panel.

**Condition:** there exists a period $t \geq 2$ and groups $g \neq g'$ such that:
- (i) $D_{g,t-1} = D_{g',t-1}$ (same treatment at $t-1$),
- (ii) $D_{g,t} \neq D_{g,t-1}$ ($g$ is a **switcher** between $t-1$ and $t$),
- (iii) $D_{g',t} = D_{g',t-1}$ ($g'$ is a **stayer** between $t-1$ and $t$).

Terminology: $g$ is a $(t-1)$-to-$t$ **switcher**; $g'$ is a $(t-1)$-to-$t$ **stayer**.

**Relation to SFSD:**
- When $T = 2$, SSD and SFSD coincide.
- When $T > 2$, SSD is **less restrictive** than SFSD: SFSD implies SSD, but not vice versa.
- Intuition: SFSD requires matching a switcher to a *not-yet-switched* unit with the **same full treatment history** up to the switch date. SSD only requires matching on treatment at $t-1$, ignoring prior history — valid because, absent dynamic effects, outcomes at $t-1$ and $t$ don't depend on treatment at earlier periods.

**Key feature:** the design underlying comparisons made **period-pair by period-pair**, which avoids "forbidden comparisons" (using already-treated, non-switching units as controls in a way that creates negative weights under TWFE) and underlies the $DID_+$ / $DID_-$ building blocks of the de Chaisemartin–D'Haultfœuille estimator.

---

## Nesting Summary

```
CLA  ⊂  SAD  ⊂  HAD-SQS  ⊂  SFSD
                              ⊂  SSD   (equal to SFSD only when T = 2)
```

Each design relaxes a restriction of the previous one:
- **CLA → SAD:** allows different adoption dates.
- **SAD → HAD-SQS:** keeps a common adoption date but allows continuous/variable dose intensity (plus non-treated stayers), and drops the absorbing-treatment requirement so doses can move freely — including back down to baseline — after adoption.
- **HAD-SQS → SFSD:** allows non-absorbing treatment (multiple switches) and heterogeneous initial treatment levels.
- **SFSD → SSD:** relaxes the matching requirement from "same full treatment history" to "same treatment in the immediately preceding period," making it applicable pair-of-periods by pair-of-periods.
