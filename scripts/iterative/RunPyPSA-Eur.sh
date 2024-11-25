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
# Source conda environment
module load anaconda/2024.10
# Start PyPSA-Eur
conda run --name pypsa-eur-20241119 snakemake --profile ${1}/pik_hpc_profile/ -s ${1}/Snakefile_remind --directory ${1} results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${2}.gdx