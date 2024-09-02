#!/usr/bin/env bash

argocd_app_sync () {
    echo $RESOURCES
    echo "-------------"
    > diff <(echo "$RESOURCES") <(echo "--resource '*:ConfigMap:itinerary-core-runtime' --resource '*:Service:itinerary-core' --resource '*:Deployment:itinerary-core' --resource '*:Deployment:itinerary-core-worker' --resource '*:Job:itinerary-core-migrations-9beb5c7f-a2d36a52' --resource '*:Job:itinerary-core-migrations-ac35dd88-b070e042' --resource '*:Job:itinerary-core-setup-qs-65493135-09865235' --resource '*:Job:itinerary-core-setup-qs-9beb5c7f-a2d36a52' --resource '*:Job:itinerary-core-setup-qs-f81bd187-f4620b72' --resource '*:Ingress:itinerary-core' --resource '*:OnePasswordItem:itinerary-core-approvals-auth-token' --resource '*:OnePasswordItem:itinerary-core-appsignal-push-api-key' --resource '*:OnePasswordItem:itinerary-core-company-editor-master-key' --resource '*:OnePasswordItem:itinerary-core-conferma-api' --resource '*:OnePasswordItem:itinerary-core-db-credentials' --resource '*:OnePasswordItem:itinerary-core-directions-api-key' --resource '*:OnePasswordItem:itinerary-core-idp-keys'")
    echo "-------------"
    argocd app sync $ARGOCD_FULL_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --prune \
        --retry-limit 2 \
        --retry-backoff-duration 5s \
        --retry-backoff-factor 2 --resource '*:ConfigMap:itinerary-core-runtime' --resource '*:Service:itinerary-core'
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