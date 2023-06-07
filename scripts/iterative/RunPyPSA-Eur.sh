#!/bin/bash
scenario="$(basename "$(pwd)")"
# Logging info
echo "Starting PyPSA-Eur"
echo "Directory: $1"
echo "Scenario: $scenario"
echo "Iteration: $2"
# Copy REMIND2PyPSA.gdx file to PyPSA resources directory
cp REMIND2PyPSA.gdx ${1}/resources/${scenario}/remind_to_pypsa-eur/i${2}.gdx
# Source micromamba environment
source /home/jhampp/software/micromamba_1.4.2/etc/profile.d/micromamba.sh
# Start PyPSA-Eur
# TODO: Remove remind_scenario=${scenario} from snakemake call
micromamba run --name pypsa-eur snakemake -call --profile ${1}/cluster_config -s ${1}/Snakefile_remind --config remind_scenario=${scenario} -- ${1}/results/${scenario}/pypsa-eur_to_remind/i${2}.gdx
# Copy PyPSA results GDX to REMIND scenario directory
cp ${1}/results/${scenario}/pypsa-eur_to_remind/i${2}.gdx PyPSA2REMIND.gdx