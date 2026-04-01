#!/usr/bin/env bash
set -euo pipefail

# Required environment variables
: "${APP_NAME:?APP_NAME environment variable is required}"
: "${APP_REGION:?APP_REGION environment variable is required}"
: "${IMAGE_TAG:?IMAGE_TAG environment variable is required}"

echo "Searching for ArgoCD applications with label: app=${APP_NAME}"
echo "Filtering by image tag: ${IMAGE_TAG}"
echo ""

# List all ArgoCD applications using label selector
MATCHING_APPS=$(argocd app list -l "app=${APP_NAME}" -l '!environment!=prod' -o name || true)

if [ -z "$MATCHING_APPS" ]; then
    echo "No applications found with label: app=${APP_NAME}"
    exit 0
fi

echo "Found matching applications:"
echo "$MATCHING_APPS"
echo ""

# Array to store environments with matching image tag
MATCHING_ENVS=()

# Check each application for matching image tag
for app in $MATCHING_APPS; do
    echo "Checking application: $app"
    
    # Get application parameters and look for currentTag
    CURRENT_TAG=$(argocd app get "$app" \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        -o json 2>/dev/null | jq -r '.spec.sources[0].helm.valuesObject.currentTag // ""' || echo "")
    
    if [ -z "$CURRENT_TAG" ]; then
        echo "  ⚠️  No currentTag parameter found"
        continue
    fi
    
    echo "  Current tag: $CURRENT_TAG"
    
    if [ "$CURRENT_TAG" = "$IMAGE_TAG" ] || [ "$CURRENT_TAG" = "${IMAGE_TAG}-*" ]; then
        # Extract environment from app name: APP_NAME-<environment>-stg-APP_REGION
        ENV=$(echo "$app" | sed -E "s/^${APP_NAME}-(.+)-stg-${APP_REGION}$/\1/")
        echo "  ✅ Match found! Environment: $ENV"
        MATCHING_ENVS+=("$ENV")
    else
        echo "  ❌ Tag mismatch"
    fi
    echo ""
done

# Output results
if [ ${#MATCHING_ENVS[@]} -eq 0 ]; then
    echo "No environments found with matching image tag: ${IMAGE_TAG}"
    exit 0
fi

echo "=========================================="
echo "Environments with matching image tag:"
echo "=========================================="
for env in "${MATCHING_ENVS[@]}"; do
    echo "  - $env"
done

# Export as comma-separated list for GitHub Actions
ENVS_CSV=$(IFS=,; echo "${MATCHING_ENVS[*]}")
echo ""
echo "MATCHING_ENVIRONMENTS=${ENVS_CSV}"

# If running in GitHub Actions, set output
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "matching_environments=${ENVS_CSV}" >> "$GITHUB_OUTPUT"
fi
