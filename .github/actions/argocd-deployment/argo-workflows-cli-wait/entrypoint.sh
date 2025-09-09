#!/bin/bash

set -euo pipefail

echo "Waiting for Argo Workflow to complete"

argo wait @latest -n $ENVIRONMENTS
if [[ $? -eq 0 ]]; then
    echo "Argo Workflow submitted successfully"
    argo get @latest -n $ENVIRONMENTS
else
    echo "Argo Workflow failed"
    exit 1
fi

