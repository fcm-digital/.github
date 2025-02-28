#!/usr/bin/env bash

argocd_app_sync_async() {
    argocd app sync $ARGOCD_FULL_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --prune \
        --retry-limit 3 \
        --retry-backoff-duration 10s \
        --retry-backoff-factor 3 \
        --async
}

for env in $(echo $ENV_TO_DEPLOY | tr ',' '\n'); do
    ARGOCD_FULL_APP_NAME="$APP_NAME-$env-stg-$APP_REGION"

    until argocd_app_sync_async </dev/null
    do
        if [ $ITER -eq 3 ]; then
            exit 1
        fi

        sleep $((10 * $ITER))s
        ITER=$(($ITER + 1))
    done
done