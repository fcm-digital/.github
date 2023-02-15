#!/usr/bin/env bash

set -euo pipefail

if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
    cd kube/values/$APP_NAME
elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
    cd helm-chart-template/$APP_NAME
else
    exit 1
fi


if [[ "$ENV_TO_DEPLOY" == "prod" ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'prod'"
    exit 1
fi

if [[ "$ENV_TO_DEPLOY" == "master" && github.ref != 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref != 'refs/heads/main' ]]; then
    echo "The current Branch Name is not allowed. It must NOT start with 'master' or 'main'"
    exit 1
fi


if [[ "$ENV_TO_DEPLOY" == "ALL_ENV" ]]; then
    if [[ github.ref == 'refs/heads/master' ]] || [[ github.ref == 'refs/heads/main' ]]; then
        for env_file in "values-"*; do
            [[ -e "$env_file" ]] || break
            if [[ $env_file != *"prod.yaml" ]]; then
                if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
                    sed -i '{n;s/current_tag:.*/current_tag: '$IMAGE_TAG'/;}' $env_file
                elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
                    cp -f ../../kube/values/$APP_NAME/$env_file $env_file
                else
                    exit 1
                fi
            fi
        done
    fi
else
    if [[ "$ENV_TO_DEPLOY" == "master" && github.ref == 'refs/heads/master' ]] || [[ "$ENV_TO_DEPLOY" == "main" && github.ref == 'refs/heads/main' ]]; then
        VALUES_FILE="values-prod.yaml"
    else
        VALUES_FILE="values-$ENV_TO_DEPLOY.yaml"
    fi

    if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
        echo "OLD_IMAGE_TAG=$(cat $VALUES_FILE | grep current_tag: | cut -d ':' -f 2 | sed 's/ //g')" >> $GITHUB_ENV
        sed -i '{n;s/current_tag:.*/current_tag: '$IMAGE_TAG'/;}' $VALUES_FILE
    elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
        cp -f ../../kube/values/$APP_NAME/$VALUES_FILE $VALUES_FILE
    else
        exit 1
    fi
fi

git status