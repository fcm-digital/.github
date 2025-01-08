#!/usr/bin/env bash

set -euo pipefail

VALUES=""
WORKFLOW_FILE=$(find "./helm-chart-values/staging/$ENVIRONMENT/" -iname "*$WORKFLOW_NAME*")

if [ -z "${WORKFLOW_FILE}" ]; then
    WORKFLOW_FILE=$(find "./helm-chart-values/staging/" -maxdepth 1 -iname "*$WORKFLOW_NAME*")
fi

if [ -z "${WORKFLOW_FILE}" ]; then
    echo "Workflow file not found"
    exit 1
else
    WORKFLOW_VALUES+=$(echo "-f .$WORKFLOW_FILE ")
fi

echo $WORKFLOW_FILE
echo $WORKFLOW_VALUES


VALUES_GLOBAL_FILE=$(find "./helm-chart-values/staging/" -maxdepth 1 -iname "*global*")
if [ ! -z "${VALUES_GLOBAL_FILE}" ]; then
    VALUES+=$(echo "-f .$VALUES_GLOBAL_FILE ")
fi

VALUES_LOCAL_FILE=$(find "./helm-chart-values/staging/$ENVIRONMENT/" -iname "*global*")
if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
    VALUES+=$(echo "-f .$VALUES_LOCAL_FILE ")
fi

echo $VALUES

for job_name in $(cat "$WORKFLOW_FILE" | grep "manifest_file:" | awk '{ print $2 }'); do
    JOB_VALUES=""
    JOB_GLOBAL_FILE=$(find "./helm-chart-values/staging/" -maxdepth 1 -iname "*$job_name*")
    if [ ! -z "${JOB_GLOBAL_FILE}" ]; then
        JOB_VALUES+=$(echo "-f .$JOB_GLOBAL_FILE")
    fi
    JOB_LOCAL_FILE=$(find "./helm-chart-values/staging/$ENVIRONMENT/" -iname "*$job_name*")
    if [ ! -z "${JOB_LOCAL_FILE}" ]; then
        JOB_VALUES+=$(echo "-f .$JOB_LOCAL_FILE ")
    fi

    if [ ! -z "${JOB_VALUES}" ]; then
        cd ./helm-chart-template
        helm template . --name-template=$APP_NAME --namespace=$ENVIRONMENT $VALUES $JOB_VALUES --set currentTag=$IMAGE_TAG > $job_name
        cd ..
    fi
done

cd ./helm-chart-template
helm template . --name-template=$APP_NAME --namespace=$ENVIRONMENT $VALUES $WORKFLOW_VALUES --set currentTag=$IMAGE_TAG > argo-workflows.yaml
