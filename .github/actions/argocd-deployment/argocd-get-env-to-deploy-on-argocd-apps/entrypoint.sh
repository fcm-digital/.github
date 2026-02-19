#!/usr/bin/env bash

set -euo pipefail

escape_regex() {
    local string=$1
    echo "$string" | sed 's/[.*+?\[\](){}^$|\\]/\\&/g'
}

get_current_tag() {
    local argocd_app_name=$1
    local current_tag=""

    if current_tag=$(argocd app get "$argocd_app_name" \
        --server "$ARGOCD_URL" \
        --auth-token "$ARGOCD_AUTH_TOKEN" \
        -o json 2>/dev/null | jq -r '.spec.sources[0].helm.valuesObject.currentTag // ""'); then
        echo "$current_tag"
    else
        echo ""
    fi
}

is_tag_match() {
    local current_tag=$1
    local sanitized_tag=$2

    if [[ "$current_tag" == "$sanitized_tag" ]]; then
        return 0
    fi

    if [[ "$current_tag" == "$sanitized_tag"-* ]]; then
        return 0
    fi

    return 1
}

escaped_app_name=$(escape_regex "$APP_NAME")
escaped_app_region=$(escape_regex "$APP_REGION")
app_pattern="^${escaped_app_name}-.*-stg-${escaped_app_region}$"

staging_apps=$(argocd app list \
    --server "$ARGOCD_URL" \
    --auth-token "$ARGOCD_AUTH_TOKEN" \
    -o name 2>/dev/null | grep -E "$app_pattern" || true)

if [[ -z "$staging_apps" ]]; then
    echo "OK: No staging ArgoCD apps found for ${APP_NAME} in region ${APP_REGION}"
    exit 0
fi

matched_envs=()

while IFS= read -r argocd_app_name; do
    if [[ -z "$argocd_app_name" ]]; then
        continue
    fi

    current_tag=$(get_current_tag "$argocd_app_name")

    if is_tag_match "$current_tag" "$SANITIZED_TAG"; then
        env_name="${argocd_app_name#${APP_NAME}-}"
        env_name="${env_name%-stg-${APP_REGION}}"
        matched_envs+=("$env_name")
    fi
done <<< "$staging_apps"

if [[ ${#matched_envs[@]} -eq 0 ]]; then
    echo "OK: No environment found for branch ${BRANCH_NAME}"
    exit 0
fi

environments_json=$(printf '%s\n' "${matched_envs[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
environments_human=$(printf '"%s", ' "${matched_envs[@]}")
environments_human="${environments_human%, }"

if [[ ${#matched_envs[@]} -gt 1 ]] && [[ "$ALLOW_MULTIPLE_ENVIRONMENTS" == "false" ]]; then
    echo "Error: More than one environment found for branch ${BRANCH_NAME} -> ${environments_human}"
else
    echo "OK: Environment(s) found for branch ${BRANCH_NAME} -> ${environments_human}"
    echo "env_to_deploy_on=${environments_json}" >> "$GITHUB_OUTPUT"
fi
