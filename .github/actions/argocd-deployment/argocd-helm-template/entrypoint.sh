#!/bin/bash

set -euo pipefail

for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do
    if [ $env == "prod" ]; then
        VALUES_DIR="./$HELM_CHART_VALUES_PATH/prod"
    else
        VALUES_DIR="./$HELM_CHART_VALUES_PATH/staging"
    fi

    VALUES_GLOBAL_FILE=$(find $VALUES_DIR/ -maxdepth 1 -iname "*.yaml*")
    if [ ! -z "${VALUES_GLOBAL_FILE}" ]; then
        for value in $VALUES_GLOBAL_FILE; do
            VALUES+=$(echo "-f .$value ")
        done
    fi

    if [ $env != "prod" ]; then
        VALUES_LOCAL_FILE=$(find "$VALUES_DIR/$env/" -iname "*.yaml*")
        if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
            for value in $VALUES_LOCAL_FILE; do
                VALUES+=$(echo "-f .$value ")
            done
        fi
    fi

    cd ./$HELM_CHART_TEMPLATE_PATH

    OUTPUT_FILE_NAME="$APP_NAME-$env.yaml"
    if [ ! -z "$TEMPLATE_FILES" ]; then
        TEMPLATE_ARGS=""
        for template in $(echo $TEMPLATE_FILES | tr ',' '\n'); do
            TEMPLATE_ARGS+=" -s templates/$template"
        done
        helm template . $TEMPLATE_ARGS --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "../$OUTPUT_FILE_NAME"
    else
        helm template . --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "../$OUTPUT_FILE_NAME"
    fi
done