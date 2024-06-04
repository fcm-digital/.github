#!/usr/bin/env bash

set -euo pipefail

cd helm-chart-template

HELM_VALUES=""

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find ../kube/values/$APP_NAME/prod -type f -name '*.yaml' -print0)
else
    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find ../kube/values/$APP_NAME/staging -maxdepth 1 -type f -name '*.yaml' -print0)

    while IFS= read -r -d '' file; do
        HELM_VALUES+="-f \"$file\" "
    done < <(find ../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY -type f -name '*.yaml' -print0)
fi

echo "show HELM_VALUES"
echo $HELM_VALUES
ls -la
pwd

helm template . --name-template=$APP_NAME --namespace=$ENV_TO_DEPLOY \
    --set currentTag=$IMAGE_TAG $HELM_VALUES > output-template.yaml

cat output-template.yaml

# kube-linter lint output-template.yaml --exclude non-existent-service-account $EXCLUDE_RULES