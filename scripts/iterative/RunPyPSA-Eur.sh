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
# Function to check the %QOS on a given partition/QoS combination
check_qos_usage() {
    local qos=$1
    qos_usage=$(sclass | grep "$qos" | head -n 1 | awk '{print $5}')
    echo $qos_usage
}
# Define the preferred order of partition/QoS combinations
declare -a PARTITION_QOS_COMBINATIONS=(
    "standard short"
    "standard medium"
    "priority standby"
    "priority priority"
)
# Find a suitable partition/QoS combination
qos_threshold=90
used_combinations=()
# Function to find a partition/QoS combination that is not in the used_combinations list
find_partition_qos() {
    for combo in "${PARTITION_QOS_COMBINATIONS[@]}"; do
        if [[ " ${used_combinations[@]} " =~ " ${combo} " ]]; then
            continue
        fi
        partition=$(echo $combo | awk '{print $1}')
        qos=$(echo $combo | awk '{print $2}')
        qos_usage=$(check_qos_usage $qos)
        qos_usage_check=$(echo "$qos_usage < $qos_threshold" | bc -l)
        if [[ $qos_usage_check -eq 1 || $qos == "priority" ]]; then
            # Set partition and QoS environment variables (read in snakemake profile)
            echo "PyPSA log: Using partition $partition and QOS $qos with usage $qos_usage %"
            export PARTITION=$partition
            export QOS=$qos
            # If not priority, add to used_combinations and set timeout to 20 minutes
            if [[ $qos != "priority" ]]; then
                used_combinations+=("$combo")
                TIMEOUT=20m
            # If priority, set timeout to 60 minutes
            else
                TIMEOUT=60m
            fi
            return 0
        else
            echo "PyPSA log: Skipping partition $partition and QOS $qos with usage $qos_usage %"
        fi
    done
}
# Start PyPSA-Eur
# Attempt to create PyPSAEUR2REMIND.gdx X times (due to spurious errors in snakemake)
# See: https://github.com/snakemake/snakemake/issues/3165
MAX_RETRIES=3
ATTEMPT=0
TARGET_FILE="results/${scenario}/i${2}/PyPSAEUR2REMIND.gdx"
# Find a suitable partition/QoS combination
find_partition_qos
# Loop until file exists or maximum attempts are reached
while [[ ! -f "${1}/${TARGET_FILE}" && $ATTEMPT -lt $MAX_RETRIES ]]; do
    # Log attempt number
    echo "PyPSA log: Attempt $((ATTEMPT + 1)) to run PyPSA-Eur..."
    # Call PyPSA-Eur
    timeout $TIMEOUT conda run --name pypsa-eur-20241119 snakemake --profile ${1}/pik_hpc_profile_bash \
        -s "${1}/Snakefile_remind" --directory "${1}" "${TARGET_FILE}"
    # Check if the timeout command was successful and move jobs if any
    if [[ $? -eq 124 ]]; then
        echo "PyPSA log: Timeout of ${TIMEOUT} reached. Moving jobs to a different QoS and partition..."
        jobs_to_move=$(squeue -u $USER -o "%.18i %.9P %.10Q %.200j" | grep "scenario=${scenario}" | awk '{print $1}')
        # Finda a new partition/QoS combination (next available in list)
        find_partition_qos
        for jobid in $jobs_to_move; do
            scontrol update jobid=$jobid qos=$QOS partition=$PARTITION
        done
    fi
    # Increment attempt counter
    ((ATTEMPT++))
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
