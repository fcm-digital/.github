#!/usr/bin/env bash

argocd_app_sync () {
    argocd app sync $ARGOCD_FULL_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --retry-limit 10 \
        --retry-backoff-duration 10s \
        --retry-backoff-factor 2
}


if [[ "$ARGOCD_CURRENT_ENV" == "master" && github.ref == 'refs/heads/master' ]] || [[ "$ARGOCD_CURRENT_ENV" == "main" && github.ref == 'refs/heads/main' ]]; then
    ARGOCD_FULL_APP_NAME="$ARGOCD_APP_NAME-prod-$ARGOCD_APP_REGION"
else
    ARGOCD_FULL_APP_NAME="$ARGOCD_APP_NAME-$ARGOCD_CURRENT_ENV-stg-$ARGOCD_APP_REGION"
fi


ITER=1

until argocd_app_sync </dev/null
do
    if [ $ITER -eq 10 ]; then
        exit 1
    fi

    sleep $((8 * $ITER))s
    ITER=$(($ITER + 1))
done
