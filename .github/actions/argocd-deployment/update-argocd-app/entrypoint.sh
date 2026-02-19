#!/usr/bin/env bash

set -euo pipefail

# Initialize an empty string to store environments that have been synced
synced_staging_envs=""

# Function to escape regex metacharacters for use in grep -E patterns
# This prevents regex injection when APP_NAME or APP_REGION contain special characters
# For example, if APP_NAME="my.app", the dot would match any character without escaping
# Special regex characters that need escaping: . * + ? [ ] ( ) { } ^ $ | \
escape_regex() {
    local string="$1"
    # Escape special regex characters by prefixing them with backslash
    echo "$string" | sed 's/[.*+?\[\](){}^$|\\]/\\&/g'
}

# Function to add a new staging environment to the synced environments list
add_synced_staging_envs() {
    local new_staging_env=$1
    if [ -z "$synced_staging_envs" ]; then
        synced_staging_envs="$new_staging_env"
    else
        synced_staging_envs="$synced_staging_envs,$new_staging_env"
    fi
}

# Function to get the ArgoCD app name based on environment
get_argocd_app_name() {
    local env=$1
    if [[ "$env" == "prod" ]]; then
        echo "${APP_NAME}-pro-${APP_REGION}"
    else
        echo "${APP_NAME}-${env}-stg-${APP_REGION}"
    fi
}

# Function to get the current image tag from an ArgoCD app
get_current_image_tag() {
    local argocd_app_name=$1
    local current_tag

    current_tag=$(argocd app get "$argocd_app_name" \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        -o json 2>/dev/null | jq -r '.spec.sources[0].helm.valuesObject.currentTag // "unknown"') || current_tag="unknown"

    echo "$current_tag"
}

# Function to update an ArgoCD app with new image tag and branch
update_argocd_app() {
    local argocd_app_name=$1
    local image_tag=$2
    local branch_name=$3

    echo "Updating ArgoCD app: $argocd_app_name"
    echo "  - Image tag: $image_tag"
    echo "  - Branch (targetRevision): $branch_name"

    # Update the targetRevision of the values source FIRST (source position 2 = second source)
    # This points to the branch in the app's code repository that contains values.yaml
    # Updating branch first is safer - it won't trigger deployment until image tag changes
    if ! argocd app set "$argocd_app_name" \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        --source-position 2 \
        --revision "$branch_name"; then
        echo "  ✗ Failed to update branch revision"
        return 1
    fi

    # Update the image tag SECOND using valuesObject (source position 1 = first source)
    # This triggers the actual deployment change
    if ! argocd app set "$argocd_app_name" \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        --source-position 1 \
        --helm-set-string "currentTag=$image_tag"; then
        echo "  ✗ Failed to update image tag (branch revision was already updated)"
        echo "  ⚠ App may be in inconsistent state - manual intervention may be required"
        return 1
    fi

    echo "  ✓ Updated successfully"
}

# Ensure the branch name is 'master' or 'main' when deploying to 'prod'
if [[ "$ENV_TO_DEPLOY" == "prod" ]] &&
   [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    echo "Error: The Environment to Deploy cannot be 'prod' if the branch is not 'master' or 'main'."
    exit 1
fi

# Prevent deployment to 'master' or 'main' environment. There shouldn't be any env with these names.
if [[ "$ENV_TO_DEPLOY" == "master" || "$ENV_TO_DEPLOY" == "main" ]]; then
    echo "Error: The Environment to Deploy cannot be 'master' or 'main'."
    exit 1
fi

# Prevent deployment to 'ALL_ENV' unless on 'master' or 'main' branch
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]] && [[ "$BRANCH_NAME" != "master" && "$BRANCH_NAME" != "main" ]]; then
    echo "Error: It cannot be deployed in All Environments if the branch is not 'master' or 'main'."
    exit 1
fi

# Handle ALL_ENV deployment (all staging environments)
if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]]; then
    echo "Deploying to ALL staging environments..."

    # Get list of staging apps for this application
    # We query ArgoCD for apps matching the pattern: ${APP_NAME}-*-stg-${APP_REGION}
    # Escape APP_NAME and APP_REGION to prevent regex injection
    escaped_app_name=$(escape_regex "$APP_NAME")
    escaped_app_region=$(escape_regex "$APP_REGION")

    staging_apps=$(argocd app list \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        -o name 2>/dev/null | grep -E "^${escaped_app_name}-.*-stg-${escaped_app_region}$" || true)

    if [[ -z "$staging_apps" ]]; then
        echo "Warning: No staging apps found matching pattern: ${APP_NAME}-*-stg-${APP_REGION}"
        exit 0
    fi

    # Get old image tag from the first app (they should all have the same tag after ALL_ENV deploy)
    first_app=$(echo "$staging_apps" | head -n1)
    old_image_tag=$(get_current_image_tag "$first_app")
    echo "old_image_tag=$old_image_tag" >> "$GITHUB_OUTPUT"

    for argocd_app_name in $staging_apps; do
        # Extract environment from app name: ${APP_NAME}-${ENV}-stg-${APP_REGION}
        env_name=$(echo "$argocd_app_name" | sed "s/^${APP_NAME}-//" | sed "s/-stg-${APP_REGION}$//")

        # Get current image tag to check if we should update this environment
        current_tag=$(get_current_image_tag "$argocd_app_name")
        current_tag_prefix=$(echo "$current_tag" | cut -d '-' -f 1)

        # Only update if current tag is master/main/latest OR if it's sandbox env
        # This prevents overwriting feature branch deployments
        if [[ "$current_tag_prefix" == "master" || "$current_tag_prefix" == "main" || "$current_tag_prefix" == "latest" || "$env_name" == "sandbox" ]]; then
            update_argocd_app "$argocd_app_name" "$IMAGE_TAG" "$BRANCH_NAME"

            if [[ "$SYNCED_ENVS_AS_OUTPUTS" == "true" ]]; then
                add_synced_staging_envs "$env_name"
            fi
        else
            echo "Skipping $argocd_app_name: current tag '$current_tag' is not master/main/latest"
        fi
    done

    # Always write output, even if empty, to prevent downstream failures
    echo "synced_staging_envs=${synced_staging_envs}" >> "$GITHUB_OUTPUT"

# Handle production deployment
elif [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "Deploying to PRODUCTION..."

    argocd_app_name=$(get_argocd_app_name "prod")

    # Get old image tag for potential rollback
    old_image_tag=$(get_current_image_tag "$argocd_app_name")
    echo "old_image_tag=$old_image_tag" >> "$GITHUB_OUTPUT"

    update_argocd_app "$argocd_app_name" "$IMAGE_TAG" "$BRANCH_NAME"

# Handle single staging environment deployment
else
    echo "Deploying to staging environment: $ENV_TO_DEPLOY..."

    argocd_app_name=$(get_argocd_app_name "$ENV_TO_DEPLOY")

    # Get old image tag for potential rollback
    old_image_tag=$(get_current_image_tag "$argocd_app_name")
    echo "old_image_tag=$old_image_tag" >> "$GITHUB_OUTPUT"

    update_argocd_app "$argocd_app_name" "$IMAGE_TAG" "$BRANCH_NAME"

    if [[ "$SYNCED_ENVS_AS_OUTPUTS" == "true" ]]; then
        echo "synced_staging_envs=$ENV_TO_DEPLOY" >> "$GITHUB_OUTPUT"
    fi
fi

echo ""
echo "✓ ArgoCD app update completed successfully"
