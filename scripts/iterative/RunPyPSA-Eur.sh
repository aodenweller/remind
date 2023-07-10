#!/bin/bash
scenario="$(basename "$(pwd)")"
# Logging info
echo "Starting PyPSA-Eur"
echo "Directory: $1"
echo "Scenario: $scenario"
echo "Iteration: $2"
# Copy REMIND2PyPSA.gdx file to PyPSA resources directory
cp REMIND2PyPSAEUR.gdx ${1}/resources/${scenario}/i${2}/REMIND2PyPSAEUR.gdx
# Source micromamba environment
source /home/jhampp/software/micromamba_1.4.2/etc/profile.d/micromamba.sh
# Start PyPSA-Eur
module load gams/42.1.0
micromamba run --name pypsa-eur-python-3-10 snakemake --profile ${1}/cluster_config/ -call -k -s ${1}/Snakefile_remind results/${scenario}/i${2}/coupling-parameters/PyPSAEUR2REMIND.gdx
module unload gams/42.1.0
# Copy PyPSA results GDX to REMIND scenario directory
cp ${1}/results/${scenario}/i${2}/coupling-parameters/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx