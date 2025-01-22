#!/bin/bash

set -euo pipefail

for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do

    if [ $env == "prod" ]; then
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

    VALUES_LOCAL_FILE=$(find "$VALUES_DIR/$env/" -iname "*.yaml*")
    if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
        for value in $VALUES_LOCAL_FILE; do
            VALUES+=$(echo "-f .$value ")
        done
    fi

    cd ./helm-chart-template
    helm template . -s templates/job.yaml --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "jobs-$env.yaml"

    delimiter="---"
    csplit -zs --suppress-matched "jobs-$env.yaml" /"$delimiter"/ '{*}'

    for file in xx*; do
        file_name=$(< $file grep 'type: ' --max-count=1 | awk '{ print $2 }')
        echo $file_name
        if [ -z "$file_name" ]; then
            rm "$file"
        else
            mv "$file" "${file_name}-${env}.yaml"
        fi
    done

    helm template . -s templates/argo-workflows-orchestration.yaml --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > argo-workflows-$env.yaml

    csplit -zs --suppress-matched argo-workflows-$env.yaml /"$delimiter"/ '{*}'

    for file in xx*; do
        workflow=$(< $file grep "app.kubernetes.io/name: " --max-count=1 | awk '{ print $2 }')
        if [[ "$workflow" == "$WORKFLOW_NAME" ]]; then
            mv "$file" "${WORKFLOW_NAME}-${env}.yaml"
        else
            rm "$file"
        fi
    done

done