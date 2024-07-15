#!/usr/bin/env bash

set -euo pipefail

if [[ "$UPDATE_DEPLOYED_AT" = true ]]; then
    echo "Updating 'DEPLOYED_AT' env variable at runtime."
    DEPLOYED_AT=$(date -u +"%FT%TZ")
fi

if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    cd helm-chart-$APP_NAME-values-prod/
    if [ ! -z ${IMAGE_TAG+x} ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./prod/values-prod-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./prod/values-prod.yaml"
    fi

elif [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]]; then
    cd helm-chart-$APP_NAME-values-staging/
    for env_path in $(ls -d -- ./../kube/values/$APP_NAME/staging/*/); do
        # Get the source of the 'currentTag' environment
        export CURRENT_ENV=$(basename "${env_path%/}")
        export CURRENT_IMAGE_TAG=$(cat "./staging/$CURRENT_ENV/values-stg-tag.yaml" | grep currentTag: | cut -d ':' -f 2 | sed 's/ //g')
        export CURRENT_IMAGE_TAG_ENV=$(cut -d '-' -f 1 <<< $( echo $CURRENT_IMAGE_TAG ))
        export CURRENT_SOURCE_FILE=$(echo "./../kube/values/$APP_NAME/staging/$CURRENT_ENV/values-stg.yaml")

        if [[ -e $CURRENT_SOURCE_FILE ]]; then
            if [[ "$CURRENT_IMAGE_TAG_ENV" == "master" || "$CURRENT_IMAGE_TAG_ENV" == "main" || "$CURRENT_ENV" == "sandbox" ]]; then
                if [ ! -z ${IMAGE_TAG+x} ]; then
                    sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$CURRENT_ENV/values-stg-tag.yaml"
                fi
                if [ ! -z ${DEPLOYED_AT+x} ]; then
                    sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" $CURRENT_SOURCE_FILE
                fi
                cp -f $CURRENT_SOURCE_FILE "./staging/$CURRENT_ENV/values-stg.yaml"
            fi
        else
            echo "$CURRENT_ENV not found in local code repository, but existing in helm-chart-$APP_NAME-values/staging repository."
        fi
    done
else
    cd helm-chart-$APP_NAME-values-staging/
    if [ ! -z ${IMAGE_TAG+x} ]; then
        sed -i "{s/currentTag:.*/currentTag: $IMAGE_TAG/;}" "./staging/$ENV_TO_DEPLOY/values-stg-tag.yaml"
    fi
    if [ ! -z ${DEPLOYED_AT+x} ]; then
        sed -i "{s/DEPLOYED_AT:.*/DEPLOYED_AT: $DEPLOYED_AT/;}" "./staging/$ENV_TO_DEPLOY/values-stg.yaml"
    fi
fi


if [ -z "$(git diff --exit-code)" ]; then
    echo "No changes in the working directory."
else
    git config user.name github-actions
    git config user.email github-actions@github.com
    git pull
    git add .
    git commit -m "MANUAL DEPLOYMENT in ${APP_NAME^^} - $IMAGE_TAG -> [${ENV_TO_DEPLOY^^}]"
    git push
fi



