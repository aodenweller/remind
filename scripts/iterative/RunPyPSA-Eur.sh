#!/bin/bash
scenario="$(basename "$(pwd)")"
# Logging info
echo "PyPSA log: Starting PyPSA-Eur"
echo "PyPSA log: Directory: ${1}"
echo "PyPSA log: Scenario: ${scenario}"
echo "PyPSA log: Iteration: ${2}"
# Make copy of REMIND2PyPSAEUR.gdx with iteration number
cp REMIND2PyPSAEUR.gdx REMIND2PyPSAEUR_${2}.gdx
# Copy REMIND2PyPSA.gdx file to PyPSA resources directory
mkdir -p ${1}/resources/${scenario}/i${2}
cp REMIND2PyPSAEUR.gdx ${1}/resources/${scenario}/i${2}/REMIND2PyPSAEUR.gdx
# Source conda environment
module load anaconda/2024.10
# Define initial PIK HPC profile and timeout
profile_folder="${1}/pik_hpc_profile_short"
TIMEOUT=20m
# Function to cancel all remaining jobs with the string "scenario=${scenario}" in the name
cancel_remaining_jobs() {
    jobs_to_cancel=$(squeue -u $USER -o "%.18i %.9P %.10Q %.200j" | grep "scenario=${scenario}")
    if [[ -n "$jobs_to_cancel" ]]; then
        echo "PyPSA log: Cancelling the following remaining jobs"
        echo "$jobs_to_cancel"
        echo "$jobs_to_cancel" | awk '{print $1}' | xargs -r scancel
    fi
}
# Start PyPSA-Eur
# Attempt to create PyPSAEUR2REMIND.gdx X times (due to spurious errors in snakemake and potential timeouts)
# See: https://github.com/snakemake/snakemake/issues/3165
MAX_RETRIES=3
ATTEMPT=0
TARGET_FILE="results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx"
# Loop until file exists or maximum attempts are reached
while [[ ! -f "${1}/${TARGET_FILE}" && $ATTEMPT -lt $MAX_RETRIES ]]; do
    # Log attempt number
    echo "PyPSA log: Attempt $((ATTEMPT + 1)) to run PyPSA-Eur..."
    # Call PyPSA-Eur with a timeout
    timeout ${TIMEOUT} conda run --name pypsa-eur-20241119 snakemake --profile ${profile_folder} \
        -s "${1}/Snakefile_remind" --directory "${1}" "${TARGET_FILE}"
    # Check if the timeout command was successful and cancel remaining jobs if any
    if [[ $? -eq 124 ]]; then
        echo "PyPSA log: Timeout of ${TIMEOUT} reached. Retrying..."
        cancel_remaining_jobs
    fi
    # Increment attempt counter
    ((ATTEMPT++))
    # Change PIK HPC profile to priority after the second attempt
    if [[ $ATTEMPT -eq 2 ]]; then
        echo "PyPSA log: Changing QOS to priority for the next attempt, increasing timeout to 60 minutes..."
        profile_folder="${1}/pik_hpc_profile_priority"
        TIMEOUT=60m
    fi
    # Sleep for 1 second
    sleep 1
done
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory if successful
if [[ -f "${1}/${TARGET_FILE}" ]]; then
    echo "PyPSA log: Successfully created ${TARGET_FILE} in attempt $((ATTEMPT)). Copying to REMIND directory."
    cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND.gdx
    cp ${1}/results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${2}.gdx
else
    # If iteration == 1, exit with error
    if [[ $2 -eq 1 ]]; then
        echo "PyPSA log: ERROR, PyPSAEUR2REMIND.gdx was not created after $MAX_RETRIES attempts in first iteration."
        exit 1
    # Else, echo that previous iteration's results will be used
    else
        echo "PyPSA log: WARNING, using previous iteration's PyPSAEUR2REMIND.gdx."
    fi
fi
