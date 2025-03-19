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

    if [ $env != "prod" ]; then
        VALUES_LOCAL_FILE=$(find "$VALUES_DIR/$env/" -iname "*.yaml*")
        if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
            for value in $VALUES_LOCAL_FILE; do
                VALUES+=$(echo "-f .$value ")
            done
        fi
    fi

    if [ ! -z "$TEMPLATE_FILE" ]; then
        OUTPUT_FILE_NAME="$(echo $TEMPLATE_FILE | awk -F'.' '{print $(NF-1)}' )-$env.yaml"
        helm template ./helm-chart-template -s templates/$TEMPLATE_FILE --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "$OUTPUT_FILE_NAME"
    else
        helm template ./helm-chart-template --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "$env.yaml"
    fi
done