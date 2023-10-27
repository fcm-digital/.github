#!/usr/bin/env bash

set -euo pipefail

if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
    echo "Updating 'DEPLOYED_AT' env variable at runtime."
    DEPLOYED_AT=$(date -u +"%FT%TZ")
fi

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./prod/values-stg.yaml"
    fi
else
    cd helm-chart-$APP_NAME-values-staging/
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./staging/$ENV_TO_DEPLOY/values-stg.yaml"
    fi
fi

git config user.name github-actions
git config user.email github-actions@github.com
git pull
git add .
git commit -m "MANUAL DEPLOYMENT in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
git push
