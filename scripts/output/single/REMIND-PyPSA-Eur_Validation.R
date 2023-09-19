# |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  REMIND License Exception, version 1.0 (see LICENSE file).
# |  Contact: remind@pik-potsdam.de

library(rmarkdown)
library(lucode2)

if(!exists("source_include")) {
  ## Define arguments that can be read from command line
  readArgs("outputdir")
}

# Load config.Rdata
load(file.path(outputdir, "config.Rdata"))

# Get run name with timestamp
scenario <- basename(outputdir)

# Check if run used the PyPSA power module
if (cfg$gms$power == "PyPSA") {
  # Check if iteration gdxes were written
  if (cfg$gms$c_keep_iteration_gdxes == 1){
    # Copy and overwrite REMIND-PyPSA-Eur_Validation.Rmd (if it was changed)
    file.copy(
      from = "scripts/output/single/notebook_templates/REMIND-PyPSA-Eur_Validation.Rmd",
      to = file.path(outputdir, "REMIND-PyPSA-Eur_Validation.Rmd"),
      overwrite = TRUE)
    # Render REMIND-PyPSA-Eur_Validation.Rmd
    rmarkdown::render(input = file.path(outputdir, "REMIND-PyPSA-Eur_Validation.Rmd"),
                      output_dir = outputdir,
                      output_file = paste0("REMIND-PyPSA-Eur_Validation_", scenario, ".pdf"))
  } else {
    stop("This run didn't have c_keep_iteration_gdxes activated.")
    }
} else {
  stop("This run was not coupled to PyPSA.")
}