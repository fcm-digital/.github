#!/usr/bin/env bash

set -euo pipefail


synced_staging_envs=""

add_synced_staging_envs() {
    local new_staging_env=$1
    if [ -z "$synced_staging_envs" ]; then
        synced_staging_envs="$new_staging_env"
    else
        synced_staging_envs="$synced_staging_envs,$new_staging_env"
    fi
}


# The branch name can only start with 'master' or 'main' if the branch is MASTER/MAIN ref.
if [[ "$ENV_TO_DEPLOY" == "prod" ]] && 
   [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then

    if [[ -z "$RELEASE_VERSION" ]]; then
        echo "The Environment to Deploy cannot be 'prod' if the branches are not 'master' or 'main', and the RELEASE_VERSION is not set."
        exit 1
    fi
fi

# The Environment name to Deploy cannot be 'master' or 'main'.
if [[ "$ENV_TO_DEPLOY" == "master" || "$ENV_TO_DEPLOY" == "main" ]]; then
    echo "The Environment to Deploy cannot be 'master' or 'main'."
    exit 1
fi

# The Environment name to Deploy cannot be 'ALL_ENV' if the branch is not 'master' or 'main'.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    echo "It cannot be deployed in All Environments if the branch is not 'master' or 'main'."
    exit 1
fi

# Must be updated in each deploy if UPDATE_DEPLOYED_AT is true.
if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
    echo "Updating 'DEPLOYED_AT' env variable at runtime."
    DEPLOYED_AT=$(date -u +"%FT%TZ")
fi

# Iter over all values-*.yaml files in order to sync thier content with the local values.
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    for env_path in $(ls -d -- ./staging/*/ 2>/dev/null); do
        # Get the source of the 'currentTag' environment
        export CURRENT_ENV=$(basename "${env_path%/}")
        export CURRENT_SOURCE_FILE=$(echo "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/values-stg.yaml")

        if [[ -e $CURRENT_SOURCE_FILE ]]; then
            export CURRENT_IMAGE_TAG=$(cat "./staging/$CURRENT_ENV/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')
            export CURRENT_IMAGE_TAG_ENV=$(cut -d '-' -f 1 <<< $( echo $CURRENT_IMAGE_TAG ))
            # Check if the currentTag is an old 'master' image -> Then, sync the values.
            # Sandbox will always be synced when a new 'master' image is deployed.
            if [[ "$CURRENT_IMAGE_TAG_ENV" == "master" || "$CURRENT_IMAGE_TAG_ENV" == "main" || "$CURRENT_ENV" == "sandbox" ]]; then
                if [[ "$CURRENT_IMAGE_TAG" != "$IMAGE_TAG" ]]; then
                    if [ "$IMAGE_TAG" != "" ]; then
                        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$CURRENT_ENV/values-stg-tag.yaml"
                    fi
                    if [ ! -z ${DEPLOYED_AT+x} ]; then
                        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" $CURRENT_SOURCE_FILE
                    fi
                    if [[ $SYNCED_ENVS_AS_OUTPUTS == true ]]; then
                        add_synced_staging_envs $CURRENT_ENV
                        echo $CURRENT_ENV
                        echo $synced_staging_envs
                    fi
                fi
                cp -f -r "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/" "./staging/"
            fi
        else
            echo "$CURRENT_ENV not found in local code repository, but existing in helm-chart-$APP_NAME-values/staging repository."
        fi
    done
    # The values-stg.yaml will always be synced when a Pull Request is closed.
    cp -f "./../kube/values/$APP_NAME/staging/values-stg.yaml" "./staging/values-stg.yaml"
    if [ ! -z ${synced_staging_envs+x} ]; then
        echo "synced_staging_envs=$( echo $synced_staging_envs )" >> $GITHUB_OUTPUT
    fi

elif [[ "$ENV_TO_DEPLOY" == "NO_SYNC" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    cp -f "./../kube/values/$APP_NAME/staging/values-stg.yaml" "./staging/values-stg.yaml"

elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    # Store the currentTag value before the deployment for rollout undo (just in case).
    echo "old_image_tag=$(cat "./prod/values-prod-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/prod/values-prod.yaml"
    fi
    cp -f -r "./../kube/values/$APP_NAME/prod/" "./"
elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ ! -z "$RELEASE_VERSION" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod-$RELEASE_VERSION/values-prod-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/values-prod.yaml"
    fi
    cp -f -r "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/" "./"
else
    cd helm-chart-$APP_NAME-values-staging/
    # Store the currentTag value before the deployment for rollout undo (just in case).
    echo "old_image_tag=$(cat "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml"
    fi
    cp -f -r "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/" "./staging/"
fi

if [ -z "$(git diff --exit-code)" ]; then
    echo "No changes in the working directory."
else
    git config user.name github-actions
    git config user.email github-actions@github.com
    git pull
    git add .
    if [[ $ROLLOUT == true ]]; then
        git commit -m "ROLLOUT UNDO in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
    elif [[ $MANUAL == true ]] && [[ "$IMAGE_TAG" != "" ]]; then
        git commit -m "MANUAL DEPLOYMENT in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}${RELEASE_VERSION:+-$RELEASE_VERSION}]"
    elif [[ $MANUAL == true ]]; then
        git commit -m "MANUAL DEPLOYMENT in ${APP_NAME^^} -> [${ENV_TO_DEPLOY^^}]"
    else
        git commit -m "DEPLOYMENT in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
    fi
    git push
fi