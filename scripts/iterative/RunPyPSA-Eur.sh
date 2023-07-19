#!/bin/bash
scenario="$(basename "$(pwd)")"
# Logging info
echo "Starting PyPSA-Eur"
echo "Directory: ${1}"
echo "Scenario: ${scenario}"
echo "Iteration: ${2}"
# Make copy of REMIND2PyPSAEUR.gdx with iteration number
cp REMIND2PyPSAEUR.gdx REMIND2PyPSAEUR_${2}.gdx
# Copy REMIND2PyPSA.gdx file to PyPSA resources directory
mkdir -p ${1}/resources/${scenario}/i${2}
cp REMIND2PyPSAEUR.gdx ${1}/resources/${scenario}/i${2}/REMIND2PyPSAEUR.gdx
# Source micromamba environment
source /home/jhampp/software/micromamba_1.4.2/etc/profile.d/micromamba.sh
# Start PyPSA-Eur
module load gams/42.1.0
micromamba run --name pypsa-eur-python-3-10 snakemake --profile ${1}/cluster_config/ -s ${1}/Snakefile_remind --directory ${1} results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx
module unload gams/42.1.0
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${2}.gdx