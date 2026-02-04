#!/usr/bin/env Rscript
# |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  REMIND License Exception, version 1.0 (see LICENSE file).
# |  Contact: remind@pik-potsdam.de
##########################################################
#### REMIND-PyPSA Output Cleanup Utility ####
##########################################################
# Version 1.2
# Type "Rscript purge_remind_pypsa.R" to start the script in the command line

# Import all functions from the scripts/start folder
invisible(sapply(list.files("scripts/start", pattern = "\\.R$", full.names = TRUE), source))

options(error = quote({
  dump.frames(to.file = TRUE)
  traceback()
  q()
}))

suppressPackageStartupMessages({
  require(lucode2, quietly = TRUE)
  require(tools)
})

message("\nStarting REMIND-PyPSA output cleanup...\n")

output_dir <- "output"
delete_dir <- "DELETE"
if (!dir.exists(delete_dir)) dir.create(delete_dir)

# List subfolders in output
subdirs <- list.dirs(output_dir, recursive = FALSE, full.names = FALSE)
if (length(subdirs) == 0) {
  message("No subdirectories found in 'output/'. Nothing to purge.")
  quit()
}

# Prompt user to select which folders to delete
purge_selection <- chooseFromList(subdirs, type = "folders to purge", multiple = TRUE,
                                  returnBoolean = FALSE,
                                  userinfo = "Select folders to move to DELETE. Leave empty to abort.")

if (length(purge_selection) == 0) {
  message("No folders selected. Exiting.")
  quit()
}

for (folder in purge_selection) {
  folder_path <- file.path(output_dir, folder)
  cfg_file <- file.path(folder_path, "config.Rdata")

  message(paste0("\nProcessing folder: ", folder))

  delete_base <- file.path(delete_dir, folder)
  remind_target <- file.path(delete_base, "REMIND")
  pypsa_target_base <- file.path(delete_base, "PyPSA")

  dir.create(remind_target, recursive = TRUE, showWarnings = FALSE)
  dir.create(pypsa_target_base, recursive = TRUE, showWarnings = FALSE)

  # Move PyPSA subfolders if config exists
  if (file.exists(cfg_file)) {
    tryCatch({
      load(cfg_file)  # loads `cfg`
      if (!exists("cfg") || is.null(cfg$gms$c32_pypsa_dir)) {
        warning("config.Rdata found but cfg or cfg$gms$c32_pypsa_dir missing.")
      } else {
        pypsa_path <- cfg$gms$c32_pypsa_dir
        for (subdir in c("resources", "results")) {
          source_path <- file.path(pypsa_path, subdir, folder)
          target_path <- file.path(pypsa_target_base, subdir, folder)

          if (dir.exists(source_path)) {
            dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
            message(paste("Moving", source_path, "->", target_path))
            success <- file.rename(source_path, target_path)
            if (!success) warning(paste("Failed to move", source_path))
          } else {
            message("No matching folder in", subdir, ":", source_path)
          }
        }
      }
    }, error = function(e) {
      warning(paste("Error loading config.Rdata in", folder_path, ":", e$message))
    })
  } else {
    message("No config.Rdata found in: ", folder_path)
  }
  # Move REMIND output folder
  new_remind_path <- file.path(remind_target, folder)
  message(paste("Moving", folder_path, "->", new_remind_path))
  file.rename(folder_path, new_remind_path)
}

message("\nCleanup complete. Selected folders have been moved into 'DELETE/<name>/{REMIND, PyPSA}'.")
