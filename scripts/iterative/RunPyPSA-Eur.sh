#!/bin/bash
scenario="$(basename "$(pwd)")"
directory="${1}"
iteration="${2}"
# Define PIK HPC profile and conda environment
# TODO: Move somewhere else
hpc_profile="${directory}/pik_hpc_profile"
conda_env="pypsa-eur-20241119"
# Logging info for main log.txt in REMIND
echo "PyPSA log: Directory ${directory}"
echo "PyPSA log: Scenario ${scenario}"
echo "PyPSA log: Iteration ${iteration}"
# Make copy of REMIND2PyPSAEUR_config.gdx and REMIND2PyPSAEUR.gdx with iteration number
cp REMIND2PyPSAEUR_config.gdx REMIND2PyPSAEUR_config_${iteration}.gdx
cp REMIND2PyPSAEUR.gdx REMIND2PyPSAEUR_${iteration}.gdx
# Copy REMIND2PyPSA_config.gdx and REMIND2PyPSAEUR.gdx to PyPSA resources directory
mkdir -p ${directory}/resources/${scenario}/i${iteration}
cp REMIND2PyPSAEUR.gdx ${directory}/resources/${scenario}/i${iteration}/REMIND2PyPSAEUR.gdx
cp REMIND2PyPSAEUR_config.gdx ${directory}/resources/${scenario}/i${iteration}/REMIND2PyPSAEUR_config.gdx
# Load conda, surpressing output, and activate environment
# TODO: This should probably happen in .profile or .bashrc or so
module load anaconda/2024.10 > /dev/null 2>&1
source activate $conda_env
# Function to check the %QOS on a given partition/QoS combination
# This function rounds down in order to compare integers
check_qos_usage() {
    local qos=$1
    local qos_usage=$(sclass | grep "$qos" | head -n 1 | awk '{print $5}' | sed 's/\..*//')
    echo "$qos_usage"
}
# Define the preferred order of partition/QoS combinations
declare -a PARTITION_QOS_COMBINATIONS=(
    "standard short"
    "standard medium"
    "standard long"
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
        if [[ $qos_usage -lt $qos_threshold || $qos == "priority" ]]; then
            # Set partition and QoS environment variables (read in snakemake profile)
            echo "PyPSA log: Using partition $partition and QOS $qos with usage $qos_usage %"
            export HPC_PARTITION=$partition
            export HPC_QOS=$qos
            # If not priority, set timeout to 20 minutes
            if [[ $qos != "priority" ]]; then
                TIMEOUT=20m
            # If priority, set timeout to 60 minutes
            else
                TIMEOUT=60m
            fi
            used_combinations+=("$combo")
            return 0
        else
            echo "PyPSA log: Skipping partition $partition and QOS $qos with usage $qos_usage %"
            used_combinations+=("$combo")
        fi
    done
}
# Step 1: Create PyPSA-Eur config yaml file
echo "PyPSA log: Creating PyPSA-Eur config yaml file..."
# Attempt to create the config file X times
MAX_ATTEMPTS=2
ATTEMPT=0
CONFIG_FILE="resources/${scenario}/i${iteration}/config.remind_scenario.yaml"
while [[ ! -f "${directory}/${CONFIG_FILE}" && $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    echo "PyPSA log: Attempt $((ATTEMPT + 1)) to create PyPSA config file..."
    snakemake -s "${directory}/Snakefile_REMIND" --directory "${directory}" "${CONFIG_FILE}" >> "log_pypsa_snakemake.txt" 2>&1
    # Increment attempt counter
    ((ATTEMPT++))
    # Sleep for 2 seconds
    sleep 2
done
# Check if the config file was created successfully
if [[ -f "${directory}/${CONFIG_FILE}" ]]; then
    echo "PyPSA log: Successfully created ${directory}/${CONFIG_FILE} in attempt $((ATTEMPT))."
else
    echo "PyPSA log: ERROR, failed to create ${directory}/${CONFIG_FILE} after $ATTEMPT attempts."
    exit 1
fi
# Step 2: Start PyPSA-Eur using the created config file
echo "PyPSA log: Starting PyPSA-Eur..."
# Attempt to create PyPSAEUR2REMIND.gdx X times (due to spurious errors in snakemake)
# See: https://github.com/snakemake/snakemake/issues/3165
MAX_ATTEMPTS=3
ATTEMPT=0
TARGET_FILE="results/${scenario}/i${iteration}/PyPSAEUR2REMIND.gdx"
# Find a suitable partition/QoS combination
find_partition_qos
while [[ ! -f "${directory}/${TARGET_FILE}" && $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    echo "PyPSA log: Attempt $((ATTEMPT + 1)) to run PyPSA-Eur..."
    # Call PyPSA-Eur in background, redirecting output to log file
    snakemake --profile "$hpc_profile" \
        -s "${directory}/Snakefile_REMIND" --directory "${directory}" "${TARGET_FILE}" \
        --configfile "${directory}/${CONFIG_FILE}" >> "log_pypsa_snakemake.txt" 2>&1 &
    snakemake_pid=$!
    # Check every two minutes and move to a different QoS and partition until all jobs are running
    while true; do
        sleep 120
        if ps -p $snakemake_pid > /dev/null; then
            jobs_to_move=$(squeue -u $USER -o "%.18i %.9P %.10Q %.200j %.2t" | grep "scenario=${scenario}" | awk '$5 == "PD" {print $1}')
            num_pending_jobs=$(echo "$jobs_to_move" | wc -l)
            if [[ ! -z "$jobs_to_move" ]]; then
                echo "PyPSA log: Jobs not running after 2 minutes. Moving $num_pending_jobs pending jobs to a different QoS and partition..."
                find_partition_qos
                for jobid in $jobs_to_move; do
                    echo "PyPSA log: Moving job $jobid to qos=$HPC_QOS and partition=$HPC_PARTITION"
                    scontrol update jobid=$jobid qos=$HPC_QOS partition=$HPC_PARTITION
                done
            else
                echo "PyPSA log: All jobs are running."
                break
            fi
        else
            break
        fi
    done
    # Check if the snakemake process is still running before waiting
    if ps -p $snakemake_pid > /dev/null; then
        # Wait for the snakemake process to finish within the timeout limit
        timeout $TIMEOUT bash -c "while ps -p $snakemake_pid > /dev/null; do sleep 10; done"
        # Check if the timeout command was successful and cancel jobs if any
        if [[ $? -eq 124 ]]; then
            echo "PyPSA log: Timeout of ${TIMEOUT} reached. Cancelling remaining jobs and restarting with a different QoS and partition..."
            jobs_to_cancel=$(squeue -u $USER -o "%.18i %.9P %.10Q %.200j" | grep "scenario=${scenario}" | awk '{print $1}')
            if [[ ! -z "$jobs_to_cancel" ]]; then
                for jobid in $jobs_to_cancel; do
                    echo "PyPSA log: Cancelling job $jobid"
                    scancel $jobid
                done
            fi
            # Find a new partition/QoS combination (next available in list)
            find_partition_qos
        fi
    else
        echo "PyPSA log: snakemake process has already finished."
    fi
    # Increment attempt counter
    ((ATTEMPT++))
    # Sleep for 1 second
    sleep 1
done
# Copy PyPSAEUR2REMIND.gdx to REMIND scenario directory if successful
MAX_ATTEMPTS_COPY=5
ATTEMPT_COPY=1
while [ $ATTEMPT_COPY -le $MAX_ATTEMPTS_COPY ]; do
    if [[ -f "${directory}/${TARGET_FILE}" ]]; then
        echo "PyPSA log: Successfully created ${directory}/${TARGET_FILE} in attempt ${ATTEMPT}. Copying to REMIND directory."
        cp "${directory}/results/${scenario}/i${iteration}/PyPSAEUR2REMIND.gdx" PyPSAEUR2REMIND.gdx
        cp PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_${iteration}.gdx
        break
    else
        echo "PyPSA log: PyPSAEUR2REMIND.gdx not found in attempt ${ATTEMPT_COPY}/${MAX_ATTEMPTS_COPY}. Retrying..."
        sleep 2
        ATTEMPT_COPY=$((ATTEMPT_COPY + 1))
    fi
done
# Fallback if file never appeared
if [[ ! -f "${directory}/${TARGET_FILE}" ]]; then
    if [[ -f "PyPSAEUR2REMIND.gdx" ]]; then
        echo "PyPSA log: WARNING, could not create ${TARGET_FILE} after $((ATTEMPT - 1)) attempts, falling back to previous iteration."
    else
        echo "PyPSA log: ERROR, failed to create ${TARGET_FILE} after $((ATTEMPT - 1)) attempts and no previous file is available."
        exit 1
    fi
fi