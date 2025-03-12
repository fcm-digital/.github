#!/usr/bin/env bash

# ============================================================================
# ArgoCD Deployment Script for Helm Chart Values Update
#
# This script updates Helm chart values for ArgoCD deployments based on
# environment, branch name, and other parameters. It handles different
# deployment scenarios including staging, production, and multi-environment
# deployments.
# ============================================================================

# Exit immediately if a command exits with a non-zero status
# Treat unset variables as an error
# Exit if any command in a pipeline fails
set -euo pipefail

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Variable to track environments that have been synchronized
synced_staging_envs=""

# Adds a new staging environment to the list of synced environments
add_synced_staging_envs() {
    local new_staging_env=$1
    if [ -z "$synced_staging_envs" ]; then
        synced_staging_envs="$new_staging_env"
    else
        synced_staging_envs="$synced_staging_envs,$new_staging_env"
    fi
}

# Updates the deployment timestamp if enabled
update_deployment_timestamp() {
    if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
        echo "Updating 'DEPLOYED_AT' env variable at runtime."
        DEPLOYED_AT=$(date -u +"%FT%TZ")
    fi
}

# Updates image tag in the specified values file
update_image_tag() {
    local values_file=$1
    if [ "$IMAGE_TAG" != "" ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "$values_file"
    fi
}

# Updates DEPLOYED_AT timestamp in the specified values file
update_deployed_at() {
    local values_file=$1
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "$values_file"
    fi
}

# Commits and pushes changes to git repository
commit_and_push_changes() {
    if [ -z "$(git diff --exit-code)" ]; then
        echo "No changes in the working directory."
        return 0
    fi

    # Configure git user
    git config user.name github-actions
    git config user.email github-actions@github.com
    git pull
    git add .

    # Create appropriate commit message based on deployment type
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
}

# ============================================================================
# VALIDATION CHECKS
# ============================================================================

# Validate production deployment requirements
if [[ "$ENV_TO_DEPLOY" == "prod" ]] && 
   [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    if [[ -z "$RELEASE_VERSION" ]]; then
        echo "ERROR: Production deployment requires either master/main branch or a RELEASE_VERSION."
        exit 1
    fi
fi

# Prevent deploying to master/main environments
if [[ "$ENV_TO_DEPLOY" == "master" || "$ENV_TO_DEPLOY" == "main" ]]; then
    echo "ERROR: Cannot deploy directly to 'master' or 'main' environments."
    exit 1
fi

# Validate ALL_ENV deployment requirements
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    echo "ERROR: ALL_ENV deployment requires master or main branch."
    exit 1
fi

# Update deployment timestamp if enabled
update_deployment_timestamp

# ============================================================================
# DEPLOYMENT LOGIC
# ============================================================================

# SCENARIO 1: Deploy to ALL staging environments from master/main branch
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    
    # Process each staging environment
    for env_path in $(ls -d -- ./staging/*/ 2>/dev/null); do
        # Extract environment name and source file path
        export CURRENT_ENV=$(basename "${env_path%/}")
        export CURRENT_SOURCE_FILE="./../kube/values/$APP_NAME/staging/$CURRENT_ENV/values-stg.yaml"

        if [[ -e $CURRENT_SOURCE_FILE ]]; then
            # Get current image tag information
            export CURRENT_IMAGE_TAG=$(cat "./staging/$CURRENT_ENV/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')
            export CURRENT_IMAGE_TAG_ENV=$(cut -d '-' -f 1 <<< $( echo $CURRENT_IMAGE_TAG ))

            # Only sync environments with master/main/latest tags or sandbox
            if [[ "$CURRENT_IMAGE_TAG_ENV" == "master" || "$CURRENT_IMAGE_TAG_ENV" == "main" || 
                  "$CURRENT_IMAGE_TAG_ENV" == "latest" || "$CURRENT_ENV" == "sandbox" ]]; then

                # Skip sandbox if disabled
                if [[ $DEPLOY_ON_SANDBOX == false && "$CURRENT_ENV" == "sandbox" ]]; then
                    echo "Skipping sandbox deployment as DEPLOY_ON_SANDBOX is false"
                    continue
                fi

                # Update image tag and deployment timestamp
                update_image_tag "./staging/$CURRENT_ENV/values-stg-tag.yaml"
                update_deployed_at "$CURRENT_SOURCE_FILE"

                # Track synced environments if enabled
                if [[ $SYNCED_ENVS_AS_OUTPUTS == true ]]; then
                    add_synced_staging_envs $CURRENT_ENV
                fi

                # Sync values from local repository to helm chart repository
                echo "Syncing values for environment: $CURRENT_ENV"
                cp -f -r "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/" "./staging/"
            fi
        else
            echo "WARNING: $CURRENT_ENV not found in local code repository, but exists in helm-chart-$APP_NAME-values/staging repository."
        fi
    done
    
    # Always sync the common staging values file
    cp -f "./../kube/values/$APP_NAME/staging/values-stg.yaml" "./staging/values-stg.yaml"
    
    # Output synced environments for GitHub Actions
    if [ ! -z ${synced_staging_envs+x} ]; then
        echo "synced_staging_envs=$( echo $synced_staging_envs )" >> $GITHUB_OUTPUT
    fi

# SCENARIO 2: No sync operation, just update common staging values
elif [[ "$ENV_TO_DEPLOY" == "NO_SYNC" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    echo "Updating only common staging values file"
    cp -f "./../kube/values/$APP_NAME/staging/values-stg.yaml" "./staging/values-stg.yaml"

# SCENARIO 3: Deploy to production from master/main branch
elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    
    # Store current image tag for potential rollback
    echo "old_image_tag=$(cat "./prod/values-prod-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    
    # Update image tag and deployment timestamp
    update_image_tag "./prod/values-prod-tag.yaml"
    update_deployed_at "./../kube/values/$APP_NAME/prod/values-prod.yaml"
    
    # Sync production values
    echo "Syncing production values"
    cp -f -r "./../kube/values/$APP_NAME/prod/" "./"

# SCENARIO 4: Deploy to production with specific release version
elif [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ ! -z "$RELEASE_VERSION" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    
    # Update image tag and deployment timestamp for specific release
    update_image_tag "./prod-$RELEASE_VERSION/values-prod-tag.yaml"
    update_deployed_at "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/values-prod.yaml"
    
    # Sync production values for specific release
    echo "Syncing production values for release: $RELEASE_VERSION"
    cp -f -r "./../kube/values/$APP_NAME/prod-$RELEASE_VERSION/" "./"

# SCENARIO 5: Deploy to specific staging environment
else
    cd helm-chart-$APP_NAME-values-staging/
    
    # Store current image tag for potential rollback
    echo "old_image_tag=$(cat "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_OUTPUT
    
    # Update image tag and deployment timestamp
    update_image_tag "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    update_deployed_at "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/values-stg.yaml"
    
    # Sync values for specific staging environment
    echo "Syncing values for specific staging environment: $ENV_TO_DEPLOY"
    cp -f -r "./../kube/values/$APP_NAME/staging/$ENV_TO_DEPLOY/" "./staging/"
fi

# Commit and push changes to git repository
commit_and_push_changes