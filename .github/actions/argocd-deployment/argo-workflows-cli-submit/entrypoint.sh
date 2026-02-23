#!/bin/bash

set -euo pipefail

WORKFLOWS_PATH="./helm-chart-template"

# Check if ARGO_TOKEN already has Bearer prefix
if [[ ! "$ARGO_TOKEN" =~ ^Bearer\ .+ ]]; then
    echo "Decoding and adding Bearer prefix to ARGO_TOKEN"
    ARGO_TOKEN="Bearer $(echo $ARGO_TOKEN | base64 --decode)"
else
    echo "ARGO_TOKEN already has Bearer prefix, skipping decode"
fi

for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do
    ARGO_WORKFLOW_FILE="$WORKFLOWS_PATH/$WORKFLOW_NAME-$env.yaml"
    if [[ -f $ARGO_WORKFLOW_FILE ]]; then
        echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"

        # Submit workflow and capture the workflow name
        WORKFLOW_NAME_SUBMITTED=$(argo submit $ARGO_WORKFLOW_FILE -n $env -o name)
        if [[ -z "$WORKFLOW_NAME_SUBMITTED" ]]; then
            echo "ERROR: Failed to submit workflow $ARGO_WORKFLOW_FILE"
            exit 1
        fi

        echo "Workflow submitted: $WORKFLOW_NAME_SUBMITTED"
        echo "Waiting for workflow to complete..."

        # argo wait can exit prematurely with non-zero even when the workflow is still
        # running, so we retry until the workflow reaches a terminal phase
        while true; do
            argo wait $WORKFLOW_NAME_SUBMITTED -n $env || true
            WORKFLOW_PHASE=$(argo get $WORKFLOW_NAME_SUBMITTED -n $env -o json | jq -r '.status.phase')
            echo "Workflow phase: $WORKFLOW_PHASE"
            if [[ "$WORKFLOW_PHASE" == "Succeeded" || "$WORKFLOW_PHASE" == "Failed" || "$WORKFLOW_PHASE" == "Error" ]]; then
                break
            fi
            echo "Workflow not yet in terminal state, retrying wait..."
            sleep 5
        done

        argo get $WORKFLOW_NAME_SUBMITTED -n $env
        echo "Retrieving logs..."
        argo logs $WORKFLOW_NAME_SUBMITTED -n $env || echo "Warning: Could not retrieve logs"

        if [[ "$WORKFLOW_PHASE" == "Succeeded" ]]; then
            echo "Argo Workflow $ARGO_WORKFLOW_FILE completed successfully"
            exit 0
        else
            echo "ERROR: Argo Workflow failed for $ARGO_WORKFLOW_FILE (phase: $WORKFLOW_PHASE)"
            exit 1
        fi
    else
        echo "ERROR: Argo Workflow file $ARGO_WORKFLOW_FILE not found"
        exit 1
    fi
done
