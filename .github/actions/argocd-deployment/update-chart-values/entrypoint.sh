#!/usr/bin/env bash

set -euo pipefail

cd helm-chart-$APP_NAME-values/

git status
ls -la

echo "Env to deploy: $ENV_TO_DEPLOY"

# The branch name cannot start with 'prod'.
if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'prod'"
    exit 1
fi

# The branch name can only start with 'master' or 'main' if the branch is MASTER/MAIN ref.
if [[ "$ENV_TO_DEPLOY" == "master" && "$BRANCH_NAME" != "master" ]] || [[ "$ENV_TO_DEPLOY" == "main" && "$BRANCH_NAME" != "main" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'master' or 'main'"
    exit 1
fi

# Iter over all values-*.yaml files in order to sync thier content with the local values.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    #ToDo: git checkout origin/staging
    for env in $(ls -d -- */); do
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./$env/values-stg-tag.yaml"
        cp -f "../kube/values/$APP_NAME/staging/$env/values-stg.yaml" "./$env/values-stg.yaml"
    done
    cp -f "../kube/values/$APP_NAME/stg/values-stg.yaml" "values-stg.yaml"
else
    if [[ "$ENV_TO_DEPLOY" == "master" && "$BRANCH_NAME" == "master" ]] || [[ "$ENV_TO_DEPLOY" == "main" && "$BRANCH_NAME" == "main" ]]; then
        # Store the currentTag value before the deployment for rollout undo (just in case).
        echo "OLD_IMAGE_TAG=$(cat "./prod/values-prod-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
        cp -f "../kube/values/$APP_NAME/prod/values-prod.yaml" "./prod/values-prod.yaml"
    else
        # Store the currentTag value before the deployment for rollout undo (just in case).
        echo "OLD_IMAGE_TAG=$(cat "./$ENV_TO_DEPLOY/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./$ENV_TO_DEPLOY/values-stg-tag.yaml"
        cp -f "../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml" "./$ENV_TO_DEPLOY/values-stg.yaml"
    fi
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

#ToDo: git checkout origin/master||main if [["$ENV_TO_DEPLOY" == "ALL_ENV"]]