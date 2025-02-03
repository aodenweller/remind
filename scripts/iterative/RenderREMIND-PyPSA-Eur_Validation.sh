#!/bin/bash

#SBATCH --qos=priority
#SBATCH --job-name=REMIND-PyPSA-Eur_Validation
#SBATCH --output=%x-%j.out
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --mem=32000

echo "Rendering REMIND-PyPSA-Eur Validation"
Rscript -e "rmarkdown::render(input = 'REMIND-PyPSA-Eur_Validation.Rmd', output_file = paste0('REMIND-PyPSA-Eur_Validation_', basename(getwd()), '.pdf'));"