#!/bin/bash

#SBATCH --qos=priority
#SBATCH --job-name=REMIND-PyPSA-Eur_Validation
#SBATCH --output=%x-%j.out
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --mem=32000

# Check if any jobs with the same name in the same directory are running
job_name="REMIND-PyPSA-Eur_Validation"
current_dir=$(basename "$PWD")
current_job_id=$SLURM_JOB_ID
running_jobs=$(squeue -u $USER -o "%.18i %.50j %.200Z %.2t" | grep "$job_name" | grep "$current_dir" | awk -v current_job_id="$current_job_id" '$1 != current_job_id && ($4 == "R" || $4 == "PD") {print $1}')

if [[ ! -z "$running_jobs" ]]; then
    echo "The REMIND-PyPSA-Eur Validation is still running or pending in job $running_jobs. Exiting."
    exit 1
fi

echo "Rendering REMIND-PyPSA-Eur Validation"
Rscript -e "rmarkdown::render(input = 'REMIND-PyPSA-Eur_Validation.Rmd', output_file = paste0('REMIND-PyPSA-Eur_Validation_', basename(getwd()), '.pdf'));"