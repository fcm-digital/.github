#!/usr/bin/env bash

argocd_delete_resource () {
    local app_name=$1
    local group=$2
    local kind=$3
    local resource_name=$4

    if [ -n "$group" ] && [ -n "$kind" ] && [ -n "$resource_name" ]; then
        local argocd_command="argocd app delete-resource $app_name \
            --server $ARGOCD_URL \
            --auth-token $ARGOCD_AUTH_TOKEN \
            --group $group \
            --kind $kind \
            --resource-name string $resource_name"
        echo "Deleting resource: $resource_name in app: $app_name"
        eval $argocd_command
    else
        echo "RESOURCES to delete not provided."
        exit 1
    fi
}

argocd_app_wait () {
    local app_name=$1
    local argocd_command="argocd app wait $app_name \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --operation"
    eval $argocd_command
}

if [[ "$ENV_TO_DEPLOY" != "prod" ]]; then
    ARGOCD_FULL_APP_NAME="$APP_NAME-$ENV_TO_DEPLOY-stg-$APP_REGION"
else
    echo "ENV_TO_DEPLOY Must not be prod. Not allowed to delete resources in a production environment using ArgoCD CLI."
    exit 1
fi

ITER=1

for resource in "${RESOURCES[@]}" do

    IFS='_'
    read group kind resource_name <<< "$resource"
    until argocd_delete_resource "$ARGOCD_FULL_APP_NAME" "$group" "$kind" "$resource_name" </dev/null
    do
        if [ $ITER -eq 3 ]; then
            exit 1
        fi

        sleep $((10 * $ITER))s
        ITER=$(($ITER + 1))
    done

    ITER=1

    until argocd_app_wait "$ARGOCD_FULL_APP_NAME" </dev/null
    do
        if [ $ITER -eq 3 ]; then
            exit 1
        fi

        sleep $((10 * $ITER))s
        ITER=$(($ITER + 1))
    done
done