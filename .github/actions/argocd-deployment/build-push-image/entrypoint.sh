#!/bin/bash

set -euo pipefail

if [[ -z "${{ inputs.artifact_repository_name }}" ]]; then
    echo "REPO_URL=${{ inputs.artifact_region }}-docker.pkg.dev/fcm-platform-artifacts-ceba/${{ inputs.app_name }}/${{ inputs.app_name }}" >> $GITHUB_ENV
    if [[ "${{ inputs.cache_type }}" == "stage-and-registry" && "${{ inputs.target }}" != "" ]]; then
        echo "REPO_URL_STAGE=${{ inputs.artifact_region }}-docker.pkg.dev/fcm-platform-artifacts-ceba/${{ inputs.app_name }}-${{ inputs.target }}/${{ inputs.app_name }}-${{ inputs.target }}" >> $GITHUB_ENV
    fi
else
    echo "REPO_URL=${{ inputs.artifact_region }}-docker.pkg.dev/fcm-platform-artifacts-ceba/${{ inputs.artifact_repository_name }}/${{ inputs.app_name }}" >> $GITHUB_ENV
    if [[ "${{ inputs.cache_type }}" == "stage-and-registry" && "${{ inputs.target }}" != "" ]]; then
        echo "REPO_URL_STAGE=${{ inputs.artifact_region }}-docker.pkg.dev/fcm-platform-artifacts-ceba/${{ inputs.artifact_repository_name }}-${{ inputs.target }}/${{ inputs.app_name }}-${{ inputs.target }}" >> $GITHUB_ENV
    fi
fi

#! Set up docker-build 'CACHE_FROM'
echo "cache_from_env<<EOF" >> $GITHUB_ENV

if [[ "${{ inputs.cache_type }}" == "registry" ]]; then

    #* 'REGISTRY CACHE' and 'PROD' env -> 'latest-cache'
    if [[ "${{ inputs.branch_name }}" == 'master' || "${{ inputs.branch_name }}" == 'main' ]]; then
        echo "type=registry,ref=${{ env.REPO_URL }}:latest-cache" >> $GITHUB_ENV

    #* 'REGISTRY CACHE' and 'STAGING' env -> 'latest-cache' and 'branch-cache'
    else
        echo "type=registry,ref=${{ env.REPO_URL }}:latest-cache" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL }}:${{ inputs.branch_name }}-cache" >> $GITHUB_ENV
    fi

elif [[ "${{ inputs.cache_type }}" == "stage-and-registry" ]]; then

    #* 'STAGE-AND-REGISTRY CACHE' and 'PROD' env -> 'latest-cache' and 'stage-latest-cache'
    if [[ "${{ inputs.branch_name }}" == 'master' || "${{ inputs.branch_name }}" == 'main' ]]; then
        echo "type=registry,ref=${{ env.REPO_URL }}:latest-cache" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:latest-cache" >> $GITHUB_ENV

    #* 'STAGE-AND-REGISTRY CACHE' and 'STAGING' env -> 'latest-cache', 'stage-latest-cache', 'branch-cache' and 'stage-branch-cache'
    else
        echo "type=registry,ref=${{ env.REPO_URL }}:latest-cache" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL }}:${{ inputs.branch_name }}-cache" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:latest" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:${{ inputs.branch_name }}-cache" >> $GITHUB_ENV
    fi
fi

echo "EOF" >> $GITHUB_ENV

#! Set up docker-build 'STAGE_CACHE_FROM'
echo "stage_cache_from_env<<EOF" >> $GITHUB_ENV

if [[ "${{ inputs.cache_type }}" == "stage-and-registry" && "${{ inputs.target }}" != "" ]]; then
    
    #* 'STAGE-AND-REGISTRY CACHE' and 'PROD' env -> 'latest-cache'
    if [[ "${{ inputs.branch_name }}" == 'master' || "${{ inputs.branch_name }}" == 'main' ]]; then
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:latest-cache" >> $GITHUB_ENV
    
    #* 'STAGE-AND-REGISTRY CACHE' and 'STAGING' env -> 'latest-cache' and 'branch-cache'
    else
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:latest-cache" >> $GITHUB_ENV
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:${{ inputs.branch_name }}-cache" >> $GITHUB_ENV
    fi
fi

echo "EOF" >> $GITHUB_ENV

#! Set up docker-build 'CACHE_TO'

if [[ "${{ inputs.cache_type }}" == "registry" || "${{ inputs.cache_type }}" == "stage-and-registry" ]]; then
    echo "cache_to_env<<EOF" >> $GITHUB_ENV

    #* 'REGISTRY CACHE' or 'STAGE-AND-REGISTRY-CACHE' and 'PROD' env -> 'latest-cache'
    if [[ "${{ inputs.branch_name }}" == 'master' || "${{ inputs.branch_name }}" == 'main' ]]; then
        echo "type=registry,ref=${{ env.REPO_URL }}:latest-cache,mode=max" >> $GITHUB_ENV

    #* 'REGISTRY CACHE' or 'STAGE-AND-REGISTRY-CACHE' and 'STAGING' env -> 'branch-cache'
    else
        echo "type=registry,ref=${{ env.REPO_URL }}:${{ inputs.branch_name }}-cache,mode=max" >> $GITHUB_ENV
    fi

    echo "EOF" >> $GITHUB_ENV
fi

#! Set up docker-build 'STAGE_CACHE_TO'

if [[ "${{ inputs.cache_type }}" == "stage-and-registry" && "${{ inputs.target }}" != "" ]]; then
    echo "stage_cache_to_env<<EOF" >> $GITHUB_ENV

    #* 'STAGE-AND-REGISTRY CACHE' and 'PROD' env -> 'latest-cache'
    if [[ "${{ inputs.branch_name }}" == 'master' || "${{ inputs.branch_name }}" == 'main' ]]; then
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:latest-cache,mode=max" >> $GITHUB_ENV

    #* 'STAGE-AND-REGISTRY CACHE' and 'STAGING' env -> 'branch-cache'
    else
        echo "type=registry,ref=${{ env.REPO_URL_STAGE }}:${{ inputs.branch_name }}-cache,mode=max" >> $GITHUB_ENV
    fi

    echo "EOF" >> $GITHUB_ENV
fi

#! Set up docker-build 'BUILD ARGS'

echo "build_args_env<<EOF" >> $GITHUB_ENV

if [[ -z "$GITHUB_ACTOR" ]]; then
    echo "USER_BUILDER=ArgoCD-Unknown-User" >> $GITHUB_ENV
else
    echo "USER_BUILDER=${GITHUB_ACTOR}" >> $GITHUB_ENV
fi

echo "APP_REVISION=${{ inputs.image_tag }}" >> $GITHUB_ENV
echo "BRANCH=${{ inputs.branch_name }}" >> $GITHUB_ENV
echo "COMMIT_SHA=${{ inputs.commit }}" >> $GITHUB_ENV
echo "COMMIT_AT=${{ inputs.commit_at }}" >> $GITHUB_ENV

for build_arg in $(echo ${{ inputs.build_args }} | tr -d '[:space:][:blank:]' | tr ',' '\n'); do
    echo "${build_arg}" >> $GITHUB_ENV
done

echo "EOF" >> $GITHUB_ENV

#! Set up docker-build 'TAGS'
echo "tags_env<<EOF" >> $GITHUB_ENV

echo "${{ env.REPO_URL }}:${{ inputs.branch_name }}" >> $GITHUB_ENV
echo "${{ env.REPO_URL }}:${{ inputs.image_tag }}" >> $GITHUB_ENV

if [[ inputs.branch_name == 'master' || inputs.branch_name == 'main' ]]; then
    echo "${{ env.REPO_URL }}:latest" >> $GITHUB_ENV
fi

echo "EOF" >> $GITHUB_ENV

#! Set up docker-build 'STAGE_TAGS'
if [[ "${{ inputs.cache_type }}" == "stage-and-registry" && "${{ inputs.target }}" != "" ]]; then
    echo "tags_stage_env<<EOF" >> $GITHUB_ENV

    echo "${{ env.REPO_URL_STAGE }}:${{ inputs.branch_name }}" >> $GITHUB_ENV

    if [[ inputs.branch_name == 'master' || inputs.branch_name == 'main' ]]; then
        echo "${{ env.REPO_URL_STAGE }}:latest" >> $GITHUB_ENV
    fi
    echo "EOF" >> $GITHUB_ENV
fi

echo "Print variables:"
echo "REPO_URL=${{ env.REPO_URL }}"
echo "REPO_URL_STAGE=${{ env.REPO_URL_STAGE }}"
echo "CACHE_FROM=${{ env.cache_from_env }}"
echo "STAGE_CACHE_FROM=${{ env.stage_cache_from_env }}"
echo "CACHE_TO=${{ env.cache_to_env }}"
echo "STAGE_CACHE_TO=${{ env.stage_cache_to_env }}"
echo "BUILD_ARGS=${{ env.build_args_env }}"
echo "TAGS=${{ env.tags_env }}"
echo "TAGS_STAGE=${{ env.tags_stage_env }}"