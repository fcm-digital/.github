#!/usr/bin/env bash

set -euo pipefail

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
else
    cd helm-chart-$APP_NAME-values-staging/
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
fi

git config user.name github-actions
git config user.email github-actions@github.com
git pull
git add .
git commit -m "MANUAL DEPLOYMENT in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
git push
