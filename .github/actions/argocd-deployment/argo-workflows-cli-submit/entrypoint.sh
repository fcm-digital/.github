#!/bin/bash

set -euo pipefail

WORKFLOWS_PATH="./helm-chart-template"

for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do
    ARGO_WORKFLOW_FILE="$WORKFLOWS_PATH/$WORKFLOW_NAME-$env.yaml"
    if [[ -f $ARGO_WORKFLOW_FILE ]]; then
        echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
        if argo submit --watch --log $ARGO_WORKFLOW_FILE -n $env; then
            echo "Argo Workflow $ARGO_WORKFLOW_FILE completed successfully"
            argo get @latest -n $env
        else
            echo "ERROR: Argo Workflow watch failed for $ARGO_WORKFLOW_FILE"
            exit 1
        fi
    else
        echo "ERROR: Argo Workflow file $ARGO_WORKFLOW_FILE not found"
        exit 1
    fi
done
