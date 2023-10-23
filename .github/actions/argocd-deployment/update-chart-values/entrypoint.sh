#!/usr/bin/env bash

set -euo pipefail


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

if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
    echo "Updating 'DEPLOYED_AT' env variable at runtime."
    DEPLOYED_AT=$(date -u +"%FT%TZ")
fi

# Iter over all values-*.yaml files in order to sync thier content with the local values.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    for env_path in $(ls -d -- ./../kube/values/$APP_NAME/staging/*/); do
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$(basename "${env_path%/}")/values-stg-tag.yaml"
        if [ ! -z ${DEPLOYED_AT+x} ]; then
            sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/staging/$(basename "${env_path%/}")/values-stg.yaml"
        fi
        cp -f "./../kube/values/$APP_NAME/staging/$(basename "${env_path%/}")/values-stg.yaml" "./staging/$(basename "${env_path%/}")/values-stg.yaml"
    done
    cp -f "./../kube/values/$APP_NAME/staging/values-stg.yaml" "./staging/values-stg.yaml"

elif [[ "$ENV_TO_DEPLOY" == "master" && "$BRANCH_NAME" == "master" ]] || [[ "$ENV_TO_DEPLOY" == "main" && "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    # Store the currentTag value before the deployment for rollout undo (just in case).
    echo "OLD_IMAGE_TAG=$(cat "./prod/values-prod-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/prod/values-prod.yaml"
    fi
    cp -f "./../kube/values/$APP_NAME/prod/values-prod.yaml" "./prod/values-prod.yaml"

else
    cd helm-chart-$APP_NAME-values-staging/
    # Store the currentTag value before the deployment for rollout undo (just in case).
    echo "OLD_IMAGE_TAG=$(cat "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml"
    fi
    cp -f "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml" "./staging/$ENV_TO_DEPLOY/values-stg.yaml"
fi

git config user.name github-actions
git config user.email github-actions@github.com
git pull
git add .
if $ROLLOUT; then
    git commit -m "ROLLOUT UNDO in (${APP_NAME^^}) - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
else
    git commit -m "DEPLOYMENT in (${APP_NAME^^}) - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
fi
git push
