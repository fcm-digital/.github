#!/usr/bin/env bash

argocd_app_sync () {
    argocd app sync $ARGOCD_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --retry-limit 10 \
        --retry-backoff-duration 10s \
        --retry-backoff-factor 2
}

ITER=1

until argocd_app_sync </dev/null
do
    if [ $ITER -eq 10 ]; then
        exit 1
    fi

    sleep $((8 * $ITER))s
    ITER=$(($ITER + 1))
done
