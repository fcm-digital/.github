#!/usr/bin/env bash

if [ $DEBUG ]; then
    set -x
fi

argocd_app_get_manifest () {
    local live_image_tag=$(argocd app manifests $ARGOCD_FULL_APP_NAME \
        --server $ARGOCD_URL \
        --auth-token $ARGOCD_AUTH_TOKEN \
        --source live | grep app.kubernetes.io/version: --max-count=1 | awk '{ print $2 }')

    echo "live_image_tag=$(echo $live_image_tag)" >> $GITHUB_OUTPUT
}

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    ARGOCD_FULL_APP_NAME="$APP_NAME-pro-$APP_REGION"
else
    ARGOCD_FULL_APP_NAME="$APP_NAME-$ENV_TO_DEPLOY-stg-$APP_REGION"
fi


ITER=1

until argocd_app_get_manifest </dev/null
do
    if [ $ITER -eq 3 ]; then
        exit 1
    fi

    sleep $((10 * $ITER))s
    ITER=$(($ITER + 1))
done

exit 0
