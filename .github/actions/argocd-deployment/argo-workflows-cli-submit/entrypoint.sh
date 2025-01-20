#!/bin/bash

set -euo pipefail

if [[ -f $ARGO_WORKFLOW_FILE ]]; then
    echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
    argo submit $ARGO_WORKFLOW_FILE
    if [[ $? -eq 0 ]]; then
        argo wait @latest -n $ARGO_NAMESPACE
        if [[ $? -eq 0 ]]; then
            echo "Argo Workflow $ARGO_WORKFLOW_FILE submitted successfully"
            argo get @latest -n $ARGO_NAMESPACE
        fi
    fi
else
    echo "File $ARGO_WORKFLOW_FILE not found"
    exit 1
fi