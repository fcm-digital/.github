#!/bin/bash

set -euo pipefail

if [ $ENVIRONMENT == "prod" ]; then
    VALUES_DIR="./helm-chart-values/prod"
else
    VALUES_DIR="./helm-chart-values/staging"
fi

VALUES_GLOBAL_FILE=$(find $VALUES_DIR/ -maxdepth 1 -iname "*.yaml*")
if [ ! -z "${VALUES_GLOBAL_FILE}" ]; then
    for value in $VALUES_GLOBAL_FILE; do
        VALUES+=$(echo "-f .$value ")
    done
fi

VALUES_LOCAL_FILE=$(find "$VALUES_DIR/$ENVIRONMENT/" -iname "*.yaml*")
if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
    for value in $VALUES_LOCAL_FILE; do
        VALUES+=$(echo "-f .$value ")
    done
fi

echo $VALUES

cd ./helm-chart-template
helm template . -s templates/job.yaml --name-template=$APP_NAME --namespace=$ENVIRONMENT $VALUES --set currentTag=$IMAGE_TAG > "jobs-$ENVIRONMENT.yaml"


delimiter="---"
# delimiter="# Source: fcm-platform-helm-chart/templates/job.yaml"
# sed -i 's/---//g' ./kube/values/itinerary-core/jobs.yaml

csplit -zs --suppress-matched "jobs-$ENVIRONMENT.yaml" /"$delimiter"/ '{*}'

ls -la

for file in xx*; do
    file_name=$(cat "$file" | grep 'type: ' --max-count=1 | awk '{ print $2 }')
    if [ -z "$file_name" ]; then
        rm "$file"
    else
        mv "$file" "${file_name}.yaml"
    fi
done

helm template . -s templates/argo-workflows-orchestration.yaml --name-template=$APP_NAME --namespace=$ENVIRONMENT $VALUES --set currentTag=$IMAGE_TAG > argo-workflows.yaml

csplit -zs --suppress-matched argo-workflows.yaml /"$delimiter"/ '{*}'

for file in xx*; do
    workflow=$(cat "$file" | grep "app.kubernetes.io/name: " --max-count=1 | awk '{ print $2 }')
    
    if [[ "$workflow" == "$WORKFLOW_NAME" ]]; then
        mv "$file" "${WORKFLOW_NAME}.yaml"
    else
        rm "$file"
    fi
done