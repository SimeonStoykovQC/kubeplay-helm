#!/bin/bash

set -eox pipefail

kubectl() {
    minikube kubectl -- "$@"
}

update-rolling() {
    # Start the rolling update (assuming you have kubectl configured)
    helm upgrade --install my-release /home/ec2-user/kubeplay-helm \
        --set redeployApplication=$(shuf -i 1000-9999 -n 1) --set redeployRouter=$(shuf -i 1000-9999 -n 1)  # TODO - doesnt work from python, not sure why

    # Monitor the rollout status
    while [[ "$(kubectl rollout status deployment/kubeplay-router-deployment)" != "deployment \"kubeplay-router-deployment\" successfully rolled out" ]]; do
        sleep 1
    done


    for ((i = 0; i < 3; i++)); do
        while [[ "$(kubectl rollout status deployment/kubeplay-application-${i}-deployment)" != "deployment \"kubeplay-application-${i}-deployment\" successfully rolled out" ]]; do
            sleep 1
        done
    done
}

export CONDA_PREFIX=/home/ec2-user/miniforge3/envs/prep
python ./prep-values.py $1

# Define variables
RATE="10"  # Requests per second
OUTPUT_FILE="results.bin"  # Output file for Vegeta results
TEMP_TARGET_FILE="target.tmp"  # Temporary target file for Vegeta

# Create a temporary target file
echo "" > $TEMP_TARGET_FILE
for ((i = 0; i < 12; i++)); do
    echo "GET http://192.168.49.2:30001/get/class${i}" >> "$TEMP_TARGET_FILE"
done

# Start the attack in the background
vegeta attack -targets=$TEMP_TARGET_FILE -rate=$RATE -output=$OUTPUT_FILE > /dev/null &
sleep 1

# Save the PID of the attack
ATTACK_PID=$!

update-rolling

# sleep 10

# Stop the attack
kill -SIGINT $ATTACK_PID

# Generate the report
vegeta report -type=text $OUTPUT_FILE

# Clean up temporary files
rm $TEMP_TARGET_FILE

