#!/bin/bash

#SBATCH --qos=priority
#SBATCH --job-name=REMIND-PyPSA-Eur_Validation
#SBATCH --output=%x-%j.out
#SBATCH --nodes=1
#SBATCH --time=00:05:00

# Logging info
echo "Rendering REMIND-PyPSA-Eur Validation"
echo "PyPSA Directory: ${1}"
Rscript -e "rmarkdown::render('REMIND-PyPSA-Eur_Validation.Rmd', params = list(pyDir = '${1}'));"