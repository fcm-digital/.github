#!/usr/bin/env bash

argocd_app_sync () {
    argocd app sync $ARGOCD_FULL_APP_NAME $RESOURCES $LABELS \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --prune \
        --retry-limit 2 \
        --retry-backoff-duration 5s \
        --retry-backoff-factor 2
        # --apply-out-of-sync-only \ # Only available for release 2.9 or higher
}

argocd_app_wait () {
    argocd app wait $ARGOCD_FULL_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --health
}

if [[ "$ENV_TO_DEPLOY" == "prod" ]] && [[ "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "main" ]]; then
    ARGOCD_FULL_APP_NAME="$APP_NAME-pro-$APP_REGION"
else
    ARGOCD_FULL_APP_NAME="$APP_NAME-$ENV_TO_DEPLOY-stg-$APP_REGION"
fi


ITER=1

until argocd_app_sync </dev/null
do
    if [ $ITER -eq 3 ]; then
        exit 1
    fi

    sleep $((10 * $ITER))s
    ITER=$(($ITER + 1))
done

ITER=1

until argocd_app_wait </dev/null
do
    if [ $ITER -eq 3 ]; then
        exit 1
    fi

    sleep $((10 * $ITER))s
    ITER=$(($ITER + 1))
done