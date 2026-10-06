clear all
set more off

cap log close
log using tutorial_1006.log, replace text


// --------------------------------------------------------------------------- //
// -- (1) Examples from DID Book 											-- //
// --------------------------------------------------------------------------- //


*--- 1a) Moser-Voena - CLA ---*
*-----------------------------*

use "../data/moser_voena_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse    patents  subclass  year   twea
whichDIDshouldIuse    patents  subclass  year   twea, detail	//detail option 


*--- 1b) Wolfers - SAD ---*
*-------------------------*

use "../data/wolfers2006_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse div_rate state year udl, detail


*--- 1c) Gentzkow et. al - SFSD ---*
*----------------------------------*


use "../data/gentzkowetal_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse prestout cnty90 year numdailies, detail


*--- 1d) Pierce and Schott - HAD(QS) ---*
*---------------------------------------*

use "../data/pierce_schott_didtextbook.dta", clear

gen lemp2001 = lemp2000 + delta2001
gen lemp2002 = lemp2000 + delta2002
gen lemp2004 = lemp2000 + delta2004
gen lemp2005 = lemp2000 + delta2005

reshape long lemp, i(indusid) j(year)
replace ntrgap = 0 if year <= 2000

* whichDIDshouldIuse  Y     G        T     D
whichDIDshouldIuse    lemp  indusid  year  ntrgap, detail



// --------------------------------------------------------------------------- //
// -- (2) SFSD: discrete vs. continuous treatment			  				-- //
// --------------------------------------------------------------------------- //


*--- 2a) Gentzkow et. al - SFSD ---*
*----------------------------------*

use "../data/gentzkowetal_didtextbook.dta", clear

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse prestout cnty90 year numdailies, detail

*--- 2c) Gentzkow contiuous ---*
*------------------------------*

use "../data/gentzkowetal_didtextbook.dta", clear

*Adding a continuous variable (defined at the group level) to each group's treatment 
set seed 90210
bys cnty90: gen byte first_g = (_n == 1)	
gen double u = runiform() if first_g
bys cnty90: egen double u_g = max(u)
gen double numdailies_cont = numdailies + u_g	//+ u ~ U(0,1)

* whichDIDshouldIuse  Y        G         T      D
whichDIDshouldIuse prestout cnty90 year numdailies_cont, detail


// --------------------------------------------------------------------------- //
// -- (3) HAD subcases 										  				-- //
// --------------------------------------------------------------------------- //


*--- 3a) Stayers ---*
*-------------------* 

use "../data/had_data2.dta", clear	//datasets 1 and 2 from did_had github repository 

* whichDIDshouldIuse  Y   G   T   D
whichDIDshouldIuse 	  y   g   t   d, detail


*--- 3b) Quasi-stayers ---*
*-------------------------*

use "../data/had_data1.dta", clear

* whichDIDshouldIuse  Y   G   T   D
whichDIDshouldIuse 	  y   g   t   d, detail


*--- 3c) No stayers or QS ---*
*----------------------------*

*I. Mass point 
clear
input g year y d
1 2001 10 0
1 2002 11 0
1 2003 12 0
1 2004 13 2
2 2001 20 0
2 2002 21 0
2 2003 22 0
2 2004 25 2
3 2001 30 0
3 2002 31 0
3 2003 32 0
3 2004 34 2
4 2001 40 0
4 2002 41 0
4 2003 42 0
4 2004 48 5
5 2001 50 0
5 2002 51 0
5 2003 52 0
5 2004 57 5
6 2001 60 0
6 2002 61 0
6 2003 62 0
6 2004 70 9
end

* whichDIDshouldIuse  Y   G   T   D
whichDIDshouldIuse    y   g   year d, detail

*II. QS null rejected 
clear
set seed 42
set obs 1000
gen g = _n
gen double dose = 5 + 5*runiform()
replace dose = 2.00 if g == 1		//pin the two lowest doses so QS = 2/(2.1-2) = 20
replace dose = 2.10 if g == 2
expand 10
bys g: gen t = _n
gen double d = cond(t >= 6, dose, 0)	//common switch at t = 6
gen double y = g/100 + t + rnormal()

* whichDIDshouldIuse  Y   G   T   D
whichDIDshouldIuse 	  y   g   t   d, detail


*--- 3d) Undetermined ---*
*------------------------*

clear
input g t y d
1 1 10 0
1 2 11 0
1 3 12 2
1 4 13 2
2 1 20 0
2 2 21 0
2 3 22 5
2 4 23 5
3 1 30 0
3 2 31 0
3 3 32 9
3 4 33 9
end

* whichDIDshouldIuse  Y   G   T   D
whichDIDshouldIuse 	  y   g   t   d, detail

*Remark: These are cases where the did_had returns an error or cannot run. Some possible cases are the following:
*   (i)   the panel is too small for did_had's nonparametric step. It calls lprobust 
*         to fit a local polynomial in the dose, and with few groups the fit has too 
*         few points, so QS = D(1)/(D(2)-D(1)) subscripts a vector with fewer than two 
*         positive doses -> r(3301). That is this example: 3 groups.
*   (ii)  did_had, lprobust or gtools is not installed
*   (iii) Stata is older than version 16, since did_had calls preserve and must run in
*         a separate frame
*   (iv)  did_had exits without leaving e(estimates), which it does silently on some
*         failures (rc = 0)
*
*In every case the design is still HAD: only the sub-case is unknown. r(had_why) says 
*which of the above happened, and the package never errors out.






