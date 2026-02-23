#!/bin/bash

set -euo pipefail

WORKFLOWS_PATH="./helm-chart-template"

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

        # Wait for workflow to complete
        if argo wait $WORKFLOW_NAME_SUBMITTED -n $env; then
            echo "Argo Workflow $ARGO_WORKFLOW_FILE completed successfully"
            argo get $WORKFLOW_NAME_SUBMITTED -n $env
            echo "Retrieving logs..."
            argo logs $WORKFLOW_NAME_SUBMITTED -n $env || echo "Warning: Could not retrieve logs"
            exit 0
        else
            echo "ERROR: Argo Workflow failed for $ARGO_WORKFLOW_FILE"
            argo get $WORKFLOW_NAME_SUBMITTED -n $env
            exit 1
        fi
    else
        echo "ERROR: Argo Workflow file $ARGO_WORKFLOW_FILE not found"
        exit 1
    fi
done
