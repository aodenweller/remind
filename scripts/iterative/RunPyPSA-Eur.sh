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
# Attempt to create PyPSAEUR2REMIND.gdx three times (due to spurious manipulation time errors in snakemake)
# See: https://github.com/snakemake/snakemake/issues/3165
MAX_RETRIES=3
ATTEMPT=0
TARGET_FILE="results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx"
# Loop until file exists or maximum attempts are reached
while [[ ! -f "${1}/${TARGET_FILE}" && $ATTEMPT -lt $MAX_RETRIES ]]; do
    echo "Attempt $((ATTEMPT + 1)) to run PyPSA-Eur..."
    
    conda run --name pypsa-eur-20241119 snakemake --profile "${1}/pik_hpc_profile/" \
        -s "${1}/Snakefile_remind" --directory "${1}" "${TARGET_FILE}"
    
    # Wait one second before next attempt
    sleep 1
    
    # Increment attempt counter
    ((ATTEMPT++))
done
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory if successful
if [[ -f "${1}/${TARGET_FILE}" ]]; then
    echo "Success: ${TARGET_FILE} created. Copying to REMIND directory."
    cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx
    cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${2}.gdx
else
    # If iteration == 1, exit with error
    if [[ $2 -eq 1 ]]; then
        echo "Failed: PyPSAEUR2REMIND.gdx was not created after $MAX_RETRIES attempts in first iteration."
        exit 1
    # Else, echo that previous iteration's results will be used
    else
        echo "Warning: Using previous iteration's PyPSAEUR2REMIND.gdx."
    fi
fi
