#!/usr/bin/env bash

set -euo pipefail

# Initialize an empty string to store environments that have been synced
synced_staging_envs=""

# Function to add a new staging environment to the synced environments list
add_synced_staging_envs() {
    local new_staging_env=$1
    if [ -z "$synced_staging_envs" ]; then
        synced_staging_envs="$new_staging_env"
    else
        synced_staging_envs="$synced_staging_envs,$new_staging_env"
    fi
}


# Ensure the branch name is 'master' or 'main' when deploying to 'prod'
if [[ "$ENV_TO_DEPLOY" == "prod" ]] && 
   [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then

    # Check if RELEASE_VERSION is set
    if [[ -z "$RELEASE_VERSION" ]]; then
        echo "The Environment to Deploy cannot be 'prod' if the branches are not 'master' or 'main', and the RELEASE_VERSION is not set."
        exit 1
    fi
fi

# Prevent deployment to 'master' or 'main' environment. There shouldn't be any env with these names.
if [[ "$ENV_TO_DEPLOY" == "master" || "$ENV_TO_DEPLOY" == "main" ]]; then
    echo "The Environment to Deploy cannot be 'master' or 'main'."
    exit 1
fi

# Prevent deployment to 'ALL_ENV' unless on 'master' or 'main' branch
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    echo "It cannot be deployed in All Environments if the branch is not 'master' or 'main'."
    exit 1
fi

# Update DEPLOYED_AT if required
if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
    echo "Updating 'DEPLOYED_AT' env variable at runtime."
    DEPLOYED_AT=$(date -u +"%FT%TZ")
fi

# Sync values files for all environments if deploying to 'ALL_ENV' on 'master' or 'main' branch
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    for env_path in $(ls -d -- ./staging/*/ 2>/dev/null); do
        # Determine the current environment and source file
        export CURRENT_ENV=$(basename "${env_path%/}")
        export CURRENT_SOURCE_FILE=$(echo "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/values-stg.yaml")

        # Check if the source file exists
        if [[ -e $CURRENT_SOURCE_FILE ]]; then
            export CURRENT_IMAGE_TAG=$(cat "./staging/$CURRENT_ENV/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')
            export CURRENT_IMAGE_TAG_ENV=$(cut -d '-' -f 1 <<< $( echo $CURRENT_IMAGE_TAG ))

            # Sync values if the currentTag is an old 'master' image
            if [[ "$CURRENT_IMAGE_TAG_ENV" == "master" || "$CURRENT_IMAGE_TAG_ENV" == "main" || "$CURRENT_IMAGE_TAG_ENV" == "latest" || "$CURRENT_ENV" == "sandbox" ]]; then

                # Skip sandbox deployment if not required
                if [[ $DEPLOY_ON_SANDBOX == false && "$CURRENT_ENV" == "sandbox" ]]; then
                    continue
                fi

                # Update the currentTag if IMAGE_TAG is set
                if [ "$IMAGE_TAG" != "" ]; then
                    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$CURRENT_ENV/values-stg-tag.yaml"
                fi

                # Update DEPLOYED_AT if set
                if [ ! -z ${DEPLOYED_AT+x} ]; then
                    sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" $CURRENT_SOURCE_FILE
                fi

                # Add environment to synced list if required
                if [[ $SYNCED_ENVS_AS_OUTPUTS == true ]]; then
                    add_synced_staging_envs $CURRENT_ENV
                fi

                # Sync values from local to helm-chart repository
                cp --force --recursive "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/" "./staging/"
            fi
        else
            echo "$CURRENT_ENV not found in local code repository, but existing in helm-chart-$APP_NAME-values/staging repository."
        fi
    done
    # Always sync common values-stg.yaml when a Pull Request is closed
    find "./../kube/values/$APP_NAME/staging/*" -maxdepth 1 -type f | xargs -I {} cp {} "./staging/"
    if [ ! -z ${synced_staging_envs+x} ]; then
        echo "synced_staging_envs=$( echo $synced_staging_envs )" >> $GITHUB_OUTPUT
    fi

# Sync common staging values if deploying to 'ONLY_GLOBAL_STG_VALUES' on 'master' or 'main' branch
elif [[ "$ENV_TO_DEPLOY" == "ONLY_COMMON_STG_VALUES" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    find "./../kube/values/$APP_NAME/staging/*" -maxdepth 1 -type f | xargs -I {} cp {} "./staging/"

# Sync prod values if deploying to 'prod' on 'master' or 'main' branch
elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    # Store the currentTag for potential rollback
    echo "old_image_tag=$(cat "./prod/values-prod-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/prod/values-prod.yaml"
    fi
    cp --force --recursive "./../kube/values/$APP_NAME/prod/" "./"

# Sync prod values if deploying to 'prod' for a specific 'release version'
elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ ! -z "$RELEASE_VERSION" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod-$RELEASE_VERSION/values-prod-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/values-prod.yaml"
    fi
    cp --force --recursive "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/" "./"
else
    cd helm-chart-$APP_NAME-values-staging/
    # Store the currentTag for potential rollback
    echo "old_image_tag=$(cat "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml"
    fi
    cp --force --recursive "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/" "./staging/"
fi

# Check for changes and commit if there are any
if [ -z "$(git diff --exit-code)" ]; then
    echo "No changes in the working directory."
else
    git config user.name github-actions
    git config user.email github-actions@github.com
    git pull
    git add .
    # Commit changes with appropriate message
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