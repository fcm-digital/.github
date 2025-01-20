#!/bin/bash

set -euox pipefail

if [[ -f $ARGO_WORKFLOW_FILE ]]; then
    echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
    argo submit $ARGO_WORKFLOW_FILE
    argo wait @latest -n $ARGO_NAMESPACE
    if [[ $? -eq 0 ]]; then
        echo "Argo Workflow $ARGO_WORKFLOW_FILE submitted successfully"
        ARGO_OUTPUT_STATUS=$(argo get @latest -n $ARGO_NAMESPACE | grep "Status:" | awk '{print $2}')
        if [[ $ARGO_OUTPUT_STATUS == "Succeeded" ]]; then
            echo "Argo Workflow $ARGO_WORKFLOW_FILE completed successfully"
            exit 0
        else
            echo "Argo Workflow $ARGO_WORKFLOW_FILE failed"
            argo get @latest -n $ARGO_NAMESPACE
            exit 1
        fi
    else
        echo "Argo Workflow $ARGO_WORKFLOW_FILE failed"
        exit 1
    fi
else
    echo "File $ARGO_WORKFLOW_FILE not found"
    exit 1
fi