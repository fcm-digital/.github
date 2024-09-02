#!/usr/bin/env bash

argocd_app_get_resources () {

    if [ -n "$RESOURCES_FILTER" ]; then
        FILTER_PARAMS=$( echo inputs.resources_filter | awk '{for(i=1;i<=NF;i++) printf "-e %s ", $i}' )
        local resources_to_sync=$(argocd app resources $ARGOCD_FULL_APP_NAME \
            --server $ARGOCD_URL \
            --auth-token $ARGOCD_AUTH_TOKEN | awk '$NF == "No" {print $(NF-3) "_" $(NF-1)}' | grep $FILTER_PARAMS )

    elif [ -n "$IGNORE_RESOURCES_FILTER" ]; then
        FILTER_PARAMS=$( echo inputs.ignore_resources_filter | awk '{for(i=1;i<=NF;i++) printf "-e %s ", $i}' )
        local resources_to_sync=$(argocd app resources $ARGOCD_FULL_APP_NAME \
            --server $ARGOCD_URL \
            --auth-token $ARGOCD_AUTH_TOKEN | awk '$NF == "No" {print $(NF-3) "_" $(NF-1)}' | grep -v $FILTER_PARAMS )
    else
        echo "resources_filter=" >> $GITHUB_OUTPUT
    fi

    if [ -z "$resources_to_sync" ]; then
        echo "resources_filter=$( echo "$resources_to_sync" | sed 's/_/:/g' | awk '{for(i=1;i<=NF;i++) printf "--resource '"'*:%s'"' ", $i}' )" >> $GITHUB_OUTPUT
    fi
}

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    ARGOCD_FULL_APP_NAME="$APP_NAME-pro-$APP_REGION"
else
    ARGOCD_FULL_APP_NAME="$APP_NAME-$ENV_TO_DEPLOY-stg-$APP_REGION"
fi

ITER=1

until argocd_app_get_resources </dev/null
do
    if [ $ITER -eq 3 ]; then
        exit 1
    fi

    sleep $((10 * $ITER))s
    ITER=$(($ITER + 1))
done
