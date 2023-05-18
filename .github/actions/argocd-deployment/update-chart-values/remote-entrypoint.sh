#!/usr/bin/env bash

set -euo pipefail

cd helm-chart-template/$APP_NAME


# The branch name cannot start with 'prod'
if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'prod'"
    exit 1
fi

# The branch name can only start with 'master' or 'main' if the branch is MASTER/MAIN ref.
if [[ "$ENV_TO_DEPLOY" == "master" && github.ref != 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref != 'refs/heads/main' ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'master' or 'main'"
    exit 1
fi

# Iter over all values-*.yaml files in order to sync thier content with the local values.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ github.ref == 'refs/heads/master' || github.ref == 'refs/heads/main' ]]; then
    for env_file in "values-stg-"*; do
        [[ -e "$env_file" ]] || break
        if [[ $env_file != *"prod.yaml" ]]; then # Only in staging environments.
            cp -f ../../kube/values/$APP_NAME/$env_file $env_file
        fi
    done
    cp -f ../../kube/values/$APP_NAME/values-stg.yaml values-stg.yaml
else
    if [[ "$ENV_TO_DEPLOY" == "master" && github.ref == 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref == 'refs/heads/main' ]]; then
        cp -f ../../kube/values/$APP_NAME/values.yaml values.yaml
        cp -f ../../kube/values/$APP_NAME/values-stg.yaml values-stg.yaml
        VALUES_FILE="values-prod.yaml"
    else
        VALUES_FILE="values-stg-$ENV_TO_DEPLOY.yaml"
    fi
    # Sync the remote value file with the content with the local values
    cp -f ../../kube/values/$APP_NAME/$VALUES_FILE $VALUES_FILE
fi


git config user.name github-actions
git config user.email github-actions@github.com
git pull
git add .
if $ROLLOUT; then
    git commit -m "Rollout Undo in $APP_NAME - $IMAGE_TAG for $ENV_TO_DEPLOY"
else
    git commit -m "New Deployment in $APP_NAME - $IMAGE_TAG for $ENV_TO_DEPLOY"
fi
git push