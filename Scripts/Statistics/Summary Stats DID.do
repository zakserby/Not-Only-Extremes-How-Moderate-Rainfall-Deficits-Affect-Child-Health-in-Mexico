*******************************************************************
* Summary statistics for the 2009 drought DID
* Project: MS Thesis
*******************************************************************

clear all
set more off

*******************************************************************
* Directories
*******************************************************************
* The root folder is set once in 00_Master.do. If this file is run on its own, the root is found by going up from Stata's working folder until the folder that has Scripts/00_Master.do
if "$root" == "" {
    local r = subinstr("`c(pwd)'", "\", "/", .)
    while "`r'" != "" & !fileexists("`r'/Scripts/00_Master.do") {
        local r = substr("`r'", 1, strrpos("`r'", "/") - 1)
    }
    global root "`r'"
}
global raw_mxfls     "$root/Data/Raw/MxFLS"
global raw_who       "$root/Data/Raw/WHO_reference"
global clean_mxfls   "$root/Data/Cleaned/MxFLS"
global clean_who     "$root/Data/Cleaned/WHO_zscores"
global clean_rain    "$root/Data/Cleaned/Rainfall"
global clean_banxico "$root/Data/Cleaned/Banxico"
global out_sumstats  "$root/Output/Tables"
global out_regs      "$root/Output/Regression_Estimates" 
global out_logs      "$root/Output/Logs"
global out_figs      "$root/Output/Figures" 

* Create the folders this project writes to (capture skips quietly if a folder already exists)
foreach d in "$root/Data" "$root/Data/Cleaned" "$clean_mxfls" "$clean_who" "$clean_rain" "$root/Output" "$out_sumstats" "$out_regs" "$out_logs" {
    capture mkdir "`d'"
}
* This includes writing to Main and Appendix subfolders, same as 00_Master.do
foreach d in "$out_sumstats" "$out_regs" "$out_logs" {
    foreach s in Main Appendix {
        capture mkdir "`d'/`s'"
    }
}
* 
* Tables and figures go to the folder of where they are placed, Main (paper), Appendix (appendix in the paper) or Online_Appendix
* The dose summary table is in the main text, the BMIZ balance table and overlap figure, the attrition tests and the Model 3 summary table in the appendix, and the sample size, sample attrition, HAZ and WAZ balance tables and overlap figures in the online appendix
capture mkdir "$out_sumstats/Online_Appendix"
capture mkdir "$out_figs"
foreach s in Main Appendix Online_Appendix {
    capture mkdir "$out_figs/`s'"
}

*******************************************************************
* Some preliminaries
*******************************************************************

capture which estpost
if _rc ssc install estout
capture which distinct
if _rc ssc install distinct

*******************************************************************
* Load DID analysis data
*******************************************************************

* Loading in data
use "$clean_mxfls/mxfls_did_analysis.dta", clear

*******************************************************************
* DID variables
*******************************************************************

* Keep remittances only on the 2005 row, blank on the others
gen remit05_tmp = remittance_hh if year == 2005
* Copy that 2005 value to all of the child's rows
bysort pid_link_canonical: egen remittance_hh_05 = max(remit05_tmp)
drop remit05_tmp

gen did_sample = age < 16 & !missing(treat2009) & treat_early == 0

*******************************************************************
* Globals
*******************************************************************

* Controls. We sort sections by household, child and mother, father and birth. Primarily bc father and birth have fewer observations for children and reduce the sample size a lot 
* Outcomes
global outcomes "haz waz bmiz"
* Treatment and the other droughts between the waves
global treatment "treat2009 drought2005 drought2006 drought2007 drought2008"
* Remittances
global remit "remittance_hh_05"
* Household controls
global controls_hh "dwell_electricity dwell_floor_good dwell_roof_good dwell_ventilation_good rooms_per_person ln_pc_expend_month rural"
* Child and mother controls
global controls_child "age child_male fully_vaccinated mother_height_cm mother_edu_years mother_age_at_birth mother_employed"
* Father and Book IV birth controls. Note this is filled for fewer children
global controls_birth "father_height_cm father_edu_years father_age_at_birth father_employed birth_order oldest_child birth_weight_kg delivered_home predominant_breastfed iron_pregnancy premature"

* All vars
global baseline_vars "$outcomes $remit $controls_hh $controls_child $controls_birth"
* Table variables as they enter the regressions, so 2002 remittances and household controls, and 2005 child and parent controls
global remit02 "remittance_hh_02"
global controls_hh02 "dwell_electricity_02 dwell_floor_good_02 dwell_roof_good_02 dwell_ventilation_good_02 rooms_per_person_02 ln_pc_expend_month_02 rural_02"
global table_vars "$treatment $remit02 $controls_hh02 $controls_child $controls_birth"


*******************************************************************
* Summary statistics table, 2005 at baseline
*******************************************************************

* Creating general summary table for our primary regression samples. Split into two panels. 
local cells "mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p50(fmt(2)) max(fmt(2)) count(fmt(%9.0fc))"
local groups `"treat2009 "\addlinespace[6pt]\textit{Binary DID treatment (CHIRPS)}" remittance_hh_02 "\addlinespace[6pt]\textit{Remittances (MxFLS-1, 2002)}" dwell_electricity_02 "\addlinespace[6pt]\textit{Household (MxFLS-1, 2002)}" age "\addlinespace[6pt]\textit{Child and mother (MxFLS-2, 2005)}" father_height_cm "\addlinespace[6pt]\textit{Father and birth (MxFLS-1 and MxFLS-2)}""'

* SPI classes, same cutoffs as add_spi() in functions.R, just adding and labeling some variables
foreach o in haz waz bmiz {
    gen tmp = `o' if year == 2009
    bysort pid_link_canonical: egen tmp09 = max(tmp)
    gen d_`o' = tmp09 - `o' if year == 2005
    drop tmp tmp09
}
label variable d_haz "Change in HAZ"
label variable d_waz "Change in WAZ"
label variable d_bmiz "Change in BMIZ"
gen cls_near = (rain_z2009 > -1) if rain_z2009 < 1
gen cls_mod = (rain_z2009 <= -1 & rain_z2009 > -1.5) if rain_z2009 < 1
gen cls_sev = (rain_z2009 <= -1.5) if rain_z2009 < 1
label variable rain_z2009 "2009 rainfall, z"
label variable cls_near "Near normal (\ensuremath{-1<z<1})"
label variable cls_mod "Moderately dry (\ensuremath{-1.5<z\le -1})"
label variable cls_sev "Severely dry or worse (\ensuremath{z\le -1.5})"

* We compute the numbers in the notes underneath the table here, so nothing is hardcoded. Same regressions as the sample size table further down including Model 3 of DID_Regs.do. 
capture which reghdfe
if _rc ssc install reghdfe
* reghdfe needs ftools and require, so on a new computer they must be installed before the first reghdfe below
capture which ftools
if _rc ssc install ftools
capture which require
if _rc ssc install require
foreach o in haz waz bmiz {
    quietly reghdfe `o' treat_post drought2005_post drought2006_post drought2007_post drought2008_post dwell_electricity_02_post dwell_floor_good_02_post dwell_roof_good_02_post dwell_ventilation_good_02_post rooms_per_person_02_post ln_pc_expend_month_02_post rural_02_post child_male_05_post mother_height_cm_05_post mother_edu_years_05_post mother_age_at_birth_05_post mother_employed_05_post fully_vaccinated_05_post if s_`o' == 1, absorb(pid_link_canonical int_ym) vce(cluster cvegeo05)
	* Picking model 3 sample for model 3 summary table
    gen m3s_`o' = e(sample)
    quietly distinct pid_link_canonical if e(sample)
	* Here we add some formatting for these 4 lines below
	* m3_ = children in Model 3
    local m3_`o' : display %9.0fc r(ndistinct)
    local m3_`o' = strtrim("`m3_`o''")
    * spi_ = children in the SPI sample
    quietly count if reg_`o' == 1 & year == 2005 & rain_z2009 < 1
    local spi_`o' : display %9.0fc r(N)
    local spi_`o' = strtrim("`spi_`o''")
}

* Panel A: WAZ sample
preserve
    * SPI sample, so without children in wet municipalities
    keep if reg_waz == 1 & year == 2005 & rain_z2009 < 1
    quietly estpost summarize waz d_waz rain_z2009 cls_near cls_mod cls_sev, detail
    esttab using "$out_sumstats/Main/summary_stats_did_table.tex", replace booktabs label ///
        cells("`cells'") collabels("Mean" "Std. dev." "Min." "Median" "Max." "Obs.") noobs nonumber nomtitle ///
        refcat(waz "\textit{Outcomes (MxFLS-2, 2005)}" d_waz "\addlinespace[6pt]\textit{Outcome change, 2005 to 2009}" rain_z2009 "\addlinespace[6pt]\textit{Dose levels (CHIRPS)}", nolabel) ///
        prehead("\documentclass[12pt]{article}" "\usepackage[margin=1in]{geometry}" "\usepackage{booktabs}" "\usepackage{longtable}" "\usepackage{caption}" ///
            "\DeclareCaptionLabelSeparator{emdash}{---}" "\captionsetup{font=normalsize,labelfont=sc,textfont=sc,labelsep=emdash}" "\begin{document}" ///
            "\begingroup" "\footnotesize" "\renewcommand{\arraystretch}{0.86}" "\setlength{\tabcolsep}{4pt}" "\setlength{\LTcapwidth}{\textwidth}" ///
            "\begin{longtable}{l*{6}{c}}" "\caption{Summary Statistics, Discrete-Dose Samples}\\" ///
            "\toprule" " & \multicolumn{6}{c}{Panel A: WAZ, age \ensuremath{\le}10 in 2005 and 2009}\\" "\cmidrule(lr){2-7}") ///
        posthead("\midrule") prefoot("") postfoot("\bottomrule" "\addlinespace[12pt]")
restore

* Panel B: HAZ and BMIZ sample, appended to the same table
preserve
    keep if reg_haz == 1 & year == 2005 & rain_z2009 < 1
    quietly estpost summarize haz bmiz d_haz d_bmiz rain_z2009 cls_near cls_mod cls_sev, detail
    esttab using "$out_sumstats/Main/summary_stats_did_table.tex", append booktabs label ///
        cells("`cells'") collabels("Mean" "Std. dev." "Min." "Median" "Max." "Obs.") noobs nonumber nomtitle ///
        refcat(haz "\textit{Outcomes (MxFLS-2, 2005)}" d_haz "\addlinespace[6pt]\textit{Outcome change, 2005 to 2009}" rain_z2009 "\addlinespace[6pt]\textit{Dose levels (CHIRPS)}", nolabel) ///
        prehead("\toprule" " & \multicolumn{6}{c}{Panel B: HAZ and BMIZ, age \ensuremath{\le}15 in 2005 and 2009}\\" "\cmidrule(lr){2-7}") ///
        posthead("\midrule") prefoot("") ///
        postfoot("\bottomrule" ///
            "\addlinespace[6pt]\multicolumn{7}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} This table is for the discrete-dose specification, the main model. Obs. counts children. The sample is children with the outcome measured in MxFLS-2 (2005) and MxFLS-3 (2009), under the panel's age cutoff" ///
            "in both survey waves, with a 2005 municipality. They were not measured in MxFLS-3 before November 2009. I use November 2009 as the cutoff because the 2009 rainfall deficit had not fully occurred before then. Dropping them from both groups equalizes treated and control measurement timing. Children in wet municipalities (z of 1 or above) are excluded." ///
            "Panel A uses the WAZ sample, Panel B the HAZ and BMIZ sample. The BMIZ sample is marginally smaller than the HAZ sample shown in Panel B, at `spi_bmiz' children. Statistics are at the 2005 baseline, except the change in WAZ, HAZ and BMIZ from 2005 to 2009, the outcome of the discrete-dose regressions, and 2009 rainfall. z is 2009 May--October CHIRPS rainfall, the maize growing season (Jessoe, Manning, and Taylor 2018), in the child's 2005 municipality in standard deviations" ///
            "from its 1981--2004 mean, grouped into dose levels with the SPI cutoffs (McKee, Doesken, and Kleist 1993; WMO 2012). The 2009 rainfall z is continuous. The three dose-group indicators have means equal to the share of children in each dose group. The discrete-dose regressions have no controls, as the contdid package does not yet accommodate covariates (Callaway, Goodman-Bacon, and Sant'Anna 2026).}\\" ///
            "\end{longtable}" "\endgroup" "\end{document}")
restore

* Summary table for the Model 3 sample of the binary DID, the same rows as the main table, without the continuous DID treatment. It goes in Tables/Appendix
* Panel A: WAZ sample
preserve
    keep if m3s_waz == 1 & year == 2005
    quietly estpost summarize waz $table_vars, detail
    * The Model 3 summary table is its own file in Tables/Appendix
    esttab using "$out_sumstats/Appendix/summary_stats_model3_table.tex", replace booktabs label ///
        cells("`cells'") collabels("Mean" "Std. dev." "Min." "Median" "Max." "Obs.") noobs nonumber nomtitle ///
        refcat(waz "\textit{Outcomes (MxFLS-2, 2005)}" `groups', nolabel) ///
        prehead("\documentclass[12pt]{article}" "\usepackage[margin=1in]{geometry}" "\usepackage{booktabs}" "\usepackage{longtable}" "\usepackage{caption}" ///
            "\DeclareCaptionLabelSeparator{emdash}{---}" "\captionsetup{font=normalsize,labelfont=sc,textfont=sc,labelsep=emdash}" "\begin{document}" ///
            "\begingroup" "\footnotesize" "\renewcommand{\arraystretch}{0.86}" "\setlength{\tabcolsep}{4pt}" "\setlength{\LTcapwidth}{\textwidth}" ///
            "\begin{longtable}{l*{6}{c}}" "\caption{Summary Statistics, Binary DID Model 3 Samples}\\" ///
            "\toprule" " & \multicolumn{6}{c}{Panel A: WAZ, age \ensuremath{\le}10 in 2005 and 2009}\\" "\cmidrule(lr){2-7}") ///
        posthead("\midrule") prefoot("") postfoot("\bottomrule" "\newpage")
restore

* Panel B: HAZ and BMIZ sample, appended to the same table
preserve
    keep if m3s_haz == 1 & year == 2005
    quietly estpost summarize haz bmiz $table_vars, detail
    esttab using "$out_sumstats/Appendix/summary_stats_model3_table.tex", append booktabs label ///
        cells("`cells'") collabels("Mean" "Std. dev." "Min." "Median" "Max." "Obs.") noobs nonumber nomtitle ///
        refcat(haz "\textit{Outcomes (MxFLS-2, 2005)}" `groups', nolabel) ///
        prehead("\toprule" " & \multicolumn{6}{c}{Panel B: HAZ and BMIZ, age \ensuremath{\le}15 in 2005 and 2009}\\" "\cmidrule(lr){2-7}") ///
        posthead("\midrule") prefoot("") ///
        postfoot("\bottomrule" ///
            "\addlinespace[6pt]\multicolumn{7}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} This table is for the sample of Model 3, the main binary DID with controls. Obs. counts children. The children have the outcome measured in MxFLS-2 (2005) and MxFLS-3 (2009), under the panel's age cutoff" ///
            "in both survey waves, and a 2005 municipality. They were not measured in MxFLS-3 before November 2009, for the same reason as in Table~\ref{tab:sumstats}." ///
            "Panel A uses the WAZ sample, Panel B the HAZ and BMIZ sample. The BMIZ sample is marginally smaller than the HAZ sample shown in Panel B, at `m3_bmiz' children. Statistics are at the 2005 baseline, except remittances and household variables (2002). Remittances enter Model 5, and the father and birth controls enter Model 4. Both are observed for fewer children." ///
            "Drought is May--October CHIRPS rainfall, the maize growing season (Jessoe, Manning, and Taylor 2018), in the 2005 municipality below its 1981--2004 20th percentile (Shah and Steinberg 2017). Remittances are cash received in the last" ///
            "12 months from parents, siblings, or children outside the household. Expenditure is in 2002 pesos per person per month." ///
            "Rural is a locality under 2,500 inhabitants (INEGI 2024).}\\" ///
            "\end{longtable}" "\endgroup" "\end{document}")
restore


*******************************************************************
* Balance table of treated vs control
*******************************************************************


* reghdfe needed for absorbing fixed effects; install once if not already present, same as in DID_Regs
capture which reghdfe
if _rc ssc install reghdfe
capture which ftools
if _rc ssc install ftools
capture which require
if _rc ssc install require


* This block defines a new Stata command called cnt_row. NOTE: Nothing runs here, just the template. This program writes one row of the table by 
	* 1) Counting how many control children, households or municipalities meet a condition
	* 1) Counting how many treated children, households or municipalities meet a condition
	* 3) Writes one line of LaTeX into the .tex file that label control count & treated count.
* Has about 60 rows, and this is done because more efficient then writing 60 times. Only the label and conditions change
capture program drop cnt_row
program define cnt_row
    gettoken label 0 : 0
    syntax , Sample(string) Control(string) Treated(string) [Distinct(varname) Last]
    foreach g in control treated {
		* Counting Children
		* NOTE: Basically box left blank no distinct(...) in the line then the program sees an empty box and counts children, one per row of data. 
        if "`distinct'" == "" {
            quietly count if (`sample') & (``g'')
            local n_`g' = r(N)
        }
		* Counting municipalities or households
		* NOTE: This distinct(...) is filled in with cvegeo05 or folio_canonical  here and specified later down
        else {
            capture quietly distinct `distinct' if (`sample') & (``g'')
            local n_`g' = cond(_rc, 0, r(ndistinct))
        }
		* Just formatting
        local c_`g' : display %12.0fc `n_`g''
        local c_`g' = strtrim("`c_`g''")
    }
    local end "\\*"
	* LaTeX stuff
    if "`last'" != "" local end "\\"
    file write cnt `"`label' & `c_control' & `c_treated'`end'"' _n
	* Displaying in stata
    di as text `"`label': "' as result "`c_control' control, `c_treated' treated"
end


preserve
* Run DID Models 1, 3 and 5 of DID_Regs.do, we flag with e(sample), meaning this creates a row with 1's and 0's and the 1's are the observations used in the regression. Then later on in the script we will count these ones to get the sample of treated or control. 
* Purpose of this block is to find out exactly which children each regression uses
local cnt_did_controls "drought2005_post drought2006_post drought2007_post drought2008_post"
local cnt_controls02 "dwell_electricity_02_post dwell_floor_good_02_post dwell_roof_good_02_post dwell_ventilation_good_02_post rooms_per_person_02_post ln_pc_expend_month_02_post rural_02_post"
local cnt_controls05 "child_male_05_post mother_height_cm_05_post mother_edu_years_05_post mother_age_at_birth_05_post mother_employed_05_post fully_vaccinated_05_post"
foreach o in haz waz bmiz {
    quietly reghdfe `o' treat_post if s_`o' == 1, absorb(pid_link_canonical int_ym) vce(cluster cvegeo05)
    gen m1_`o' = e(sample)
    quietly reghdfe `o' treat_post `cnt_did_controls' `cnt_controls02' `cnt_controls05' if s_`o' == 1, absorb(pid_link_canonical int_ym) vce(cluster cvegeo05)
    gen m3_`o' = e(sample)
    quietly reghdfe `o' treat_post remittance_hh_02_post treat_post_remit02 `cnt_did_controls' `cnt_controls02' `cnt_controls05' if s_`o' == 1, absorb(pid_link_canonical int_ym) vce(cluster cvegeo05)
    gen m5_`o' = e(sample)
}

* Every child in the regression samples has exactly two rows used, 2005 and 2009. The table counts children, not rows, so each child must be counted once, thus we only keep one year
keep if year == 2005
* SPI classes from z = 2009 rainfall in the 2005 municipality, the same cutoffs as add_spi() in functions.R
gen spi_near = (rain_z2009 > -1) if rain_z2009 < 1
gen spi_mod = (rain_z2009 <= -1 & rain_z2009 > -1.5) if rain_z2009 < 1
gen spi_sev = (rain_z2009 <= -1.5) if rain_z2009 < 1
gen spi_sevonly = (rain_z2009 <= -1.5 & rain_z2009 > -2) if rain_z2009 < 1
gen spi_ext = (rain_z2009 <= -2) if rain_z2009 < 1

* Text for the group headings
local age_haz "15 or younger"
local age_waz "10 or younger"
local age_bmiz "15 or younger"

capture file close cnt
* The sample size and attrition tables are their own file in Tables/Online_Appendix
file open cnt using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", write replace
foreach l in "\documentclass[12pt]{article}" "\usepackage[margin=1in]{geometry}" "\usepackage{booktabs}" "\usepackage{longtable}" "\usepackage{caption}" "\DeclareCaptionLabelSeparator{emdash}{---}" "\captionsetup{font=normalsize,labelfont=sc,textfont=sc,labelsep=emdash}" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" "\begin{document}" {
    file write cnt `"`l'"' _n
}

* LaTex
file write cnt "\begingroup" _n "\footnotesize" _n "\renewcommand{\arraystretch}{0.86}" _n "\setlength{\tabcolsep}{4pt}" _n "\setlength{\LTcapwidth}{\textwidth}" _n "\setlength{\LTleft}{0pt}" _n "\setlength{\LTright}{0pt plus 1fil}" _n
file write cnt "\begin{longtable}{@{\extracolsep{\fill}}lcc}" _n "\caption{Sample Sizes, Treated and Control Children}\\" _n 


*******************************************************************
* Panel A: binary DID
*******************************************************************
* LaTeX
file write cnt "\toprule" _n " & \multicolumn{2}{c}{Panel A: Binary DID, 2009 drought}\\*" _n "\cmidrule(lr){2-3}" _n " & Control & Treated\\*" _n "\midrule" _n
foreach o in haz waz bmiz {
    local O = upper("`o'")
    local space ""
    if "`o'" != "haz" local space "\addlinespace[6pt]"
    file write cnt "`space'\textit{`O' sample, children aged `age_`o'' in 2005 and 2009} & & \\*" _n
    local t "control(treat2009 == 0) treated(treat2009 == 1)"
	* This is calling upon the count if in our program and the t sets control vs treated counts
    cnt_row "Children, estimation sample", sample(reg_`o' == 1) `t'
    cnt_row "Children, Model 1 (basic DID)", sample(m1_`o' == 1) `t'
    cnt_row "Children, Model 3 (DID with controls)", sample(m3_`o' == 1) `t'
    cnt_row "Children, Model 5 (triple difference)", sample(m5_`o' == 1) `t'
	* Only exists for triple difference, and also adds up to total number of children in Model 5 with the children not in remittance households
    cnt_row "\quad In 2002 remittance households", sample(m5_`o' == 1 & remittance_hh_02 == 1) `t'
    cnt_row "Households, estimation sample", sample(reg_`o' == 1) `t' distinct(folio_canonical)
    cnt_row "2005 municipalities, estimation sample", sample(reg_`o' == 1) `t' distinct(cvegeo05) last
}
file write cnt "\bottomrule" _n

*******************************************************************
* Panel B: continuous DID, any 2009 rainfall deficit vs none
*******************************************************************

file write cnt "\addlinespace[12pt]" _n "\toprule" _n " & \multicolumn{2}{c}{Panel B: Continuous DID, any 2009 deficit}\\*" _n "\cmidrule(lr){2-3}" _n " & Control & Treated\\*" _n "\midrule" _n
foreach o in haz waz bmiz {
    local O = upper("`o'")
    local space ""
    if "`o'" != "haz" local space "\addlinespace[6pt]"
    file write cnt "`space'\textit{`O' sample, children aged `age_`o'' in 2005 and 2009} & & \\*" _n
    local t "control(any_deficit2009 == 0) treated(any_deficit2009 == 1)"
    cnt_row "Children, continuous DID sample", sample(reg_`o' == 1) `t'
	* Does not add up to total number of households thus we have both variables
    cnt_row "\quad In 2002 remittance households", sample(reg_`o' == 1 & remittance_hh_02 == 1) `t'
    cnt_row "\quad In 2002 non-remittance households", sample(reg_`o' == 1 & remittance_hh_02 == 0) `t'
    cnt_row "Households", sample(reg_`o' == 1) `t' distinct(folio_canonical)
    cnt_row "2005 municipalities", sample(reg_`o' == 1) `t' distinct(cvegeo05) last
}
file write cnt "\bottomrule" _n

*******************************************************************
* Panel C: continuous DID, SPI drought classes vs near normal
*******************************************************************

* Panel C starts on a new page like Panel B of the summary statistics table, so its header is not left at the bottom of a page
file write cnt "\newpage" _n "\toprule" _n " & \multicolumn{2}{c}{Panel C: Dose groups vs near normal}\\*" _n "\cmidrule(lr){2-3}" _n " & Control & Treated\\*" _n "\midrule" _n
* Each class with its z range, in the order of the SPI regressions in Contdid_regs.R
local cls_mod "Moderately dry (\ensuremath{-1.5<z\le -1})"
local cls_sev "Severely dry or worse (\ensuremath{z\le -1.5})"
local cls_sevonly "Severely dry (\ensuremath{-2<z\le -1.5})"
local cls_ext "Extremely dry (\ensuremath{z\le -2})"
foreach c in mod sev sevonly ext {
    local space ""
    if "`c'" != "mod" local space "\addlinespace[6pt]"
    file write cnt `"`space'\textit{`cls_`c''} & & \\*"' _n
    local t "control(spi_near == 1) treated(spi_`c' == 1)"
    cnt_row "Children, HAZ sample", sample(reg_haz == 1) `t'
    cnt_row "Children, WAZ sample", sample(reg_waz == 1) `t'
    cnt_row "Children, BMIZ sample", sample(reg_bmiz == 1) `t'
    cnt_row "2005 municipalities, HAZ sample", sample(reg_haz == 1) `t' distinct(cvegeo05)
    cnt_row "2005 municipalities, WAZ sample", sample(reg_waz == 1) `t' distinct(cvegeo05)
    cnt_row "2005 municipalities, BMIZ sample", sample(reg_bmiz == 1) `t' distinct(cvegeo05) last
}

* Notes at the bottom
file write cnt "\bottomrule" _n
file write cnt "\addlinespace[6pt]\multicolumn{3}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} Counts are children, households or 2005 municipalities in each regression sample at the 2005 baseline." _n
file write cnt "Estimation samples are children with the outcome measured in both MxFLS-2 (2005) and MxFLS-3 (2009) who have a 2005 municipality. They are aged 15 or younger for HAZ and BMIZ and 10 or younger for WAZ in both survey waves." _n
file write cnt "They were not measured in MxFLS-3 before November 2009, for the same reason as in Table~\ref{tab:sumstats}. In Panel A, treated children's 2005 municipality had a drought in 2009, meaning May--October CHIRPS rainfall in the maize growing season was below its 1981--2004 20th percentile" _n
file write cnt "(Jessoe, Manning, and Taylor 2018; Shah and Steinberg 2017). Model 1 drops children alone in their interview-month cell. Continuous DID uses the full sample. Model 3 adds 2005--2008 droughts and 2002 household and 2005 child and mother controls." _n
file write cnt "Model 5 adds 2002 remittances times post and drought times post times 2002 remittances. Model 5 children not in remittance households are the Model 5 count minus the remittance row. In Panel B, treated children's 2005 municipality had 2009" _n
file write cnt "rainfall below its 1981--2004 mean (z below 0), where z is 2009 rainfall in standard deviations from that mean. Panel B gives sample sizes for the continuous DID. Its two remittance rows are children in 2002 remittance and non-remittance households, the two groups compared in Panel B of Table~\ref{tab:oa_contdid}." _n
file write cnt "Rows do not add up to the total because children with missing 2002 remittances are in neither row. Panel C compares each dose group with near normal (z between -1 and 1) in the discrete-dose analysis." _n
file write cnt "Dose levels use standardized rainfall cutoffs of the SPI adopted by the World Meteorological Organization (McKee, Doesken, and Kleist 1993; WMO 2012). Children in wet municipalities (z of 1 or above) are not in the discrete-dose analysis." _n
file write cnt "Remittances are cash received in the last 12 months from parents, siblings or children living outside the household, from MxFLS-1 (2002).}\\" _n
file write cnt "\end{longtable}" _n "\endgroup" _n

file close cnt
restore



*******************************************************************
* Attrition, general aka not specific to regressions 
*******************************************************************

* Table 4: Sample attrition across the waves, as counts of children in each wave. The DID only uses 2005 and 2009 and the event studies use all three waves. The continuous DID uses the same samples, so this covers it too
* Each row starts from the children who meet the regression sample rules in the first wave and could stay in the sample, not from all children measured. Then the later columns count who is still in the sample
* NOTE THIS IS JUST OVERALL ATTRITION BETWEEN WAVES

preserve
* Age cutoffs of the samples, same as in Build_DID_Analysis_Data.do
local cut_haz 16
local cut_waz 11
local cut_bmiz 16

* The loop copies each child's age in 2002, 2005 and 2009 onto all of that child's rows. That way, each row can compare ages across waves, for example age2009-age2005. A missing age2009 marks the children whose 2009 age has to be filled in some other way: from their birth date and the 2009 interview date, or failing that, from the median gap.
foreach y in 2002 2005 2009 {
    gen tmp = age if year == `y'
    bysort pid_link_canonical: egen age`y' = max(tmp)
    drop tmp
}

* Median age gap between the waves, for children under 16 measured in both
* We use the median bc a few gaps are weird, like -4 or 44, probably from data entry errors
gen gap0509 = age2009 - age2005 if year == 2005 & age < 16
quietly summarize gap0509, detail
local gap0509 = r(p50)
local n0509 = r(N)
* Share of these children within a year of the median, for the notes section
quietly count if inrange(gap0509, `gap0509' - 1, `gap0509' + 1)
local sh0509 : display %3.0f 100 * r(N) / `n0509'
local sh0509 = strtrim("`sh0509'")
gen gap0209 = age2009 - age2002 if year == 2002 & age < 16
quietly summarize gap0209, detail
local gap0209 = r(p50)
local n0209 = r(N)
quietly count if inrange(gap0209, `gap0209' - 1, `gap0209' + 1)
local sh0209 : display %3.0f 100 * r(N) / `n0209'
local sh0209 = strtrim("`sh0209'")

* Copy each child's 2009 interview date to all of their rows
gen tmp = int_date if year == 2009
bysort pid_link_canonical: egen int2009 = max(tmp)
drop tmp

* This code below has essentially three steps
* 1) Measured: if the child was measured in 2009, use that real age.
* 2) Computed: if they're in MxFLS-3 but weren't measured, compute their age from their birth date and their household's 2009 interview date. This only happens if the birth date passed the cleaning check. This code is similar to the cleaning script
* 3) Estimated: if they're not in MxFLS-3 (or the birth date failed the check), take their last measured age plus the median gap: 4 years from 2005, 8 from 2002.
gen age_next = age2009
replace age_next = floor((int2009 - mdy(bmonth, 15, byear)) / 365.25) if missing(age_next) & !missing(age_days)
replace age_next = age2005 + `gap0509' if missing(age_next)
replace age_next = age2002 + `gap0209' if missing(age_next)

capture file close cnt
file open cnt using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", write append

* LaTeX
file write cnt "\clearpage" _n "\begingroup" _n "\footnotesize" _n "\renewcommand{\arraystretch}{0.86}" _n "\setlength{\tabcolsep}{4pt}" _n "\setlength{\LTcapwidth}{\textwidth}" _n "\setlength{\LTleft}{0pt}" _n "\setlength{\LTright}{0pt plus 1fil}" _n
file write cnt "\begin{longtable}{@{\extracolsep{\fill}}lccc}" _n "\caption{Sample Attrition Across Waves}\\" _n
file write cnt "\toprule" _n " & \multicolumn{3}{c}{Number of children (N)}\\*" _n "\cmidrule(lr){2-4}" _n " & MxFLS-1 (2002) & MxFLS-2 (2005) & MxFLS-3 (2009)\\*" _n "\midrule" _n

foreach o in haz waz bmiz {
    local O = upper("`o'")
    * This codes children as 1 if children meet the DID sample rules for the starting baseline regression specification
    gen did = (year == 2005 & age < `cut_`o'' & !missing(`o') & !missing(treat2009) & treat_early == 0 & age_next < `cut_`o'')
    * If children meet the event study rules
    gen es = (year == 2002 & age < `cut_`o'' & !missing(`o') & !missing(cvegeo) & treat_early == 0 & age_next < `cut_`o'')
    bysort pid_link_canonical: egen es05 = max(e_`o' == 1 & !missing(`o') & year == 2005)
    bysort pid_link_canonical: egen es_n3 = total(e_`o' == 1 & !missing(`o'))
    * Counting children
    quietly count if did == 1
    local d05 = r(N)
    quietly count if did == 1 & reg_`o' == 1
    local d09 = r(N)
    quietly count if es == 1
    local e02 = r(N)
    quietly count if es == 1 & es05 == 1
    local e05 = r(N)
    quietly count if es == 1 & es_n3 == 3
    local e09 = r(N)
    * Just formatting
    foreach x in d05 d09 e02 e05 e09 {
        local `x' : display %12.0fc ``x''
        local `x' = strtrim("``x''")
    }
    * LaTeX stuff
    local space ""
    if "`o'" != "haz" local space "\addlinespace[6pt]"
    file write cnt "`space'\textit{`O' sample, children under `cut_`o''} & & & \\*" _n
    file write cnt "DID (2005 and 2009) & & `d05' & `d09'\\*" _n
    file write cnt "Event studies (all three waves) & `e02' & `e05' & `e09'\\" _n
    * Displaying in stata
    di as text "`O': DID 2005 `d05', 2009 `d09' | event studies 2002 `e02', 2005 `e05', 2009 `e09'"
    drop did es es05 es_n3
}

* Notes at the bottom, like Tables 1 and 2
file write cnt "\bottomrule" _n
file write cnt "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} Counts of children in each wave. The binary DID only uses MxFLS-2 (2005) and MxFLS-3 (2009)." _n
file write cnt "The continuous DID uses the same sample as the binary DID. The event studies use all three waves. Each row starts from the children who meet the regression sample rules in its first wave and could stay in the sample." _n
file write cnt "They are under the age cutoff in every wave, 15 or younger for HAZ and BMIZ and 10 or younger for WAZ. They were not measured in MxFLS-3 before" _n 
file write cnt "November 2009, for the same reason as in Table~\ref{tab:sumstats}. Later columns count the children still in the sample, so the drop across columns is attrition. This is not the same as the children the regressions drop as singletons, with" _n
file write cnt "only one wave in the sample, as these also include children who aged out or are only in a later wave. The DID 2009 count is the estimation sample, and the event study 2009 count is the" _n
file write cnt "children in all three waves. For children not measured in a later wave, I estimate their age in that wave to see whether they aged out. Their age comes from their birth date and their household's MxFLS-3 interview date," _n
file write cnt "since MxFLS-3 interviews ran over several years. Children not in MxFLS-3 or whose birth date does not match their reported age get their last measured age plus the median gap between waves." _n
file write cnt "This gap is `gap0509' years from 2005 to 2009 and `gap0209' years from 2002 to 2009. Among children measured in both waves, `sh0509' and `sh0209' percent of gaps are within a year of the median." _n
file write cnt "A one-year error only matters for children near the age cutoff. This way, children who simply aged out are not counted as attrition.}\\" _n
file write cnt "\end{longtable}" _n "\endgroup" _n
file close cnt

*******************************************************************
* Attrition tests, specific to regressions
*******************************************************************

* We run two attrition tests to assess attrition bias
* 1) Regress attrition on the dose groups and on the binary drought
* 2) Baseline Outcomes of Attrited and Non-Attrited Children
	*(a) regress the 2005 outcome on attrition for all children
	*(b) keep only the children lost to attrition and regress their 2005 outcome on the treatment
* NOTE: One row per child the 2005 row, no fixed effects or controls like the balance table, standard errors clustered by 2005 municipality


*** ATTRITION CONCEPT ******
    * NOTE: CAN THINK OF DID AS DENOMINATOR AND ATTRITED AS NUMERATOR
    * attrited = 1: the child met the sample rules in 2005 and would still have been young enough in 2009, but has no usable 2009 measurement, so the child dropped out of the sample
    * attrited = 0: the child was measured in 2009 and is in the regression sample. Children who simply aged out aren't counted either way


foreach o in haz waz bmiz {
    * did = 1 marks every child who met the DID sample rules in 2005 and could have been in the 2009 estimation sample
    gen did = (year == 2005 & age < `cut_`o'' & !missing(`o') & !missing(treat2009) & treat_early == 0 & age_next < `cut_`o'')
    * Attrited = 1 if the child is not in the 2009 estimation sample and 0 if the child is. Both are eligible children, i.e. did == 1 in both cases
    gen attrited = (reg_`o' != 1) if did == 1
    * Test 1, dose groups vs near normal and binary drought
    quietly regress attrited cls_mod cls_sev if did == 1, vce(cluster cvegeo05)
	* Computes mean attrition
    quietly summarize attrited if e(sample)
    estadd scalar mean = r(mean)
    eststo a1_`o'
    quietly regress attrited treat2009 if did == 1, vce(cluster cvegeo05)
    quietly summarize attrited if e(sample)
    estadd scalar mean = r(mean)
    eststo a2_`o'
    * Test 2 (a) the 2005 outcome on attrition for all children on the dose sample and the binary sample
    quietly regress `o' attrited if did == 1 & !missing(cls_mod), vce(cluster cvegeo05)
    quietly summarize `o' if e(sample)
    estadd scalar mean = r(mean)
    eststo b1_`o'
    quietly regress `o' attrited if did == 1, vce(cluster cvegeo05)
    quietly summarize `o' if e(sample)
    estadd scalar mean = r(mean)
    eststo b2_`o'
    * Test 2 (b) only the children lost to attrition. Their 2005 outcome on the dose groups and on the binary drought
    quietly regress `o' cls_mod cls_sev if did == 1 & attrited == 1, vce(cluster cvegeo05)
    quietly summarize `o' if e(sample)
    estadd scalar mean = r(mean)
    eststo c1_`o'
    quietly regress `o' treat2009 if did == 1 & attrited == 1, vce(cluster cvegeo05)
    quietly summarize `o' if e(sample)
    estadd scalar mean = r(mean)
    eststo c2_`o'
    drop did attrited
}

* Notes
local tstart `" "\clearpage" "\begingroup" "\footnotesize" "\renewcommand{\arraystretch}{0.86}" "\setlength{\tabcolsep}{4pt}" "\setlength{\LTcapwidth}{\textwidth}" "'
local dlab `"cls_mod "Moderately dry (\ensuremath{-1.5<z\le -1})" cls_sev "Severely dry or worse (\ensuremath{z\le -1.5})" treat2009 "Drought""'
local stars "\mbox{\sym{*}\(p<.10\), \sym{**}\(p<.05\), \sym{***}\(p<.01\).}"
local fe "There are no fixed effects or controls. Standard errors clustered by 2005 municipality are in parentheses. Wild cluster bootstrap p-values are not reported."
local a_note "Each column regresses an indicator for attrition on the treatment. Each coefficient is the difference in the probability of attrition between children in that rainfall group and children in near-normal municipalities. Attrition equals 1 if the child is not in the 2009 estimation sample. The table compares moderately dry and severely dry or worse with near-normal (\ensuremath{-1<z<1}) municipalities. The sample omits children in wet municipalities (z of 1 or above). Specifically, children in the sample meet the regression sample rules in MxFLS-2 (2005). That is, they are aged 15 or younger for HAZ and BMIZ and 10 or younger for WAZ in both survey waves, have a 2005 municipality, and were not measured in MxFLS-3 before November 2009, for the same reason as in Table~\ref{tab:sumstats}. Children who aged out are not counted as attrition."
local a2_note "See Table~\ref{tab:oaattrrain} notes. The coefficient is the difference in the probability of attrition between children in drought and non-drought municipalities. This specification includes wet municipalities (z of 1 or above) and uses the binary drought instead of the dose groups. Drought is May--October 2009 CHIRPS rainfall below the municipality's 1981--2004 20th percentile (Shah and Steinberg 2017)."
* Notes
local b_note "This table tests whether the children lost to attrition differ at baseline from those who stay. Each column regresses the 2005 WHO z-score on an indicator for attrition, for all children. Attrition equals 1 if the child is not in the 2009 estimation sample. The sample is as in Table~\ref{tab:oaattrrain}. The treatment does not enter. The dose and binary versions differ only in that the discrete-dose version excludes children in wet municipalities (z of 1 or above)."
local b2_note "See Table~\ref{tab:oaattrbase} notes. This version includes children in wet municipalities."
local c_note "This table tests whether the children lost to attrition from moderately dry and severely dry or worse municipalities differ at baseline from those lost from near-normal (\ensuremath{-1<z<1}) municipalities. It keeps only the children lost to attrition, without children in wet municipalities (z of 1 or above). Each column regresses their 2005 WHO z-score on the treatment. The sample is as in Table~\ref{tab:oaattrrain}."
local c2_note "See Table~\ref{tab:oaattrlost} notes. This version compares the children lost to attrition from drought municipalities with those lost from all other municipalities, including wet ones. Drought is May--October 2009 CHIRPS rainfall below the municipality's 1981--2004 20th percentile (Shah and Steinberg 2017)."

* Table 1: Effects of the 2009 Rainfall Deficit on Attrition, discrete dose and binary DID
esttab a1_haz a1_waz a1_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(cls_mod cls_sev) varlabels(`dlab') ///
    stats(mean N, labels("Mean attrition" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Effects of the 2009 Rainfall Deficit on Attrition, Discrete Dose}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `a_note' `fe' `stars'}\\" "\end{longtable}" "\endgroup")
esttab a2_haz a2_waz a2_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(treat2009) varlabels(`dlab') ///
    stats(mean N, labels("Mean attrition" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Effects of the 2009 Rainfall Deficit on Attrition, Binary DID}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `a2_note' `stars'}\\" "\end{longtable}" "\endgroup")

* Table 2: Baseline Outcomes of Attrited and Non-Attrited Children, test 2 (a), discrete dose and binary DID
local blab `"`dlab' attrited "Attrited""'
esttab b1_haz b1_waz b1_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(attrited) varlabels(`blab') ///
    stats(mean N, labels("Mean of 2005 outcome" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Baseline Outcomes of Attrited and Non-Attrited Children, Discrete Dose}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `b_note' `fe' `stars'}\\" "\end{longtable}" "\endgroup")
esttab b2_haz b2_waz b2_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(attrited) varlabels(`blab') ///
    stats(mean N, labels("Mean of 2005 outcome" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Baseline Outcomes of Attrited and Non-Attrited Children, Binary DID}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `b2_note' `stars'}\\" "\end{longtable}" "\endgroup")

* Table 3: Baseline Outcomes of Children Lost to Attrition, test 2 (b), discrete dose and binary DID
esttab c1_haz c1_waz c1_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(cls_mod cls_sev) varlabels(`blab') ///
    stats(mean N, labels("Mean of 2005 outcome" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Baseline Outcomes of Children Lost to Attrition, Discrete Dose}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `c_note' `fe' `stars'}\\" "\end{longtable}" "\endgroup")
esttab c2_haz c2_waz c2_bmiz using "$out_sumstats/Online_Appendix/sample_size_attrition_tables.tex", append booktabs ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(treat2009) varlabels(`blab') ///
    stats(mean N, labels("Mean of 2005 outcome" "Children") fmt(3 %9.0fc)) collabels(none) nomtitles numbers nonotes noobs nodepvars ///
    prehead(`tstart' "\begin{longtable}{l*{3}{c}}" "\caption{Baseline Outcomes of Children Lost to Attrition, Binary DID}\\" "\toprule" " & HAZ & WAZ & BMIZ\\") ///
    posthead("\midrule") prefoot("\midrule") ///
    postfoot("\bottomrule" "\addlinespace[6pt]\multicolumn{4}{p{0.97\textwidth}}{\scriptsize \textit{Notes:} `c2_note' `stars'}\\" "\end{longtable}" "\endgroup" "\end{document}")
restore


******************************************************************************************************************
* Exogeneity/Robustness of Rainfall
******************************************************************************************************************

* IN GENERAL HERE WE ARE MAKING SURE RAINFALL ISN'T UNBALANCED BETWEEN COVARIATES

* This table looks at if children in dry municipalities  differ from near normal ones before the 2009 drought
* Same children as the rainfall class regressions in Contdid_regs.R
* NOTE: No fixed effects, bc the rainfall class regressions and contdid use the 2005 to 2009 change with no fixed effects or covariates, so we test the same comparison

* Column variables and their headers, in the order of the table. Two rows of 16 columns like Table D4
local bal_vars "dwell_electricity_02 dwell_floor_good_02 dwell_roof_good_02 dwell_ventilation_good_02 rooms_per_person_02 ln_pc_expend_month_02 pc_expend_month_02 rural_02 progresa_hh_02 remittance_hh_02 child_male_05 age fully_vaccinated_05 mother_height_cm_05 mother_edu_years_05 mother_age_at_birth_05 mother_employed_05 father_height_cm_05 father_edu_years_05 father_age_at_birth_05 father_employed_05 birth_order_05 oldest_child_05 birth_weight_kg_05 delivered_home_05 predominant_breastfed_05 iron_pregnancy_05 premature_05 outcome05 long_run_mean long_run_sd"
* This is for the headers for the 1st row of columns, 2nd row of columns up to premature. And then for col. 30 and after they are added in by a loop below, not here
local bal_h1 `""Electricity" "Good floor" "Good roof" "Enough ventilation" "Rooms per person" "Log expenditure" "Expenditure (pesos)" "Rural" "PROGRESA" "Remittances" "Male" "Age" "Fully vaccinated" "Mother's height (cm)" "Mother's schooling" "Mother's age at birth""'
local bal_h2 `""Mother employed" "Father's height (cm)" "Father's schooling" "Father's age at birth" "Father employed" "Birth order" "Oldest child" "Birth weight (kg)" "Born at home" "Weeks breastfed" "Iron in pregnancy" "Premature""'

* Baseline characteristics for the propensity score of the overlap figure, the Model 3 controls and the child's age
local ps_vars "dwell_electricity_02 dwell_floor_good_02 dwell_roof_good_02 dwell_ventilation_good_02 rooms_per_person_02 ln_pc_expend_month_02 rural_02 child_male_05 mother_height_cm_05 mother_edu_years_05 mother_age_at_birth_05 mother_employed_05 fully_vaccinated_05 age"

* Column numbers and the names of the stored regressions, for the 1st row of columns 1 to 16 and the 2nd row of columns 17 to 31
* Adding column numbers above each title
forvalues j = 1/16 {
    local nums1 `"`nums1' "(`j')""'
    local mods1 "`mods1' b`j'"
}
* 31 columns in total
forvalues j = 17/31 {
    local nums2 `"`nums2' "(`j')""'
    local mods2 "`mods2' b`j'"
}

* Looping over outcomes
foreach o in bmiz haz waz {
    local O = upper("`o'")
    preserve
    * Keeping rainfall class sample
    keep if reg_`o' == 1 & year == 2005 & rain_z2009 < 1
    gen mod_dry = (rain_z2009 <= -1 & rain_z2009 > -1.5)
    gen sev_dry = (rain_z2009 <= -1.5)
    * Listing outcomes 
    gen outcome05 = `o'
    quietly count
    * Formatting
    local n_all : display %9.0fc r(N)
    local n_all = strtrim("`n_all'")

    * Running one regression per column. Similar to add_rows in Regression Stats.do, estadd attaches each column's mean to its regression so esttab can write it
    eststo clear
    * Starts a counter at 0. It numbers the columns
    local k = 0
    * Looping over the covariates
    foreach v of local bal_vars {
        local ++k
        quietly regress `v' mod_dry sev_dry, vce(cluster cvegeo05)
        quietly summarize `v' if e(sample)
        estadd scalar mean = r(mean)
        eststo b`k'
    }

    * LaTeX, creating a landscape table with two rows of 16 columns
    * The BMIZ balance table is in the appendix, and the HAZ and WAZ ones are in the online appendix
    local file = cond("`o'" == "bmiz", "$out_sumstats/Main/balance_table.tex", "$out_sumstats/Online_Appendix/balance_table_online_appendix.tex")
    local mode = cond("`o'" == "waz", "append", "replace")
    local doc `" "\documentclass[12pt]{article}" "\usepackage[margin=1in]{geometry}" "\usepackage{booktabs}" "\usepackage{longtable}" "\usepackage{caption}" "\usepackage{graphicx}" "\usepackage{array}" "\usepackage{pdflscape}" "\DeclareCaptionLabelSeparator{emdash}{---}" "\captionsetup{font=normalsize,labelfont=sc,textfont=sc,labelsep=emdash}" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" "\begin{document}" "'
    if "`o'" == "waz" local doc ""
    local end = cond("`o'" == "haz", "\clearpage", "\end{document}")
    * Specifications
    local ph `" `doc' "\begin{landscape}" "\begin{table}[!h]" "\centering" "\caption{Dose Groups and Baseline Characteristics, `O' Sample}" "\begingroup" "\footnotesize" "\hyphenpenalty=10000" "\exhyphenpenalty=10000" "\renewcommand{\arraystretch}{0.86}" "\setlength{\tabcolsep}{1.5pt}" "\resizebox{\linewidth}{!}{%" "\begin{tabular}{l*{16}{>{\centering\arraybackslash}p{2.2cm}}}" "\toprule" "'

    * Notes
    local pf `" "\bottomrule" "\end{tabular}}" "\endgroup" "\par\vspace{6pt}\parbox{\linewidth}{\scriptsize \textit{Notes:} The sample is the `n_all' children in the `O' discrete-dose regressions. Each column regresses a baseline characteristic on indicators for moderately dry (\ensuremath{-1.5<z\le -1}) and severely dry or worse (\ensuremath{z\le -1.5}) municipalities. Each coefficient is the mean difference in the characteristic between children in that dry dose group and children in the near-normal dose group (\ensuremath{-1<z<1})." "Columns 1--10 are from MxFLS-1 (2002) and columns 11--29 from MxFLS-2 (2005). Of particular interest are the measures of household poverty. Expenditure per person is a proxy for income and is shown in logs and in 2002 pesos per month. PROGRESA equals 1 if any household member was in the program in the last 12 months, which marks the household as poor by the program's targeting. The dwelling characteristics also reflect household poverty." "Long-run rainfall is the municipality's 1981--2004 May--October mean and SD in millimeters. The table has no fixed effects because the discrete-dose regressions use each child's 2005-to-2009 change without fixed effects or covariates. Standard errors clustered by 2005 municipality are in parentheses. Wild cluster bootstrap p-values are not reported." "\mbox{\sym{*}\(p<.10\), \sym{**}\(p<.05\), \sym{***}\(p<.01\).}}" "\end{table}" "\end{landscape}" "`end'" "'

    * Writes the table into .tex
    * We save a local with text saying no fixed effects, this is just a long row at the bottom of the table 
    local heads2 `"`bal_h2' "`O'" "Long-run rain mean" "Long-run rain SD""'
    forvalues r = 1/2 {
        local a = 16 * (`r' - 1) + 1
        local z = 16 * `r'
        * Settings for the first row == 1
        * The first row has 16 columns and the second row 15
        local nc = cond(`r' == 1, 16, 15)
        local fe `""Fixed effects & \multicolumn{`nc'}{c}{None}\\""'
        local pat ""
        forvalues j = 1/`nc' {
            local pat "`pat' 1"
        }
        if `r' == 1 {
            local heads `"`bal_h1'"'
            local top `"`ph'"'
            local bottom `"`fe'"'
        }
        * Settings for the second row
        else {
            local heads `"`heads2'"'
            local top `""\addlinespace[8pt]" "\toprule""'
            local bottom `"`fe' `pf'"'
            local mode "append"
        }
        * Writes the results and formatting
        esttab `mods`r'' using "`file'", `mode' booktabs ///
            cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01) keep(mod_dry sev_dry) varlabels(mod_dry "Moderately dry" sev_dry "Severely dry or worse") ///
            stats(N mean, labels("\addlinespace[3pt]Observations" "Mean of dep. var.") fmt(%9.0fc 3)) ///
            mgroups(`nums`r'', pattern(`pat')) mlabels(`heads', prefix("") suffix("")) ///
            collabels(none) nonumbers nonotes noobs nodepvars ///
            prehead(`top') posthead("\midrule") prefoot("") postfoot(`bottom')
    }

    * Overlap figure. This is the propensity score of each dry class vs near normal. contdid has no controls
	* NOTE: A logit drops every child with any missing variable, but the contdid regressions keep all children. So for each variable with missing values, the code fills the gaps with the sample mean and adds a 0/1 flag marking which children were filled in, as Adhvaryu et al. do.
    local Xf ""
    foreach v of local ps_vars {
        quietly count if missing(`v')
        if r(N) > 0 {
            gen m_`v' = missing(`v')
            quietly summarize `v'
            gen f_`v' = cond(missing(`v'), r(mean), `v')
            local Xf "`Xf' f_`v' m_`v'"
        }
        else local Xf "`Xf' `v'"
    }
    * Creating the two panels that are comparing sev dry to normal and also mod dry to normal 
	* Severely dry vs near normal
    gen d1 = sev_dry if mod_dry == 0
	* Moderately dry vs near normal
    gen d2 = mod_dry if sev_dry == 0
    foreach c in 1 2 {
		* Labels
		* This goes into legend
        local lab = cond(`c' == 1, "Severely dry or worse", "Moderately dry")
        * This label goes into title 
        local xt = cond(`c' == 1, "severely dry or worse", "moderately dry")
        * Propensity score run here. Which is the predicted chance of being in the dry class from the baseline characteristics
        quietly logit d`c' `Xf'
        predict ps`c' if e(sample), pr
        * This is for numbers for the box in the figure. We are just doing simple formatting, and calling upon. Note: Outside support counts dry children whose score is below the lowest or above the highest near normal score
        quietly summarize ps`c' if d`c' == 1
        local mt : display %4.2f r(mean)
        local nt : display %9.0fc r(N)
        local nt = strtrim("`nt'")
        quietly summarize ps`c' if d`c' == 0
        local mc : display %4.2f r(mean)
        local nc : display %9.0fc r(N)
        local nc = strtrim("`nc'")
        quietly count if d`c' == 1 & (ps`c' < r(min) | ps`c' > r(max))
        local out = r(N)
        local box `""Children  `nt' / `nc'" "Mean score  `mt' / `mc'" "Outside support  `out'""'
        * Create twoway graph
        twoway ///
            (kdensity ps`c' if d`c' == 1, range(0 1) lc(black) lw(medthick)) ///
            (kdensity ps`c' if d`c' == 0, range(0 1) lc(black) lw(medthick) lp(dash)), ///
            graphregion(color(white)) plotregion(color(white) lcolor(black) lwidth(thin) margin(zero)) ///
            ylabel(0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6", angle(0) labsize(medsmall) glcolor(gs14) glwidth(vthin) glpattern(solid) tlcolor(black)) ///
            xlabel(0 "0" 0.2 ".2" 0.4 ".4" 0.6 ".6" 0.8 ".8" 1 "1", labsize(medsmall) grid glcolor(gs14) glwidth(vthin) glpattern(solid) tlcolor(black)) ///
            xscale(range(0 1) lcolor(black)) yscale(range(0 6) lcolor(black)) ///
            text(4.56 0.665 `box', placement(se) justification(left) box bcolor(white) lcolor(black) lwidth(thin) margin(small) size(medsmall)) ///
            legend(order(1 "`lab'" 2 "Near normal") ring(0) pos(1) cols(1) region(lcolor(black) lwidth(thin)) size(medsmall) symxsize(8) keygap(1)) ///
            xtitle("Predicted chance of being `xt'", size(medium)) ytitle("Density", size(medium)) name(overlap`c', replace)
    }
    * Exporting to Main or Online_Appendix
    * The BMIZ overlap figure is in the main text
    local f = cond("`o'" == "bmiz", "Main", "Online_Appendix")
    graph combine overlap1 overlap2, rows(1) xsize(13) ysize(5) graphregion(color(white)) imargin(small)
    graph export "$out_figs/`f'/overlap_pscore_`o'.png", replace width(2600)
    restore
}










