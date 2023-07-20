# |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  REMIND License Exception, version 1.0 (see LICENSE file).
# |  Contact: remind@pik-potsdam.de

library(rmarkdown)

load(file.path(outputdir, "config.Rdata"))

message(paste("Looking for PyPSA output in", cfg$gms$c32_pypsa_dir))

## Check if run used the PyPSA power module
if (cfg$gms$power == "PyPSA") {
  ## Check if iteration gdxes were written
  if (cfg$gms$c_keep_iteration_gdxes == 1){
    # Copy and overwrite REMIND-PyPSA-Eur_Validation.Rmd (if it was changed)
    file.copy(
      from = "scripts/output/single/notebook_templates/REMIND-PyPSA-Eur_Validation.Rmd",
      to = file.path(outputdir, "REMIND-PyPSA-Eur_Validation.Rmd"),
      overwrite = TRUE)
    # Render REMIND-PyPSA-Eur_Validation.Rmd
    rmarkdown::render(
      input = file.path(outputdir, "REMIND-PyPSA-Eur_Validation.Rmd"),
      params = list(pyDir = cfg$gms$c32_pypsa_dir))
  } else {
    stop("This run didn't have c_keep_iteration_gdxes activated.")
    }
} else {
  stop("This run was not coupled to PyPSA.")
}