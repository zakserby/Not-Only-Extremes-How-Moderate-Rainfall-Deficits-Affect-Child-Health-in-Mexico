#===============================================================================
# MS Thesis
# Results document
#===============================================================================

# This script puts every table and figure in the output folder into one LaTeX file and also a PDF file. We use TinyTex. Note that miscellaneous figures are not included
# It also builds the paper (with its appendix) and the online appendix from the text in Paper/Text
# Must be run after the summary stats, the regressions and regression stats do files and r scripts, since it only reads their output. 00_Master.do runs it last

#===============================================================================
# 1). Preliminary
#===============================================================================

rm(list=ls())
# Close a log left open by an earlier run that stopped partway, same as Contdid_regs.R
while (sink.number() > 0) sink()

# Load packages. tinytex compiles the LaTeX file
options(repos = c(CRAN = "https://cloud.r-project.org"))
want <- c("tinytex")
need <- want[!(want %in% installed.packages()[,"Package"])]
if (length(need)) install.packages(need)
lapply(want, function(i) require(i, character.only=TRUE))
rm(want, need)

# Directories, same as the other R scripts: the project root is one folder up from Scripts
dir <- list()
dir$root <- dirname(getwd())
# If the project root is not one folder up from the working folder, go up from the working folder until the folder that has Scripts/00_Master.do
if (!dir.exists(paste(dir$root,"/Data",sep=""))) {
  dir$root <- getwd()
  while (!file.exists(paste(dir$root,"/Scripts/00_Master.do",sep="")) && dirname(dir$root) != dir$root) dir$root <- dirname(dir$root)
  if (!file.exists(paste(dir$root,"/Scripts/00_Master.do",sep=""))) stop("Project folder not found. Set the working directory to the Scripts folder (open MS Thesis.Rproj) or run 00_Master.do")
}
dir$paper <- paste(dir$root,"/Paper",sep="")
dir$tables <- paste(dir$root,"/Output/Tables",sep="")
dir$figures <- paste(dir$root,"/Output/Figures",sep="")
dir$output_logs <- paste(dir$root,"/Output/Logs",sep="")
dir.create(dir$paper, recursive = TRUE, showWarnings = FALSE)
for (s in c("Main","Miscellaneous")) {
  dir.create(paste(dir$output_logs,"/",s,sep=""), recursive = TRUE, showWarnings = FALSE)
}

# Everything printed below is also saved to this log
sink(paste(dir$output_logs,"/Main/build_results.log",sep=""), split = TRUE)

# TinyTeX is installed once if there is no LaTeX on the computer. The usual download link was down in October 2026, so if it fails we take the same
# bundle from TinyTeX's GitHub releases and unpack it where tinytex looks for it
if (!tinytex::is_tinytex() && Sys.which("pdflatex") == "") {
  ok <- tryCatch({tinytex::install_tinytex(); TRUE}, error = function(e) FALSE)
  if (!ok) {
    if (!("jsonlite" %in% installed.packages()[,"Package"])) install.packages("jsonlite")
    os <- ifelse(Sys.info()[["sysname"]] == "Darwin", "darwin", "linux")
    rel <- jsonlite::fromJSON("https://api.github.com/repos/rstudio/tinytex-releases/releases/latest")
    url <- grep(paste0("TinyTeX-1-", os, "-.*\\.tar\\.(xz|gz)$"), rel$assets$browser_download_url, value = TRUE)[1]
    file <- file.path(tempdir(), basename(url))
    download.file(url, file, mode = "wb")
    home <- ifelse(os == "darwin", "~/Library", "~")
    untar(file, exdir = path.expand(home))
  }
}
# Put the TinyTeX programs on the path for this session, so pdflatex is found
if (tinytex::is_tinytex()) {
  bin <- list.dirs(file.path(tinytex::tinytex_root(), "bin"), recursive = FALSE)[1]
  Sys.setenv(PATH = paste(bin, Sys.getenv("PATH"), sep = .Platform$path.sep))
  # The citations and the reference list need these three, so they are installed if they are missing
  for (p in c("biblatex", "biblatex-chicago", "biber")) {
    if (!(p %in% tinytex::tl_pkgs())) tinytex::tlmgr_install(p)
  }
}

#===============================================================================
# 2). Tables
#===============================================================================

# Each table file is its own LaTeX document, so we keep only what is between \begin{document} and \end{document}
# Meaning this function keeps only the middle of each file: the tables themselves, without the setup and ending
table_body <- function(file) {
  lines <- readLines(file, warn = FALSE)
  # This finds which line number holds \begin{document} and similar the end one with \end{document}
  start <- grep("^\\\\begin\\{document\\}", lines)
  end <- grep("^\\\\end\\{document\\}", lines)
  lines[(start + 1):(end - 1)]
}

#===============================================================================
# 3). Figures
#===============================================================================

# NOTE: The main purpose of this is to write the title above each figure in Results.pdf, built from the image's file name
# First defining so lookups that will be used in the function
outcome <- c(haz = "Height-for-Age", waz = "Weight-for-Age", bmiz = "BMI-for-Age")
group <- c(boys = "Boys", girls = "Girls", rural = "Rural Children", urban = "Urban Children", all3 = "Children in All Three Waves", controls = "With Controls")
# Defining the function
figure_title <- function(name) {
  # Breaking apart the file name
  parts <- strsplit(sub("\\.png$", "", name), "_")[[1]]
  # Finding the outcome and group and giving them the appropropriate names
  v <- outcome[parts[parts %in% names(outcome)]]
  g <- group[parts[parts %in% names(group)]]
  # This finds the figure type, whatever's left after removing the outcome and subgroup pieces (i.e. event study)
  base <- paste(parts[!(parts %in% c(names(outcome), names(group)))], collapse = "_")
  # This is basicaly constructing the title
  family <- gsub("_", " ", base)
  if (base == "trends") family <- paste0("Mean ", v, " by Wave, Treated and Control, Binary DID")
  if (base == "event_study") family <- paste0("Event Study, ", v, ", Binary DID")
  if (base == "event_study_ddd") family <- paste0("Triple Difference Event Study, ", v, ", Binary DID")
  if (base == "event_study_severity") family <- paste0("Event Study by Dose Level, ", v, ", Discrete Dose")
  if (base == "contdid_binscatter") family <- paste0("Change in ", v, " by 2009 Rainfall Deficit, Continuous Dose")
  if (base == "contdid_att_clustered") family <- paste0("ATT by 2009 Rainfall Deficit, ", v, ", Continuous Dose")
  if (base == "contdid_acrt_clustered") family <- paste0("ACRT by 2009 Rainfall Deficit, ", v, ", Continuous Dose")
  if (base == "contdid_spi_att_clustered") family <- paste0("ATT by 2009 Rainfall Deficit below z = -1, ", v, ", Continuous Dose")
  if (base == "drought_map_spi") family <- "2009 Rainfall by Municipality, Dose Levels"
  if (base == "drought_map_binary") family <- "2009 Drought by Municipality, Binary DID Treatment"
  if (base == "overlap_pscore") family <- paste0("Overlap of Baseline Characteristics, ", v, ", Dose Groups")
  # This joins the type title and the subgroup with a comma
  paste(c(family, g), collapse = ", ")
}

# Notes under the event study figures, so the sample and specification of each are clear
figure_note <- function(name) {
  fe <- "Child and interview year-month fixed effects, 2005 is the reference wave, and 95\\% confidence intervals use standard errors clustered by 2005 municipality."
  if (grepl("^event_study_severity_.*_all3", name)) return("Moderately dry and severely dry or worse compared with near-normal. The sample is the children in the discrete-dose table who were measured in all three survey waves, so the 2002 lead and the 2009 coefficient come from the same children. Similar to the discrete-dose table, there are no controls. Included are child and survey wave fixed effects. 2005 is the reference wave. 95\\% confidence intervals use standard errors clustered by 2005 municipality.")
  if (grepl("^event_study_severity_", name)) return("Moderately dry and severely dry or worse compared with near-normal. The 2009 coefficients are the same as in the discrete-dose table. Here I include both the 2002 lead and the 2009 coefficient. Similar to the discrete-dose table, there are no controls. Included are child and survey wave fixed effects. 2005 is the reference wave. 95\\% confidence intervals use standard errors clustered by 2005 municipality.")
  if (grepl("^event_study_(haz|waz|bmiz)_controls", name)) return("Drought compared with no drought. The coefficients are on the 2009 drought indicator interacted with the 2002 and 2009 survey waves. The sample is the children in Model 3 of the binary difference-in-differences, in each survey wave in which they are measured. The Model 3 controls are each interacted with the 2002 and 2009 survey waves. Included are child and interview year-month fixed effects. 2005 is the reference wave. 95\\% confidence intervals use standard errors clustered by 2005 municipality.")
  if (grepl("^overlap_pscore_", name)) return("The sample is the children in the discrete-dose regressions. Kernel densities of the propensity score. That is, the predicted probability of being in the dry dose group from a logit on baseline characteristics. Baseline characteristics are the 2002 household controls (electricity, floor, roof, ventilation, rooms per person, log expenditure per person, rural) and the 2005 child and mother controls (sex, full vaccination, mother's height, schooling, age at birth, and employment), and the child's age. Missing values are set to the sample mean and flagged with an indicator. Each panel compares one dry dose group with near-normal (\\ensuremath{-1<z<1}) and is estimated separately. Moderately dry is \\ensuremath{-1.5<z\\le -1}, and severely dry or worse is \\ensuremath{z\\le -1.5}. In each box, children and mean score are shown as dry dose group/near-normal. Outside support is the number of dry dose group children whose score lies below the lowest or above the highest near-normal score.")
  ""
}

# Creating one figure, the title on top and the figure below it, in that order
# The function takes two inputs: the figures subfolder, e.g. "Main" and the image file, e.g. "event_study_waz.png"
figure_block <- function(sub, name) {
  note <- figure_note(name)
  c("\\begin{figure}[H]", "\\centering",
    paste0("\\caption{", figure_title(name), "}"),
    paste0("\\includegraphics[width=0.8\\textwidth]{", name, "}"),
    if (note != "") paste0("\\par\\parbox{0.8\\textwidth}{\\scriptsize \\textit{Notes:} ", note, "}"),
    "\\end{figure}", "")
}

# The figures in each folder: Main (paper), Appendix (appendix in the paper) and Online_Appendix
main_figs <- c("drought_map_spi.png", "event_study_severity_bmiz.png", "event_study_severity_haz.png", "event_study_severity_waz.png",
               "event_study_severity_bmiz_all3.png", "overlap_pscore_bmiz.png")
app_figs <- c("drought_map_binary.png", "event_study_bmiz_controls.png", "event_study_haz_controls.png", "event_study_waz_controls.png",
              "event_study_severity_haz_all3.png", "event_study_severity_waz_all3.png")
online_figs <- c("contdid_binscatter_bmiz.png", "contdid_binscatter_haz.png", "contdid_binscatter_waz.png", "contdid_att_clustered_bmiz.png", "contdid_att_clustered_haz.png", "contdid_att_clustered_waz.png")

#===============================================================================
# 4). Write Results.tex
#===============================================================================

# This builds the whole Results.tex file as one list of text lines and saves it
# It's the step that puts everything together by implementing the document setup, adds a title page, inserts the middles of the table files, the Main figures, the Appendix figures and the online appendix figures, and closes the document
tex <- c("\\documentclass[12pt]{article}", "\\usepackage[margin=1in]{geometry}", "\\usepackage{booktabs}", "\\usepackage{longtable}",
         "\\usepackage{caption}", "\\usepackage{graphicx}", "\\usepackage{float}",
         "\\usepackage{array}", "\\usepackage{lscape}",
         "\\DeclareCaptionLabelSeparator{emdash}{---}", "\\captionsetup{font=normalsize,labelfont=sc,textfont=sc,labelsep=emdash}", "\\captionsetup[figure]{position=top,justification=centering}",
         "\\def\\sym#1{\\ifmmode^{#1}\\else\\(^{#1}\\)\\fi}",
         "\\graphicspath{{../Output/Figures/Main/}{../Output/Figures/Appendix/}{../Output/Figures/Online_Appendix/}{./}}",
         "\\title{Results First Draft}", "\\author{Zachary Serby}", "\\date{\\today}",
         "\\begin{document}", "\\maketitle", "\\thispagestyle{empty}", "\\clearpage", "",
         "\\section*{Main}", "\\subsection*{Summary Statistics}", "",
         table_body(paste(dir$tables,"/Main/summary_stats_did_table.tex",sep="")), "",
         "\\clearpage", "\\subsection*{Regression Results}", "",
         table_body(paste(dir$tables,"/Main/regression_tables_main.tex",sep="")), "",
         "\\clearpage", table_body(paste(dir$tables,"/Main/balance_table.tex",sep="")), "",
         "\\clearpage", unlist(lapply(main_figs, function(f) figure_block("Main", f))),
         "\\clearpage", "\\section*{Appendix}", "",
         table_body(paste(dir$tables,"/Appendix/summary_stats_model3_table.tex",sep="")), "",
         "\\clearpage", table_body(paste(dir$tables,"/Appendix/regression_tables_appendix.tex",sep="")), "",
         "\\clearpage", unlist(lapply(app_figs, function(f) figure_block("Appendix", f))),
         "\\clearpage", "\\section*{Online Appendix}", "",
         table_body(paste(dir$tables,"/Online_Appendix/sample_size_attrition_tables.tex",sep="")), "",
         "\\clearpage", table_body(paste(dir$tables,"/Online_Appendix/regression_tables_online_appendix.tex",sep="")), "",
         "\\clearpage", table_body(paste(dir$tables,"/Online_Appendix/balance_table_online_appendix.tex",sep="")), "",
         "\\clearpage", unlist(lapply(online_figs, function(f) figure_block("Online_Appendix", f))),
         "\\end{document}")
# Writes every line in tex and saves it
writeLines(tex, paste(dir$paper,"/Results.tex",sep=""))
cat("Results.tex written with", length(main_figs), "main figures\n")

#===============================================================================
# 5). Compile Results.pdf
#===============================================================================

# This chunk turns Results.tex into Results.pdf, and cleans up a bit
# It is a function since the paper and the online appendix are compiled the same way below. keep_aux keeps the .aux file, which the paper needs for the online appendix numbers
compile_tex <- function(name, keep_aux = FALSE) {
  setwd(dir$paper)
  # biber is what makes the citations and the reference list
  tinytex::latexmk(paste(name, ".tex", sep=""), engine = "pdflatex", bib_engine = "biber", clean = FALSE)
  # Moves the LaTeX log into the logs folder and deletes the leftover files
  if (file.exists(paste(name, ".log", sep=""))) file.rename(paste(name, ".log", sep=""), paste(dir$output_logs,"/Miscellaneous/", name, "_latex.log",sep=""))
  leftovers <- c(".out", ".fls", ".fdb_latexmk", ".toc", ".bbl", ".bcf", ".blg", ".run.xml")
  if (!keep_aux) leftovers <- c(".aux", leftovers)
  for (f in paste(name, leftovers, sep="")) {
    if (file.exists(f)) file.remove(f)
  }
  cat(paste(name, ".pdf written to", sep=""), dir$paper, "\n")
}
compile_tex("Results")

#===============================================================================
# 6). The paper and the online appendix
#===============================================================================

# This section builds the paper and its own appendix. Additionally it builds the online appendix from the text in Paper/Text
# In the text, each %%TABLE, %%FIGURE and %%FIGROW line is where a table or figure goes. NOTE: We have it so it gets replaced with the one from Output

# Finds which folder the figure is in e.g. Main, Appendix or Online_Appendix
figure_path <- function(name) {
  for (s in c("Main","Appendix","Online_Appendix")) {
    f <- paste(dir$figures,"/",s,"/",name,sep="")
    if (file.exists(f)) return(f)
  }
  stop("Figure not found: ", name)
}

# Creates a function to take one table out of a table file and gets it ready for the paper
# Meaning it adds a label so \ref gives the table number, keeps the table on one page/one panel per page if it is too long, and puts the notes right below it
table_block <- function(file, key, label) {
  lines <- table_body(paste(dir$tables,"/",file,sep=""))
  # Finds the caption of the table, using words from its caption
  cap <- grep(key, lines, fixed = TRUE)
  cap <- cap[grepl("\\caption{", lines[cap], fixed = TRUE)][1]
  if (is.na(cap)) stop("Table not found: ", key, " in ", file)
  # The table starts at the \begingroup or \begin{landscape} before its caption and ends at the \endgroup or \end{landscape} after it
  land <- any(grepl("^\\\\begin\\{landscape\\}", lines[1:cap]))
  open <- ifelse(land, "^\\\\begin\\{landscape\\}", "^\\\\begingroup$")
  close <- ifelse(land, "^\\\\end\\{landscape\\}", "^\\\\endgroup$")
  start <- max(grep(open, lines[1:cap]))
  end <- cap + min(grep(close, lines[(cap + 1):length(lines)]))
  block <- lines[start:end]
  # The label goes right after the caption
  k <- cap - start + 1
  block[k] <- sub("\\\\caption\\{(.*)\\}", paste("\\\\caption{\\1}\\\\label{", label, "}", sep=""), block[k])

  # A longtable can break across pages, so it is changed to a normal table that stays on one page
  lt <- grep("^\\\\begin\\{longtable\\}", block)
  if (length(lt) == 1) {
    capline <- sub("\\\\\\\\\\s*$", "", block[k])
    le <- grep("^\\\\end\\{longtable\\}", block)
    spec <- sub("^\\\\begin\\{longtable\\}", "", block[lt])
    rows <- block[(lt + 1):(le - 1)]
    rows <- rows[rows != block[k]]
    rows <- rows[!(rows %in% c("\\newpage", "\\clearpage"))]
    # Panels start at each toprule. A table with more than 45 rows is split there, one panel per page
    tops <- grep("^\\\\toprule", rows)
    nrows <- sum(grepl("\\\\\\\\\\*?\\s*$", rows))
    starts <- 1
    if (length(tops) > 1 && nrows > 45) starts <- tops
    starts[1] <- 1
    # Panels A and B of the online appendix sample size table fit together on one page
    if (label == "tab:oa_sizes" && length(starts) > 2) starts <- starts[-2]
    ends <- c(starts[-1] - 1, length(rows))
    tabs <- list()
    for (i in seq_along(starts)) {
      panel <- rows[starts[i]:ends[i]]
      # The space between two panels is not needed once they are on separate pages
      if (i < length(starts)) panel <- panel[!grepl("^\\\\addlinespace\\[12pt\\]$", panel)]
      # The notes are taken out of the table and put below it, as wide as the table
      n1 <- grep("\\textit{Notes:}", panel, fixed = TRUE)[1]
      notes <- NULL
      if (!is.na(n1)) {
        n2 <- n1 - 1 + grep("\\}\\\\\\\\\\s*$", panel[n1:length(panel)])[1]
        txt <- paste(panel[n1:n2], collapse = " ")
        # This removes the \multicolumn around the notes
        txt <- sub("^\\\\addlinespace\\[[0-9]+pt\\]\\\\multicolumn\\{[0-9]+\\}\\{p\\{[^}]*\\}\\}\\{", "", txt)
        txt <- sub("\\}\\\\\\\\\\s*$", "", txt)
        notes <- c("\\par\\vspace{4pt}", paste("\\noindent\\makebox[\\textwidth][c]{\\parbox{\\wd\\tblbox}{", txt, "}}%", sep=""))
        panel <- panel[-(n1:n2)]
      }
      # The table goes in a box, so it can be centered if it is a little wider than the text and the notes can use its width
      body <- NULL
      if (any(grepl("\\\\\\\\\\*?\\s*$", panel))) {
        body <- c(paste("\\global\\setbox\\tblbox=\\hbox{\\begin{tabular}", spec, sep=""), panel, "\\end{tabular}}%", "\\makebox[\\textwidth][c]{\\usebox{\\tblbox}}%")
      }
      # A table on one page can move. So the text fills the page around it. The first panel of a split table stays in place, and the later ones start the next page with no title
      pos <- ifelse(length(starts) > 1, "[H]", "[!htbp]")
      if (i == 1) {
        tabs[[i]] <- c(paste("\\begin{table}", pos, "\\centering", sep=""), capline, body, notes, "\\end{table}")
      } else {
        tabs[[i]] <- c("\\clearpage", "\\noindent", body, notes, "\\par\\vspace{\\intextsep}")
      }
    }
    after <- NULL
    if (le < length(block)) after <- block[(le + 1):length(block)]
    block <- c(block[1:(lt - 1)], unlist(tabs), after)
  }

  
  # This basically keeps the font size the same as in the Stata table file, since LaTeX resets it to normal size and the table would come out too big
  # Finds where each table starts
  bt <- grep("^\\\\begin\\{table\\}", block)
  if (length(bt) > 0) {
    # Finds the font size the table file sets before the table
    sz <- grep("^\\\\(tiny|scriptsize|footnotesize|small)\\s*$", block[1:bt[1]], value = TRUE)
    if (length(sz) > 0) {
      for (t in rev(bt)) {
        # Puts the font size right after the caption, so the title stays normal size
        cp <- t - 1 + grep("\\caption{", block[t:min(t + 3, length(block))], fixed = TRUE)[1]
        # If there is no caption, it goes right after \begin{table}
        if (is.na(cp)) cp <- t
        block <- append(block, sz[length(sz)], after = cp)
      }
    }
  }
  

  # Tables keep single spacing in a one and a half spaced document
  # A landscape table always starts a new page, so afterpage puts it after the current page and the text keeps going on the page before. It is centered on its page
  if (land) {
    block <- sub("\\begin{table}[!h]", "\\begin{table}[H]", block, fixed = TRUE)
    bl <- grep("^\\\\begin\\{landscape\\}", block)[1]
    el <- grep("^\\\\end\\{landscape\\}", block)[1]
    block <- c(block[1:bl], "\\vspace*{\\fill}", block[(bl + 1):(el - 1)], "\\vspace*{\\fill}", block[el:length(block)])
    return(c("\\afterpage{\\begingroup\\singlespacing", block, "\\endgroup}", ""))
  }
  c("\\begingroup\\singlespacing", block, "\\endgroup", "")
}

# One figure with its title on top and its notes below. If the line has two files, they are put side by side
paper_figure <- function(file, label, title, notes) {
  files <- strsplit(file, ";")[[1]]
  w <- ifelse(length(files) > 1, "0.48\\textwidth", "0.85\\textwidth")
  # The continuous dose binned scatterplots and ATT figures are all the same size, as wide as two can be next to each other
  if (grepl("^contdid_(binscatter|att_clustered)_", file)) w <- "0.49\\textwidth"
  # [!htbp] lets the figure move, so the text fills the page around it
  c("\\begin{figure}[!htbp]", "\\centering", paste("\\caption{", title, "}\\label{", label, "}", sep=""),
    paste("\\includegraphics[width=", w, "]{", sapply(files, figure_path), "}", sep="", collapse = "\\hfill"),
    if (notes != "") paste("\\par\\parbox{0.85\\textwidth}{\\singlespacing\\scriptsize \\textit{Notes:} ", notes, "}", sep=""),
    "\\end{figure}", "")
}

# Figures side by side on one landscape page, each with its own number and title, and the notes they share below
paper_figrow <- function(files, labels, titles, notes) {
  w <- sprintf("%.2f", 0.98 / length(files))
  rows <- c()
  for (i in seq_along(files)) {
    rows <- c(rows, paste("\\begin{minipage}[t]{", w, "\\linewidth}", sep=""), "\\centering",
              paste("\\captionof{figure}{", titles[i], "}\\label{", labels[i], "}", sep=""),
              paste("\\includegraphics[width=\\linewidth]{", figure_path(files[i]), "}", sep=""), "\\end{minipage}\\hfill")
  }
  # Same as the landscape tables, afterpage puts the page after the current one so the text keeps going
  c("\\afterpage{\\begin{landscape}", "\\vspace*{\\fill}", "\\noindent", rows, "\\par\\vspace{6pt}",
    if (notes != "") paste("\\noindent\\parbox{\\linewidth}{\\singlespacing\\scriptsize \\textit{Notes:} ", notes, "}", sep=""),
    "\\vspace*{\\fill}", "\\end{landscape}}", "")
}

# Makes a landscape page wait one more page, so a nearby table or figure isn't left alone on a page
wait_one_page <- function(x) {
  # Adds a second \afterpage{ at the start
  x[1] <- sub("^\\\\afterpage\\{", "\\\\afterpage{\\\\afterpage{", x[1])
  # Finds the last line that isn't blank and adds a } to close it
  k <- max(which(x != ""))
  x[k] <- paste(x[k], "}", sep="")
  x
}

# Goes through the text file and swaps each %% line for its table or figure
fill_text <- function(file) {
  lines <- readLines(paste(dir$paper,"/Text/",file,sep=""), warn = FALSE, encoding = "UTF-8")
  out <- list()
  # Keeps track of where the tables and figures are, so a landscape page close to one can wait a page
  last_float <- -100
  is_float <- function(x) startsWith(x, "%%FIGURE") || (startsWith(x, "%%TABLE") && !grepl("balance_table", x))
  float_lines <- which(sapply(lines, is_float))
  near_next <- function(j) any(float_lines > j & float_lines - j <= 10)
  for (j in seq_along(lines)) {
    l <- lines[j]
    # Splits the line at each |, e.g. %%TABLE|file|caption words|label
    p <- strsplit(l, "|", fixed = TRUE)[[1]]
    # Blank lines are kept as they are
    if (length(p) == 0) p <- ""
    # A table
    if (p[1] == "%%TABLE") {
      tb <- table_block(p[2], p[3], p[4])
      # If it's landscape and a table or figure is within 10 lines, it waits one more page
      landscape <- grepl("^\\\\afterpage\\{", tb[1])
      if (landscape && (j - last_float <= 10 || near_next(j))) tb <- wait_one_page(tb)
      if (!landscape) last_float <- j
      out[[length(out) + 1]] <- tb
      # One figure
    } else if (p[1] == "%%FIGURE") {
      last_float <- j
      out[[length(out) + 1]] <- paper_figure(p[2], p[3], p[4], ifelse(length(p) > 4, p[5], ""))
      # Figures side by side on a landscape page, which also waits a page if one is close
    } else if (p[1] == "%%FIGROW") {
      fr <- paper_figrow(strsplit(p[2], ";")[[1]], strsplit(p[3], ";")[[1]], strsplit(p[4], ";")[[1]], ifelse(length(p) > 4, p[5], ""))
      if (j - last_float <= 10 || near_next(j)) fr <- wait_one_page(fr)
      out[[length(out) + 1]] <- fr
      # Regular text stays the same
    } else {
      out[[length(out) + 1]] <- l
    }
  }
  unlist(out)
}

# Document setup shared by the paper and the online appendix, formatted like the reference paper
# lscape turns a wide table sideways but keeps the page itself upright in the PDF
paper_preamble <- c("\\documentclass[12pt]{article}", "\\usepackage[margin=1in]{geometry}", "\\usepackage[T1]{fontenc}", "\\usepackage{newtxtext,newtxmath}",
                    # Some publishers put an odd hyphen or apostrophe in their titles, so these print as the normal ones
                    "\\DeclareUnicodeCharacter{2010}{-}", "\\DeclareUnicodeCharacter{05F3}{'}",
                    "\\usepackage{setspace}", "\\onehalfspacing", "\\usepackage{amsmath}", "\\usepackage{booktabs}", "\\usepackage{longtable}", "\\usepackage{array}",
                    "\\usepackage{graphicx}", "\\usepackage{float}", "\\usepackage{lscape}", "\\usepackage{afterpage}", "\\usepackage{placeins}", "\\renewcommand{\\topfraction}{0.9}", "\\renewcommand{\\bottomfraction}{0.8}", "\\renewcommand{\\textfraction}{0.07}", "\\renewcommand{\\floatpagefraction}{0.85}", "\\setcounter{topnumber}{3}", "\\setcounter{totalnumber}{4}", "\\usepackage{caption}", "\\usepackage{adjustbox}",
                    "\\captionsetup{font=normalsize,labelsep=colon}", "\\captionsetup[figure]{position=top,justification=centering}",
                    # The link color is the same blue as the reference paper
                    "\\usepackage{xcolor}", "\\definecolor{linkblue}{cmyk}{0.94,0.54,0,0}",
                    # Citations and the reference list come from Paper/Text/References.bib, in Chicago 17th edition author-date style
                    # The ISSNs, months, DOIs, URLs and handles are left out of the reference list like in the reference papers (References.bib still has them)
                    "\\usepackage[authordate,backend=biber,natbib=false,maxcitenames=3,mincitenames=1,maxbibnames=10,minbibnames=7]{biblatex-chicago}",
                    "\\DeclareSourcemap{\\maps[datatype=bibtex]{\\map{\\step[typesource=software,typetarget=misc]}}}",
                    "\\AtEveryBibitem{\\clearfield{issn}\\clearfield{month}\\clearfield{doi}\\clearfield{url}\\clearfield{urlyear}\\clearfield{eprint}}",
                    "\\addbibresource{Text/References.bib}",
                    "\\usepackage[colorlinks=true,linkcolor=linkblue,citecolor=linkblue,urlcolor=linkblue,filecolor=linkblue,runcolor=linkblue]{hyperref}", "\\usepackage{xurl}",
                    "\\def\\sym#1{\\ifmmode^{#1}\\else\\(^{#1}\\)\\fi}",
                    "\\setlength{\\LTcapwidth}{\\textwidth}",
                    # No words broken across lines with a hyphen, and normal spaces after periods (e.g. "Obs." and "et al.")
                    "\\usepackage{microtype}", "\\newsavebox{\\tblbox}", "\\hyphenpenalty=10000", "\\exhyphenpenalty=10000", "\\emergencystretch=3em", "\\frenchspacing",
                    # So text copied from the PDF keeps its spaces
                    "\\pdfinterwordspaceon")

# The table and figure notes from the Stata and R scripts have their citations typed out
# This chunk changes them to \parencite{...} and \textcite{...}, so they print and link like the citations in the text. The names, years and keys all come from References.bib

# First reading References.bib and splitting it into one entry per paper
bib_txt <- paste(readLines(paste(dir$paper,"/Text/References.bib",sep=""), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
bib_entries <- regmatches(bib_txt, gregexpr("(?s)@\\w+\\{[^,]+,\\n.*?\\n\\}", bib_txt, perl = TRUE))[[1]]

# Takes one author from References.bib and keeps only the last name, e.g. "Maccini, Sharon" is "Maccini"
last_name <- function(author) {
  # Removes extra spaces at the start and end
  author <- trimws(author)
  # Organizations are in braces, e.g. "{INEGI}" is "INEGI"
  if (grepl("^\\{.*\\}$", author)) return(gsub("[{}]", "", author))
  # Names like "de Onis" are written as family=Onis, prefix=de, so this puts them back together
  if (grepl("^family=", author)) {
    family <- sub("^family=([^,]+).*$", "\\1", author)
    prefix <- ""
    if (grepl("prefix=", author)) prefix <- paste(sub("^.*prefix=([^,]+).*$", "\\1", author), " ", sep="")
    return(paste(prefix, family, sep=""))
  }
  # Everyone else is "Last, First", so it keeps what is before the comma
  trimws(sub(",.*$", "", author))
}

# Makes a table of how each paper is cited, its year and its key, e.g. "Maccini and Yang", "2009", macciniWeatherHealthSchooling2009
cite_lookup <- data.frame(name = character(0), year = character(0), key = character(0))
for (entry in bib_entries) {
  # The key is on the first line
  key <- sub("^@\\w+\\{([^,]+),.*$", "\\1", strsplit(entry, "\n")[[1]][1])
  # Gets the authors, or the editors if there are no authors
  who <- regmatches(entry, regexpr("(?m)^  (author|editor) = \\{.*\\},?$", entry, perl = TRUE))
  if (length(who) == 0) next
  who <- sub("^  (author|editor) = \\{(.*)\\},?$", "\\2", who[1])
  # Splits the authors at "and" and keeps each last name
  names_last <- sapply(strsplit(who, " and (?![^{]*\\})", perl = TRUE)[[1]], last_name)
  # Gets the year, or n.d. if there is no date
  date <- regmatches(entry, regexpr("(?m)^  date = \\{(\\d{4})", entry, perl = TRUE))
  year <- "n.d."
  if (length(date) == 1) year <- sub("^.*\\{", "", date)
  # Writes the names like in a citation. Up to three names written out. Four or more as "First et al."
  n <- length(names_last)
  if (n == 1) cite_name <- names_last[1]
  if (n == 2) cite_name <- paste(names_last[1], " and ", names_last[2], sep="")
  if (n == 3) cite_name <- paste(names_last[1], ", ", names_last[2], ", and ", names_last[3], sep="")
  if (n >= 4) cite_name <- paste(names_last[1], " et al.", sep="")
  # Some names come with a curly apostrophe, so a version with a straight one is added too, e.g. Sant’Anna and Sant'Anna
  cite_names <- unique(c(cite_name, gsub(intToUtf8(8217), "'", cite_name, fixed = TRUE)))
  # Adds the paper to the table
  cite_lookup <- rbind(cite_lookup, data.frame(name = cite_names, year = year, key = key))
}

# Finds the keys for a name and its years. If one is not in References.bib, the citation is left as it is
find_keys <- function(name, years) {
  keys <- c()
  for (y in trimws(strsplit(years, ",")[[1]])) {
    k <- cite_lookup$key[cite_lookup$name == name & cite_lookup$year == y]
    if (length(k) == 0) return(NULL)
    keys <- c(keys, k)
  }
  unique(keys)
}

# These are the patterns that find the citations. Longer names go first so "Yang and Choi" is found before "Yang"
all_names <- unique(cite_lookup$name[order(-nchar(cite_lookup$name))])
all_names <- gsub("([][.\\\\|(){}^$*+?])", "\\\\\\1", all_names, perl = TRUE)
years_pattern <- "(?:\\d{4}|n\\.d\\.)(?:, (?:\\d{4}|n\\.d\\.))*"
# One finds a citation inside a parenthesis like Shah and Steinberg 2017, the other one in the text like Currie and Vogl 2013
one_pattern <- paste("^(", paste(all_names, collapse = "|"), "),? (", years_pattern, ")$", sep="")
text_pattern <- paste("(?<![A-Za-z])(", paste(all_names, collapse = "|"), ") \\((", years_pattern, ")\\)", sep="")

# Changes a citation in a parenthesis to \parencite, e.g. Jessoe, Manning, and Taylor 2018 and Shah and Steinberg 2017 in one parenthesis
# It is only changed if every part is a citation, and a word in front like MxFLS is kept in front
paren_cite <- function(paren) {
  parts <- strsplit(substr(paren, 2, nchar(paren) - 1), "; ", fixed = TRUE)[[1]]
  before <- ""
  keys <- c()
  for (i in seq_along(parts)) {
    part <- parts[i]
    if (grepl(one_pattern, part, perl = TRUE)) {
      k <- find_keys(sub(one_pattern, "\\1", part, perl = TRUE), sub(one_pattern, "\\2", part, perl = TRUE))
      if (is.null(k)) return(paren)
      keys <- c(keys, k)
    } else if (i == 1 && !grepl("\\d{4}", part)) {
      before <- part
    } else {
      return(paren)
    }
  }
  if (length(keys) == 0) return(paren)
  keys <- paste(unique(keys), collapse = ",")
  if (before == "") return(paste("\\parencite{", keys, "}", sep=""))
  paste("\\parencite[", before, ";][]{", keys, "}", sep="")
}


# Changes a citation in the text to \textcite, e.g. Currie and Vogl 2013 becomes \textcite{currieEarlyLifeHealthAdult2013}
text_cite <- function(cite) {
  # Finds the key from the names and the year
  k <- find_keys(sub(text_pattern, "\\1", cite, perl = TRUE), sub(text_pattern, "\\2", cite, perl = TRUE))
  # If it is not in References.bib, it is left as it is
  if (is.null(k)) return(cite)
  paste("\\textcite{", paste(k, collapse = ","), "}", sep="")
}

# Creating citations
# Goes through the document line by line, but skips the title page and the captions
convert_cites <- function(doc) {
  skip <- seq_len(which(doc == "\\begin{document}")[1])
  t1 <- grep("^\\\\begin\\{titlepage\\}", doc)
  t2 <- grep("^\\\\end\\{titlepage\\}", doc)
  if (length(t1) == 1 && length(t2) == 1) skip <- c(skip, t1:t2)
  for (k in setdiff(seq_along(doc), skip)) {
    line <- doc[k]
    # Only a line with a year or n.d. can have a citation
    if (grepl("\\caption{", line, fixed = TRUE) || !grepl("(\\d{4}|n\\.d\\.)", line)) next
    # This replaces the parentheses that are citations, and then the citations in the text
    found <- gregexpr("\\([^()]*\\)", line)
    if (found[[1]][1] != -1) regmatches(line, found) <- list(unname(sapply(regmatches(line, found)[[1]], paren_cite)))
    found <- gregexpr(text_pattern, line, perl = TRUE)
    if (found[[1]][1] != -1) regmatches(line, found) <- list(unname(sapply(regmatches(line, found)[[1]], text_cite)))
    doc[k] <- line
  }
  doc
}

# The online appendix is built first, so the paper can use its table and figure numbers and link to them
online <- c(paper_preamble, "\\begin{document}", "", fill_text("Online_Appendix_Text.tex"), "", "\\end{document}")
# Table 1 of the paper in the online appendix notes links to Table 1 in Paper.pdf
online <- gsub("Table~\\ref{tab:sumstats}", "\\href{Paper.pdf\\#tab-sumstats}{Table~1} of the paper", online, fixed = TRUE)
# The online appendix has no reference list, so a citation there links to that paper in the reference list of Paper.pdf
# These lines go right before \begin{document} and change where the citation links go
bp <- which(online == "\\begin{document}")[1]
online <- append(online, c("\\makeatletter", "\\protected\\def\\blx@imc@bibhyperref{\\@ifnextchar[{\\zs@bhr@opt}{\\zs@bhr}}", "\\def\\zs@bhr@opt[#1]#2{\\zs@bhr{#2}}",
                           "\\long\\def\\zs@bhr#1{\\href{Paper.pdf\\#cite.0@\\thefield{entrykey}}{#1}}", "\\makeatother"), after = bp - 1)
# Changes the citations in the notes, then saves and compiles the online appendix
online <- convert_cites(online)
writeLines(online, paste(dir$paper,"/Online_Appendix.tex",sep=""), useBytes = TRUE)
compile_tex("Online_Appendix", keep_aux = TRUE)

# This builds the paper with the title page, the text with its tables and figures, the references and the appendix in the paper
# xr-hyper reads Online_Appendix.aux, so the paper can use the online appendix numbers and link to that file. It has to be loaded before hyperref
hy <- grep("{hyperref}", paper_preamble, fixed = TRUE)
paper_pre <- c(paper_preamble[1:(hy - 1)], "\\usepackage{xr-hyper}", paper_preamble[hy:length(paper_preamble)], "\\externaldocument[OA-]{Online_Appendix}[Online_Appendix.pdf]")
paper <- c(paper_pre, "\\begin{document}", "", fill_text("Paper_Text.tex"), "", "\\end{document}")
# Table 1 gets a name, so the online appendix can link to it
paper <- sub("\\label{tab:sumstats}", "\\label{tab:sumstats}\\hypertarget{tab-sumstats}{}", paper, fixed = TRUE)
# Changes the citations in the notes, then saves and compiles the paper
paper <- convert_cites(paper)
writeLines(paper, paste(dir$paper,"/Paper.tex",sep=""), useBytes = TRUE)
compile_tex("Paper")
# The online appendix .aux file is not needed anymore once the paper is done, so remove
if (file.exists(paste(dir$paper,"/Online_Appendix.aux",sep=""))) file.remove(paste(dir$paper,"/Online_Appendix.aux",sep=""))
sink()

# The end
