clear all
set matsize 1000
global bartikFolder "$dropbox\outside\Bartik_Shock"
global raw "$bartikFolder\raw"
global derived "$bartikFolder/derived$extraDerivedParam"

local delta = 6
 
foreach baseYear in 2000 2010 {

use "$derived/InputBartik2000-2017", clear
keep if year == `baseYear'

local controls male race_white native_born educ_hs educ_coll veteran nchild
local weight pop`baseYear'

local y kfr_pooled_pooled_p25
local x emp_ch

local ind_stub init_sh_ind_
// nat_empl_ind_ will include current cz growth in national growth rates.  
// nat_empl_ind_lo_ will exclude the current cz
local growth_stub nat_empl_ind_

local time_var year

/*qui tab year, gen(year_)
drop year_1*/

levelsof `time_var', local(years)


/** Demean growth rates **/
egen mean_growth = rowmean(`growth_stub'*)
foreach growth of varlist `growth_stub'* {
	qui replace `growth' = `growth' - mean_growth
	}
drop mean_growth

/* Construct initial industry shares  and controls */
sort czone year

local ind_stub sh_ind_
local controls male race_white native_born educ_hs educ_coll veteran nchild




egen test = rowtotal(`ind_stub'*), 
foreach ind_var of varlist `ind_stub'* {
	replace `ind_var' = `ind_var' / test
	if regexm("`ind_var'", "`ind_stub'(.*)") {
		local ind_num = regexs(1)
		replace `growth_stub'`ind_num' = 0 if `growth_stub'`ind_num' == .
		gen b_`ind_num' = `ind_var' * `growth_stub'`ind_num'
		}
	}
egen z3 = rowtotal(b_*)
drop b_*


local controls male race_white native_born educ_hs educ_coll veteran nchild



drop if czone == .


 foreach var of varlist `ind_stub'* {
 
	 qui summarize `var'
	 local max = r(max)
	 if `max' == 0 {
		drop `var'
			if regexm("`var'", "`ind_stub'(.*)") {
		local ind_num = regexs(1)
		drop `growth_stub'`ind_num'
		}
		
	 }
 }

drop if czone == .
qui gen bartikInst = 0
qui gen bartikVariance = 0


foreach var of varlist `ind_stub'* {
	if regexm("`var'", "`ind_stub'(.*)") {
		local ind = regexs(1) 
		}
	qui replace bartikInst = bartikInst + `var' * `growth_stub'`ind' ///
			if `var'!= . & `growth_stub'`ind'!=.
	gen shareVariance = `var' * (1-`var') / sampleSize // This variance calculation comes from the variance of a Bernoulli distribution (empirically estimated) which
														// represents the ACS choosing a portion of the total population
	qui replace bartikVariance = bartikVariance +  shareVariance * (`growth_stub'`ind')^2 if `var'!= . & `growth_stub'`ind'!=.
						// the industry shares are by far the higher variance object compared to national
						// growth rates, so this approximation works
	drop shareVariance
}

keep czone year wage_ch emp_ch bartikInst bartikVariance educ_coll_lt4yrs educ_coll_4yrs ageDecile

local endYear = `baseYear' + `delta'
export delim "$derived/`baseYear'/BartikInst`baseYear'-`endYear'", replace
save "$derived/`baseYear'/BartikInst`baseYear'-`endYear'", replace
}
