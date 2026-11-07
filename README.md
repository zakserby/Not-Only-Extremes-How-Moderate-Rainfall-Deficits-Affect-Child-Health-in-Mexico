# Not Only Extremes: How Moderate Rainfall Deficits Affect Child Health in Mexico (MS Thesis)

**Zachary Serby, Cornell University**

> **This project is fully reproducible. All data needed to run the analysis are included in this repository, and every file path is relative. The project can be downloaded and run on any computer without changing file paths or settings. Running the single master file `Scripts/00_Master.do` rebuilds the cleaned survey data from the raw data and produces all regressions, tables, and figures along with the paper, online appendix and results PDFs.**

**Paper:** [Paper.pdf](https://zakserby.github.io/Not-Only-Extremes-How-Moderate-Rainfall-Deficits-Affect-Child-Health-in-Mexico/Paper.pdf) (the paper and its appendix), with the [online appendix](https://zakserby.github.io/Not-Only-Extremes-How-Moderate-Rainfall-Deficits-Affect-Child-Health-in-Mexico/Online_Appendix.pdf) and every table and figure in [Results.pdf](https://zakserby.github.io/Not-Only-Extremes-How-Moderate-Rainfall-Deficits-Affect-Child-Health-in-Mexico/Results.pdf) (links in the PDFs are clickable; also in [Paper/](Paper))
**Code:** [Scripts/](Scripts) (start with [Scripts/00_Master.do](Scripts/00_Master.do))

---

## Overview

This thesis studies how the effects of the 2009 rainfall deficit in Mexico on child health vary with the severity of the deficit, measured by WHO height-for-age (HAZ), weight-for-age (WAZ), and BMI-for-age (BMIZ) z-scores, and whether household remittances buffered the shock. It combines the Mexican Family Life Survey (2002, 2005, 2009) with municipality-level CHIRPS rainfall over the May-October growing season. The main design is a difference-in-differences that treats rainfall severity categories (SPI cutoffs) as the dose levels of a multi-valued discrete treatment, following Callaway, Goodman-Bacon and Sant'Anna (2024), with near-normal municipalities as the comparison group. It also estimates a binary difference-in-differences with baseline controls, triple differences with 2002 remittances, event studies, and the continuous difference-in-differences, with subanalyses by child sex and by rural vs urban locality.

## How to run

1. Download or clone this repository.
2. Open `Scripts/00_Master.do` (double-clicking it sets Stata's working folder to `Scripts`; if Stata is already open, `cd` to the project or `Scripts` folder first). The project root is found automatically.
3. Run it. The full pipeline runs, in order: MxFLS cleaning (2002, 2005, 2009), the DID analysis data, summary statistics and balance tables, the drought map (R), DID/DDD and event studies, continuous DID (R), subanalyses by sex and by rural vs urban (Stata, then R), the regression tables, and the paper (R, compiled to `Paper/Paper.pdf`, `Paper/Online_Appendix.pdf` and `Paper/Results.pdf`). The continuous DID steps are the slowest because of the wild cluster bootstrap.

Each step can be switched on or off with the `run_*` switches at the top of `00_Master.do` (all are on). The master calls R through `Rscript` and finds it automatically in the usual Mac locations; on another system, set `global Rscript` in `00_Master.do`.

### Rainfall data

The cleaned municipality rainfall panel (`Data/Cleaned/Rainfall/municipality_year_rainfall.dta`) is included, so the analysis runs without the raw rainfall file. The raw CHIRPS file (7.7 GB) is not included because it exceeds GitHub's file size limit. To rebuild the rainfall panel from scratch, download it from the UCSB Climate Hazards Center:

https://data.chc.ucsb.edu/products/CHIRPS-2.0/global_monthly/netcdf/chirps-v2.0.monthly.nc

place it at `Data/Raw/Rainfall/chirps-v2.0.monthly.nc`, and set `run_R` to 1 in `00_Master.do`. If the cleaned rainfall file is ever missing, the master rebuilds it automatically from the raw file.

## Repository structure

```
Scripts/
  00_Master.do                      Runs everything in order
  MS Thesis.Rproj                   R project (R scripts take the project root as one folder up from Scripts)
  .Rprofile                         Saves the R console history to Output/Logs/Miscellaneous when R closes
  Cleaning/
    Cleaned_rainfall_municipality_drought.R   CHIRPS to a municipality-year May-October rainfall panel and drought indicator
    Cleaning Script for MxFLS_2002_03.do      Cleans each MxFLS wave: WHO z-scores, remittances, controls
    Cleaning Script for MxFLS_2005_06.do
    Cleaning Script for MxFLS_2009_12.do      Also appends the three waves into the panel
    Build_DID_Analysis_Data.do                Merges the panel with rainfall, builds treatment, controls, samples
  Statistics/
    Summary Stats DID.do            Summary statistics, sample sizes, attrition, balance tables and overlap figures
    Regression Stats.do             All regression tables in LaTeX
    Drought_map.R                   Maps of the 2009 drought by municipality
  Regressions/
    DID_Regs.do                     Binary DID, triple difference, event studies, robustness
    Contdid_regs.R                  Continuous DID, rainfall dose groups (SPI cutoffs), remittance buffer
    functions.R                     Functions used by the R scripts
    Subanalysis_Gender_*            Same analyses for boys and girls
    Subanalysis_Rural_*             Same analyses for rural and urban children
  Paper/
    Build_Results.R                 Writes Paper.tex, Online_Appendix.tex and Results.tex and compiles the PDFs

Data/
  Raw/        MxFLS data and documentation (codebooks, questionnaires, user guides),
              INEGI municipal shapefiles, WHO z-score macros (never edited by any script)
  Cleaned/    Produced by the scripts: MxFLS wave files and panel, DID analysis data,
              WHO z-score files, municipality rainfall panel

Output/
  Tables/                 Summary statistics, balance and regression tables (.tex)
  Regression_Estimates/   Event study coefficients (.dta) and continuous DID estimates (.csv)
  Figures/                Trends, event studies, continuous DID figures, overlap figures, 2009 drought maps (.png)
                          Main and Appendix are in the paper, Online_Appendix is in the online appendix
  Logs/                   Every Stata, R and LaTeX log

Paper/
  Paper.tex, Paper.pdf              The paper and its appendix
  Online_Appendix.tex, .pdf         Online appendix (subanalyses and additional figures)
  Results.tex, Results.pdf          Every table and figure
  Text/                             Text of the paper and online appendix, and References.bib

README.rtf                          Detailed project readme
```

## Data sources

- **Mexican Family Life Survey (MxFLS)**: MxFLS-1 (2002), MxFLS-2 (2005-06), MxFLS-3 (2009-12). Data, codebooks, questionnaires and user guides are publicly available at no charge from [ennvih-mxfls.org](http://www.ennvih-mxfls.org).
- **CHIRPS v2.0** monthly precipitation, 0.05 degree grid, UCSB Climate Hazards Center: [chirps-v2.0.monthly.nc](https://data.chc.ucsb.edu/products/CHIRPS-2.0/global_monthly/netcdf/chirps-v2.0.monthly.nc).
- **INEGI** Marco Geoestadistico 2010 municipal boundaries (Municipios_2010_5).
- **WHO** Child Growth Standards (igrowup) and 2007 Growth Reference (who2007) Stata macros.

## Software requirements

- **Stata** (tested with Stata 19 MP). reghdfe, ftools, require, estout, distinct and boottest install automatically.
- **R** 4.x (tested with R 4.4.2). terra, sf, data.table, readxl, haven, did (>= 2.5.0), BMisc, sandwich, RColorBrewer and tinytex install automatically. contdid 0.1.1 installs from GitHub (bcallaway11/contdid) and needs ptetools >= 1.0.1. fwildclusterboot 0.13.0 and summclust 0.7.2 install from the CRAN archive and need the Xcode command line tools and gfortran on a Mac.
- **TinyTeX** compiles Paper.pdf, Online_Appendix.pdf and Results.pdf; `Build_Results.R` installs it if no LaTeX is found, and missing LaTeX packages (including biblatex-chicago and biber for the references) install automatically.

Bootstrap results are reproducible: `set.seed(1234)` is set before every bootstrap in R, and `seed(1234)` for every `boottest` in Stata.
