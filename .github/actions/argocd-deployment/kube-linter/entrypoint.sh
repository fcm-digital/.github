#!/usr/bin/env bash

set -euo pipefail


HELM_VALUES=""

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    cd kube/values/$APP_NAME/prod

    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find '.' -type f -name '*.yaml' -print0)
else
    cd kube/values/$APP_NAME/staging

    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find '.' -maxdepth 1 -type f -name '*.yaml' -print0)

    cd $ENV_TO_DEPLOY

    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find '.' -type f -name '*.yaml' -print0)
fi

helm template . --name-template=$APP_NAME --namespace=$ENV_TO_DEPLOY \"
    --set currentTag=$IMAGE_TAG $HELM_VALUES > output-template.yaml

kube-linter lint output-template.yaml --exclude non-existent-service-account ${{ inputs.exclude_rules }}