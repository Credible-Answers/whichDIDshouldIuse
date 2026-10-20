{smcl}
{* *! version 1  2026-10-19}{...}
{viewerjumpto "Syntax" "whichdidshouldiuse##syntax"}{...}
{viewerjumpto "Description" "whichdidshouldiuse##description"}{...}
{viewerjumpto "The designs" "whichdidshouldiuse##designs"}{...}
{viewerjumpto "Further detail" "whichdidshouldiuse##detail"}{...}
{viewerjumpto "Options" "whichdidshouldiuse##options"}{...}
{viewerjumpto "Example" "whichdidshouldiuse##Example"}{...}
{viewerjumpto "FAQ" "whichdidshouldiuse##FAQ"}{...}
{viewerjumpto "Saved results" "whichdidshouldiuse##saved_results"}{...}

{title:Title}

{p 4 8}
{cmd:whichdidshouldiuse} {hline 2} Classify a panel's difference-in-differences design
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 8}
{cmd:whichdidshouldiuse Y G T D}
{ifin}
[{cmd:,}
{cmd:detail}
{cmd:strict}]
{p_end}

{synoptset 28 tabbed}{...}


{marker description}{...}
{title:Description}

{p 4 8}
{cmd:whichdidshouldiuse} reads a panel and classifies its difference-in-differences
{it:design} as {cmd:CLA}, {cmd:SAD}, {cmd:HAD}, {cmd:SFSD} or {cmd:OTHER}, names a
suitable estimator, and points you at the relevant chapter of Clement de Chaisemartin
and Xavier D'Haultfoeuille's difference-in-differences textbook.
{p_end}

{p 4 8}
It classifies; it does {bf:not} estimate. There are no fixed effects, weights or
standard-error options, because nothing is being fitted.
{p_end}

{p 4 8}
The four variables are positional and required, in that order. You pass your own
variable names; no pre-renaming is needed. The command runs inside
{helpb preserve}/{cmd:restore}, so your data in memory is unchanged when it finishes.
{p_end}

{p 8 8}
{cmd:Y} is the outcome variable.
{p_end}
{p 8 8}
{cmd:G} is the group identifier.
{p_end}
{p 8 8}
{cmd:T} is {bf:calendar} time (year, quarter, ...).
{p_end}
{p 8 8}
{cmd:D} is the treatment variable.
{p_end}

{marker designs}{...}
{title:The designs}

{synoptset 10 tabbed}{...}
{synopthdr:design}
{synoptline}
{synopt:{cmd:CLA}}Treatment is binary 0/1, absorbing, treated groups all become treated on the same date,
never-treated controls exist, everyone starts untreated. Estimator: static /
event-study TWFE. Chapter 3.{p_end}
{synopt:{cmd:SAD}}As CLA, but treatment dates {bf:vary} across treated groups. Estimator:
{cmd:csdid}, {cmd:did_multiplegt_dyn} or {cmd:did2s}. Chapter 6.{p_end}
{synopt:{cmd:HAD}}Everyone starts untreated, treated groups all become treated on the {bf:same} date, but
the treatment {bf:dose} varies across treated groups. Estimator depends on the sub-case below. Chapter 7.{p_end}
{synopt:{cmd:SFSD}}Groups experience their first treatment change at
{bf:different} dates. Allows non-absorbing treatments, non-binary treatments, and heterogeneous baseline
doses. Estimator: {cmd:did_multiplegt_dyn}. Chapter 8.{p_end}
{synopt:{cmd:OTHER}}None of the above. Section 8.5.2.{p_end}
{synoptline}
{p2colreset}{...}

{p 4 8}
The designs {bf:nest}: CLA is a special case of SAD, which is a special case of HAD
with quasi-stayers, which is a special case of SFSD. They are checked
most-restrictive-first, so the design you are shown is the tightest one that holds.
{p_end}

{dlgtab:HAD sub-cases}

{p 4 8}
When the design is HAD, {cmd:r(had_case)} says which control group exists at the
common treatment date. This decides what is identified and which estimator applies.
{p_end}

{synoptset 16 tabbed}{...}
{synopthdr:r(had_case)}
{synoptline}
{synopt:{cmd:stayers}}Some groups keep {it:D} = 0 at the treatment date: they stay untreated. ATT and WATT are
identified, estimable at the usual sqrt(G) rate. Estimator: {cmd:ivregress 2sls} or
{cmd:did_multiplegt_stat}.{p_end}
{synopt:{cmd:quasi-stayers}}No stayers, but {cmd:did_had}'s test does not reject that
some doses are close to 0. WATT is identified using quasi-stayers as controls;
estimated nonparametrically with bias-corrected CIs. Estimator:
{cmd:did_had}.{p_end}
{synopt:{cmd:none}}No stayers and no quasi-stayers. Only the {bf:sign} of the WATT is
identified, and only under an assumption on treatment-effect heterogeneity.
Estimator: {cmd:did_had}.{p_end}
{synopt:{cmd:undetermined}}{cmd:did_had} could not be run; {cmd:r(had_why)} says why.
The design is still HAD {c -} only the sub-case is unknown.{p_end}
{synoptline}
{p2colreset}{...}

{p 4 8}
The quasi-stayer test is {cmd:did_had}'s own, read from {cmd:e(estimates)}. Reaching
this sub-case {bf:requires Stata 16 or later}: {cmd:did_had} calls {helpb preserve},
which cannot nest inside the one {cmd:whichdidshouldiuse} already holds, so it is run
inside a {help frames:frame}, and frames arrived in Stata 16. Any other failure yields
{cmd:undetermined} too, rather than an error.
{p_end}

{dlgtab:SFSD sub-cases}

{synoptset 24 tabbed}{...}
{synopthdr:r(sfsd_case)}
{synoptline}
{synopt:{cmd:shared-baseline}}A pair of groups share the same treatment at period one 
and first switch treatment at different dates. Estimator:
{cmd:did_multiplegt_dyn}.{p_end}
{synopt:{cmd:continuous-baseline}}No two groups share the same period-one treatment {c -} the signature
of a continuously distributed baseline treatment. This is the textbook's section
8.3.5.1 extension; estimate with {cmd:did_multiplegt_dyn}'s {cmd:continuous()}
option.{p_end}
{synoptline}
{p2colreset}{...}

{marker options}{...}
{title:Options}

{p 4 8}
{cmd:detail} additionally prints the input echo, the panel summary, the
missing-treatment breakdown and the full {cmd:DIAGNOSTICS} block. It may be
abbreviated {cmd:det}. The option controls {bf:display only}: every {cmd:r()} return
listed under {help whichdidshouldiuse##saved_results:Saved results} is set whether or
not it is specified.
{p_end}

{p 4 8}
{cmd:strict} drops groups with missing treatment instead of applying the default
repairs. It may be abbreviated {cmd:str}. See
{help whichdidshouldiuse##detail:Further detail} for what the two modes do and why
running both is a useful check.
{p_end}

{p 4 8}
{cmd:if} and {cmd:in} are not options but sample qualifiers, and they do more here than
remove rows: because they are applied before the panel is balanced, a restriction on
time can change the reported design.
{p_end}


{marker Example}{...}
{title:Example}{cmd:: classifying the Moser and Voena (2012) panel}

{p 4 4}
The data for this example can be downloaded by running:
{p_end}

{phang2}{stata ssc install whichdidshouldiuse, replace}{p_end}
{phang2}{stata net get whichdidshouldiuse}{p_end}
{phang2}{stata use moser_voena_didtextbook.dta, clear}{p_end}

{p 4 4}
Classifying the panel, where {cmd:patents} is the outcome, {cmd:subclass} the group,
{cmd:year} the time period and {cmd:twea} the treatment:
{p_end}

{phang2}{stata whichdidshouldiuse patents subclass year twea}{p_end}

{p 4 4}
The panel is reported as a classical DID design: the treatment is binary and
absorbing, all 336 treated subclasses are first treated in 1919, and 6,912 subclasses
are never treated.
{p_end}

{p 4 4}
Printing the input echo, the panel summary, the missing-treatment breakdown and the
full diagnostics block:
{p_end}

{phang2}{stata whichdidshouldiuse patents subclass year twea, detail}{p_end}

{p 4 4}
For more examples, the repository contains an {cmd:examples.do} that runs the command across every
design and sub-case:
{browse "https://github.com/Credible-Answers/whichDIDshouldIuse"}.
{p_end}


{dlgtab:Non-classical designs}

{p 4 4}
The Moser and Voena panel above is a classical design. The three panels below are the
worked examples for the other designs, one each. All three ship with the package, so the
{cmd:net get} above has already downloaded them.
{p_end}

{p 4 8}
{bf:Staggered adoption (SAD)} - the divorce panel of Wolfers (2006), where
{cmd:div_rate} is the outcome, {cmd:state} the group, {cmd:year} the time period and
{cmd:udl} the treatment:
{p_end}

{phang2}{stata use wolfers2006_didtextbook.dta, clear}{p_end}
{phang2}{stata whichdidshouldiuse div_rate state year udl}{p_end}

{p 4 4}
The treatment is still binary and absorbing, as in the classical case, but the 29
treated states do not adopt at the same time: treatment occurs between 1969 and 1985. That
variation in timing is what separates SAD from CLA.
{p_end}

{p 4 8}
{bf:Heterogeneous adoption (HAD)} - the employment panel of Pierce and Schott. It ships
wide, so the outcome is assembled and the panel reshaped before the command runs:
{p_end}

{phang2}{stata use pierce_schott_didtextbook.dta, clear}{p_end}
{phang2}{stata gen lemp2001 = lemp2000 + delta2001}{p_end}
{phang2}{stata gen lemp2002 = lemp2000 + delta2002}{p_end}
{phang2}{stata gen lemp2004 = lemp2000 + delta2004}{p_end}
{phang2}{stata gen lemp2005 = lemp2000 + delta2005}{p_end}
{phang2}{stata reshape long lemp, i(indusid) j(year)}{p_end}
{phang2}{stata replace ntrgap = 0 if year <= 2000}{p_end}
{phang2}{stata whichdidshouldiuse lemp indusid year ntrgap}{p_end}

{p 4 4}
Here every group is untreated at the baseline period 2000 and all 103 groups (industries) become treated in
2001, so there is no variation in timing {c -} what varies is the treatment dose.
This is also the example where {cmd:r(had_case)} carries real information: no group stays
untreated, but {cmd:did_had}'s test does not reject the null that some doses are close to
zero (p-value 0.140), so the sub-case is {cmd:quasi-stayers} and those near-zero-dose
groups serve as the controls. See {help whichdidshouldiuse##designs:HAD sub-cases}.
{p_end}

{p 4 8}
{bf:Staggered first switch (SFSD)} - the newspaper panel of Gentzkow et al., where
{cmd:prestout} is the outcome, {cmd:cnty90} the group, {cmd:year} the time period and
{cmd:numdailies} the treatment:
{p_end}

{phang2}{stata use gentzkowetal_didtextbook.dta, clear}{p_end}
{phang2}{stata whichdidshouldiuse prestout cnty90 year numdailies}{p_end}

{p 4 4}
{cmd:numdailies} is a count of newspapers, so the treatment is neither binary nor
absorbing {c -} counties gain and lose papers repeatedly. None of the three designs above
applies, but counties experience their first change in their numbers of newspapers at different dates,
between 1872 and 1928, which is what SFSD requires.
{p_end}

{marker detail}{...}
{title:Further detail}

{p 4 8}
{cmd:Preparing your data} - four things to check before running:
{p_end}

{p 8 12}
{bf:1. Calendar time.} {cmd:T} is calendar time. Gaps are fine, because the command
normalizes time internally, so a panel missing 2003 still has a well-defined "period
before the switch".
{p_end}

{p 8 12}
{bf:2. A long panel.} One row per group-period. Wide data must be {helpb reshape}d
first.
{p_end}

{p 8 12}
{bf:3. A genuine zero.} {cmd:D} is coded so that 0 means untreated. The design
definitions need a real untreated state, and a treatment coded 4/9 is binary but has
none; {cmd:r(is_binary)} with {cmd:r(is_binary01)} = 0 tells you a rescaling is
needed.
{p_end}

{p 8 12}
{bf:4. Missing is not zero.} A missing treatment value means "unknown", not
"untreated": the command cannot rule out that treatment had already begun. Wherever
you know a group was untreated, write the zero in rather than leaving the cell blank.
This matters most in the period just before a group switches, where an unexplained
blank costs you the group entirely {c -} it is dropped, which
can change the design you are shown without any error being issued. See
{it:When demotion changes the classification} below.
{p_end}

{p 4 8}
{cmd:Missing treatment: the default rules} - Treatment missing outside a group's
baseline period could mean the group is unusable. By default the command applies a
set of repairs modeled on {cmd:did_multiplegt_dyn}: a group is kept whenever its
first switch date can still be pinned down, and every adjustment that could change
the answer is reported rather than silently applied. The
{cmd:Missing treatment} block printed by {cmd:detail} breaks the adjustments down,
and each one has its own {cmd:r()} return.
{p_end}

{p 4 8}
{cmd:Missing treatment: the strict option} - {cmd:strict} discards instead of
repairing: any group whose treatment is missing at baseline, or at any period before
its first switch, is dropped. The repairs keep groups that {cmd:strict} would
discard, which is usually what you want, but agreement between the two modes is evidence that the repairs are not driving the
classification.
{p_end}

{p 4 8}
By default the command prints the classification and nothing else. The one exception
is a "Groups dropped ..." line, which is never suppressed when nonzero: it reports
groups discarded from your sample, so a run that silently loses 400 groups must not
look like one that loses none.
{p_end}

{p 4 8}
{cmd:Missing treatment: when demotion changes the classification} - Demotion is the one default repair
that can change the answer. A group is demoted to a control when its treatment is missing in the period immediately before its first apparent switch: the switch
happened somewhere between the last period at which treatment is observed and the
apparent switch date, so the first switch date cannot be pinned down, and the group
is kept only as a control, up to the last period at which its
treatment is observed and still equal to its baseline treatment.
Suppose the design is in truth heterogeneous
adoption, with some groups taking a dose of 1 and others a dose of 2 at a common
date. If every dose-2 group has its treatment missing in the period right before that
date, every dose-2 group is demoted, the surviving switchers all share a dose of 1,
and the panel is reported as a classical DID design. No error is issued, because the
designs nest and are checked most-restrictive-first: losing the high-dose switchers
makes a {it:tighter} design hold, and the tighter design is the one reported. If
demotion removes every switcher the command reports {cmd:OTHER} rather than inventing
a design, but it will not warn you when it merely removes the switchers that
distinguished one design from another.
{p_end}

{p 4 8}
{cmd:Avoiding the problem} - Before classifying, be sure of two things for every
switcher: the exact date of its first switch, and its treatment status in the period
immediately before that date. In other words, leave no missing treatment in the period just before a group experiences for the first time a treatment different from its baseline treatment.
{p_end}

{title:References}

{p 4 8}
de Chaisemartin, C. and D'Haultfoeuille, X. (2026).
{it:Causal Inference with Differences-in-Differences: Credible Answers to Hard Questions.} Princeton University Press.
{p_end}

{p 4 8}
Moser, P. and Voena, A. (2012).
{browse "https://doi.org/10.3886/E112497V1":Replication data for "Compulsory Licensing: Evidence from the Trading with the Enemy Act"}.
Nashville, TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for Political and Social Research.
{p_end}

{p 4 8}
Wolfers, J. (2006).
{browse "https://doi.org/10.3886/E116250V1":Replication data for "Did Unilateral Divorce Laws Raise Divorce Rates? A Reconciliation and New Results"}.
Nashville, TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for Political and Social Research.
{p_end}

{p 4 8}
Gentzkow, M., Shapiro, J. M. and Sinkinson, M. (2011).
{browse "https://doi.org/10.3886/E112472V1":Replication data for "The Effect of Newspaper Entry and Exit on Electoral Politics"}.
Nashville, TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for Political and Social Research.
{p_end}

{p 4 8}
Pierce, J. R. and Schott, P. K. (2016).
{browse "https://doi.org/10.3886/E112965V1":Replication data for "The Surprisingly Swift Decline of US Manufacturing Employment"}.
Nashville, TN: American Economic Association. Ann Arbor, MI: Inter-university Consortium for Political and Social Research.
{p_end}


{title:Auxiliary packages}

{p 4 4}
The command requires that the {cmd:distinct} package be installed on the user's
machine. HAD panels without stayers additionally require {cmd:did_had},
{cmd:lprobust} (shipped inside {cmd:nprobust}) and {cmd:gtools}. You do not need to
install any of these yourself: the command installs what is missing on first use.
{p_end}


{title:Authors}

{p 4 4}
Alberto Trelles, Sciences Po, France.{break}
Clément de Chaisemartin, Economics Department, Sciences Po, France.{break}
Anzony Quispe, Brown University, USA.
{p_end}


{title:Contact}

{p 4 4}
Mail:
{browse "mailto:chaisemartin.packages@gmail.com":chaisemartin.packages@gmail.com}
{p_end}

{p 4 4}
GitHub:
{browse "https://github.com/Credible-Answers/whichDIDshouldIuse"}.
{p_end}


{marker saved_results}{...}
{title:Saved results}

{p 4 8}
{cmd:whichdidshouldiuse} is {helpb return:rclass}. Read {cmd:r()} {bf:immediately}
{c -} the next command that returns {cmd:r()} results clears it.
{p_end}

{p 4 8}
{cmd:whichdidshouldiuse} stores the following in {cmd:r()}:
{p_end}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(design)}}{cmd:"CLA"}, {cmd:"SAD"}, {cmd:"HAD"}, {cmd:"SFSD"},
{cmd:"OTHER"}{p_end}
{synopt:{cmd:r(estimator)}}recommended estimator (empty if {cmd:OTHER}){p_end}
{synopt:{cmd:r(had_case)}}HAD sub-case; empty unless the design is HAD{p_end}
{synopt:{cmd:r(had_why)}}why the quasi-stayer test could not run; set only when
{cmd:had_case} is {cmd:"undetermined"}{p_end}
{synopt:{cmd:r(sfsd_case)}}SFSD sub-case; empty unless the design is SFSD{p_end}

{p2col 5 24 28 2: Scalars {c -} strict option}{p_end}
{synopt:{cmd:r(strict)}}1 if {cmd:strict} was used{p_end}

{p2col 5 24 28 2: Scalars {c -} sample sizes}{p_end}
{synopt:{cmd:r(n_groups)}}the sample actually
classified{p_end}
{synopt:{cmd:r(n_switchers)}}groups that change treatment at some point{p_end}
{synopt:{cmd:r(n_never_treated)}}groups that never change treatment and are still
usable at the earliest switch{p_end}
{synopt:{cmd:r(n_truncated_controls)}}controls that stop being observed before the
panel ends (default mode only){p_end}

{p2col 5 24 28 2: Scalars {c -} condition flags (all 0/1)}{p_end}
{synopt:{cmd:r(any_switchers)}}at least one group changes treatment{p_end}
{synopt:{cmd:r(same_Fg)}}all switchers switch at the {bf:same} period{p_end}
{synopt:{cmd:r(is_binary)}}{it:D} takes only two distinct values {c -} {it:any}
two{p_end}
{synopt:{cmd:r(is_binary01)}}those two values are exactly 0 and 1{p_end}
{synopt:{cmd:r(is_absorbing)}}once switched, {it:D} never changes again{p_end}
{synopt:{cmd:r(zero_baseline)}}every group has baseline treatment 0{p_end}
{synopt:{cmd:r(common_baseline)}}every group has the {it:same} baseline (not
necessarily 0){p_end}
{synopt:{cmd:r(heterog_dose)}}the size of the first treatment change varies across
switchers{p_end}
{synopt:{cmd:r(sfsd_pair)}}two groups share a baseline and first switch at different
dates{p_end}

{p2col 5 24 28 2: Scalars {c -} HAD sub-case}{p_end}
{synopt:{cmd:r(n_stayers)}}groups still at {it:D} = 0 at the switch date{p_end}
{synopt:{cmd:r(had_d_min)}}lowest positive dose at the switch{p_end}
{synopt:{cmd:r(had_tie)}}1 if two or more switchers share that lowest dose{p_end}
{synopt:{cmd:r(n_at_d_min)}}groups at the lowest dose{p_end}
{synopt:{cmd:r(n_above_d_min)}}groups with a dose above the lowest positive
dose{p_end}
{synopt:{cmd:r(qs_stat)}}{cmd:did_had}'s QS statistic; missing unless it ran{p_end}
{synopt:{cmd:r(qs_pval)}}its p-value; missing unless it ran{p_end}
{synopt:{cmd:r(qs_n)}}its N; missing unless it ran{p_end}
{synopt:{cmd:r(qs_reject)}}1 if quasi-stayers are rejected at 5%{p_end}

{p2col 5 24 28 2: Scalars {c -} SFSD sub-case}{p_end}
{synopt:{cmd:r(n_baseline_cells)}}distinct baseline values{p_end}
{synopt:{cmd:r(n_sfsd_cells)}}how many of those contain an SFSD pair{p_end}

{p2col 5 24 28 2: Scalars {c -} switch dates}{p_end}
{synopt:{cmd:r(common_switch_t)}}normalized {c -} {bf:only meaningful when}
{cmd:r(same_Fg)} {bf:== 1}{p_end}
{synopt:{cmd:r(common_switch_cal)}}the same date in calendar units{p_end}
{synopt:{cmd:r(first_switch_cal)}}earliest first switch, calendar{p_end}
{synopt:{cmd:r(last_switch_cal)}}latest first switch, calendar{p_end}

{p2col 5 24 28 2: Scalars {c -} sample adjustments}{p_end}
{synopt:{cmd:r(n_dropped_baseline)}}({cmd:strict}) dropped for missing {it:D} at the
first period{p_end}
{synopt:{cmd:r(n_dropped_pretreat)}}({cmd:strict}) dropped for a pre-treatment
violation{p_end}
{synopt:{cmd:r(n_dropped_alld)}}(default) dropped because {it:D} is never
observed{p_end}
{synopt:{cmd:r(n_late_entry)}}(default) baseline taken at a later entry date{p_end}
{synopt:{cmd:r(n_missing_at_start)}}(default) observed via {it:Y} before {it:D} is
first observed{p_end}
{synopt:{cmd:r(n_filled_pre_gap)}}(default) pre-switch gap read as baseline{p_end}
{synopt:{cmd:r(n_demoted)}}(default) demoted to a control {c -} the one adjustment
that can change the design{p_end}
{synopt:{cmd:r(n_exit_controls)}}(default) never-switchers whose {it:D} stops being
observed early{p_end}
{synopt:{cmd:r(n_post_gap_switchers)}}(both) switchers with {it:D} missing after their
switch{p_end}
{synoptline}
{p2colreset}{...}

{p 4 8}
Each sample-adjustment count is a number of groups. Missing ({cmd:.}) means "not
assessed in this mode", not zero.
{p_end}


{title:Also see}

{p 4 4}
The estimators this command recommends, each of which must be installed before its
help file will open: {help csdid:csdid}, {help did_had:did_had},
{help did_multiplegt_dyn:did_multiplegt_dyn},
{help did_multiplegt_stat:did_multiplegt_stat}, {help did2s:did2s}.
{p_end}

{p 4 4}
Online: {helpb distinct}, {help frames}.
{p_end}
