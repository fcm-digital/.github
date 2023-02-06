#!/usr/bin/env bash

set -euo pipefail

cd kube/values/$APP_NAME/


if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'prod'"
    exit 1
fi

if [[ "$ENV_TO_DEPLOY" == "master" && github.ref != 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref != 'refs/heads/main' ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'master' or 'main'"
    exit 1
fi

if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]]; then
    for env_file in values-*; do
        [[ -e "$env_file" ]] || break
        if [[ $env_file != *"prod.yaml" ]]; then
            cp -f $env_file ../../../helm-chart-template/$APP_NAME/$env_file
        fi
    done
else
    if [[ "$ENV_TO_DEPLOY" == "master" ]] || [[ "$ENV_TO_DEPLOY" == "main" ]]; then \
        VALUES_FILE="values-prod.yaml"; else VALUES_FILE="values-$ENV_TO_DEPLOY.yaml"; fi

    cp -f $env_file ../../../helm-chart-template/$APP_NAME/$env_file
fi

git config user.name github-actions
git config user.email github-actions@github.com
git pull
git add .
git commit -m "$COMMIT_MSG ($APP_NAME) - $IMAGE_TAG for $ENV_TO_DEPLOY environment"
git push
