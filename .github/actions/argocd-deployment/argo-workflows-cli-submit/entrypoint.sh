#!/bin/bash

set -euox pipefail

if [[ -f $ARGO_WORKFLOW_FILE ]]; then
    echo "Submitting Argo Workflow file $ARGO_WORKFLOW_FILE"
    argo submit --from $ARGO_WORKFLOW_FILE
    argo list
else
    echo "File $ARGO_WORKFLOW_FILE not found"
    exit 1
fi