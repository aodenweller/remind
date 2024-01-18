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
# TODO: Remove hard-coded path and move micromamba away from personal directory
export MAMBA_EXE='/p/tmp/adrianod/software/micromamba_20240118/micromamba'
export MAMBA_ROOT_PREFIX='/p/tmp/adrianod/software/micromamba_20240118'
source /p/tmp/adrianod/software/micromamba_20240118/etc/profile.d/micromamba.sh
# Add CPLEX to PATH if not already there
# TODO: Remove hard-coded path and move CPLEX away from personal directory
[[ ":$PATH:" != *":/p/tmp/adrianod/software/cplex_22.1.0/cplex/bin/x86-64_linux:"* ]] && PATH="/p/tmp/adrianod/software/cplex_22.1.0/cplex/bin/x86-64_linux:${PATH}"
# Start PyPSA-Eur
micromamba run --name pypsa-eur-20240118 snakemake --profile ${1}/cluster_config/ -s ${1}/Snakefile_remind --directory ${1} results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx
cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${2}.gdx