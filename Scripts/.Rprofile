# This runs every time R starts in the Scripts folder (opening MS Thesis.Rproj, or when 00_Master.do runs Rscript)
# When R closes, it saves what was typed in the console to Output/Logs/Miscellaneous/R.Rhistory and replaces the last one, so no .Rhistory is left in the folders
.Last <- function() {
  # The project folder is one up from Scripts
  hist_file <- paste(dirname(getwd()),"/Output/Logs/Miscellaneous/R.Rhistory",sep="")
  # Rscript runs from Stata have no history, so this is only for RStudio
  if (interactive() && dir.exists(dirname(hist_file))) try(utils::savehistory(hist_file), silent = TRUE)
}
