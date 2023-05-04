#!/usr/bin/env bash

set -euo pipefail

cd kube/values/$APP_NAME


# The branch name cannot start with 'prod'.
if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'prod'"
    exit 1
fi

# The branch name can only start with 'master' or 'main' if the branch is MASTER/MAIN ref.
if [[ "$ENV_TO_DEPLOY" == "master" && github.ref != 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref != 'refs/heads/main' ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'master' or 'main'"
    exit 1
fi

# Iter over all values-*.yaml files in order to update their current_tag value with the new deployment tag.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ github.ref == 'refs/heads/master' || github.ref == 'refs/heads/main' ]]; then
    for env_file in "values-stg-"*; do
        [[ -e "$env_file" ]] || break
        if [[ $env_file != *"prod.yaml" ]]; then # Only in staging environments.
            sed -i '{n;s/current_tag:.*/current_tag: '$IMAGE_TAG'/;}' $env_file
        fi
    done
else
    if [[ "$ENV_TO_DEPLOY" == "master" && github.ref == 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref == 'refs/heads/main' ]]; then
        VALUES_FILE="values-prod.yaml"
    else
        VALUES_FILE="values-stg-$ENV_TO_DEPLOY.yaml"
    fi
    # Store the current_tag value before the deployment for rollout undo (just in case).
    echo "OLD_IMAGE_TAG=$(cat $VALUES_FILE | grep current_tag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
    # Replace current_tag value in the current environment
    sed -i '{n;s/current_tag:.*/current_tag: '$IMAGE_TAG'/;}' $VALUES_FILE
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