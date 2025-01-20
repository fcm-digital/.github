#!/bin/bash

set -euox pipefail

if [[ -f $ARGO_WORKFLOW_FILE ]]; then
    echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
    argo submit $ARGO_WORKFLOW_FILE
    sleep 5s
    argo list
else
    echo "File $ARGO_WORKFLOW_FILE not found"
    exit 1
fi