#!/bin/bash

set -euo pipefail

if [[ -z $LABELS ]]; then
    LABELS=""
else
    LABELS="-l $LABELS"
fi

echo "Waiting for Argo Workflow to complete"
argo wait @latest -n $ENVIRONMENTS $LABELS
if [[ $? -eq 0 ]]; then
    echo "Argo Workflow submitted successfully"
    argo get @latest -n $ENVIRONMENTS $LABELS
else
    echo "Argo Workflow failed"
    exit 1
fi

