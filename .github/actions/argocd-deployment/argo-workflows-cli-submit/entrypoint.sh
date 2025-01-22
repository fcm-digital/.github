#!/bin/bash

set -euo pipefail

WORKFLOWS_PATH="./helm-chart-template"

for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do
    ARGO_WORKFLOW_FILE="$WORKFLOWS_PATH/$ARGO_WORKFLOW_FILE-$env.yaml"
    if [[ -f $WORKFLOW_FILE ]]; then
        echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
        argo submit $ARGO_WORKFLOW_FILE
        if [[ $? -eq 0 ]]; then
            argo wait @latest -n $env
            if [[ $? -eq 0 ]]; then
                echo "Argo Workflow $ARGO_WORKFLOW_FILE submitted successfully"
                argo get @latest -n $env
            fi
        fi
    else
        echo "File $ARGO_WORKFLOW_FILE not found"
        exit 1
    fi
done
