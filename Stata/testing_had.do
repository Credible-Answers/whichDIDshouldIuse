discard
clear all

*------------------------------*
*--- Data from DID textbook ---*
*------------------------------*

use "../data/pierce_schott_didtextbook.dta", clear
gen lemp2001 = lemp2000 + delta2001
gen lemp2002 = lemp2000 + delta2002
gen lemp2004 = lemp2000 + delta2004
gen lemp2005 = lemp2000 + delta2005
reshape long lemp, i(indusid) j(year)
replace ntrgap = 0 if year <= 2000

* --- Reference: did_had on its own ---
did_had lemp indusid year ntrgap, effects(1) graph_off _no_updates
matrix ref = e(estimates)
matrix list ref

* --- Now run the package ---
whichDIDshouldIuse lemp indusid year ntrgap, detail

* --- Compare by hand ---
di "did_had QS           = " ref[1,8]
di "whichDIDshouldIuse QS = " r(qs_stat)
di "did_had p            = " ref[1,9]
di "whichDIDshouldIuse p = " r(qs_pval)

*------------------------------* 
*--- Data1 from HAD package ---*
*------------------------------* 

use "../data/had_data1.dta", clear

* --- Reference: did_had on its own ---
did_had y g t d, effects(1) graph_off _no_updates
matrix ref = e(estimates)
matrix list ref

* --- Now run the package ---
whichDIDshouldIuse y g t d

* --- Compare by hand ---
di "did_had QS           = " ref[1,8]
di "whichDIDshouldIuse QS = " r(qs_stat)
di "did_had p            = " ref[1,9]
di "whichDIDshouldIuse p = " r(qs_pval)

*------------------------------* 
*--- Data2 from HAD package ---*   STAYERS
*------------------------------* 

use "../data/had_data2.dta", clear

* --- Reference: did_had on its own ---
did_had y g t d, effects(1) graph_off _no_updates
matrix ref = e(estimates)
matrix list ref

* --- Now run the package ---
whichDIDshouldIuse y g t d, detail

* --- Compare by hand ---
di "did_had QS           = " ref[1,8]		// 17.133393
di "whichDIDshouldIuse QS = " r(qs_stat)	// missing
di "did_had p            = " ref[1,9]		// .05514688
di "whichDIDshouldIuse p = " r(qs_pval)		// missing 

*Remark: since this classifies as HAD-stayers, did_had isn't run by whichDIDshouldIuse, so QS and p are missing 















