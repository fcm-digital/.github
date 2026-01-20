#!/bin/bash

################################################################################
# ArgoCD Deployment - Argo Workflows Helm Template Generator
################################################################################
#
# PURPOSE:
#   This script generates Kubernetes YAML manifests for Argo Workflows by 
#   processing Helm charts with environment-specific values. It's designed to
#   work with multiple environments (stagings) and creates separate manifest
#   files for each environment.
#
# WHAT IT DOES:
#   1. Loops through specified environments (e.g., abc, ath, bne...)
#   2. Collects environment-specific Helm values files
#   3. Generates Kubernetes Job manifests from Helm templates
#   4. Generates Argo Workflow orchestration manifests
#   5. Splits multi-document YAML files into individual files
#   6. Names files based on their content for easy identification
#
# REQUIRED ENVIRONMENT VARIABLES:
#   - ENVIRONMENTS: Comma-separated list of environments (e.g., "abc,ath,bne")
#   - HELM_CHART_VALUES_PATH: Path to the directory containing values files
#   - HELM_CHART_TEMPLATE_PATH: Path to the Helm chart templates directory
#   - APP_NAME: Name of the application being deployed
#   - IMAGE_TAG: Docker image tag to use for the deployment
#   - WORKFLOW_NAME: Name of the Argo Workflow to extract
#
# EXPECTED DIRECTORY STRUCTURE:
#   $HELM_CHART_VALUES_PATH/
#   ├── staging/
#       ├── *.yaml (global staging values)
#       └── <env-name>/
#          └── *.yaml (environment-specific values)
#
# OUTPUT FILES:
#   - <job-type>-<env>.yaml: Individual Kubernetes Job manifests
#   - <workflow-name>-<env>.yaml: Argo Workflow orchestration manifest
#
# EXAMPLE USAGE:
#   export ENVIRONMENTS="ath"
#   export HELM_CHART_VALUES_PATH="helm-chart-values"
#   export HELM_CHART_TEMPLATE_PATH="helm-chart-template"
#   export APP_NAME="my-application"
#   export IMAGE_TAG="master-tag"
#   export WORKFLOW_NAME="data-processing-workflow"
#   ./entrypoint.sh
#
# ERROR HANDLING:
#   The script uses 'set -euo pipefail' which means:
#   - Exit immediately if any command fails (set -e)
#   - Treat unset variables as errors (set -u)
#   - Fail if any command in a pipeline fails (set -o pipefail)
#
################################################################################

set -euo pipefail

# Loop through each environment specified in the ENVIRONMENTS variable
# The tr command converts comma-separated values into newline-separated values
for env in $(echo $ENVIRONMENTS | tr ',' '\n'); do

    # Step 1: Determine the values directory based on environment
    # Production uses 'prod' folder, all other environments use 'staging'
    if [ $env == "prod" ]; then
        VALUES_DIR="./$HELM_CHART_VALUES_PATH/prod"
    else
        VALUES_DIR="./$HELM_CHART_VALUES_PATH/staging"
    fi

    # Step 2: Collect global values files (files at the root of the environment directory)
    # These values apply to all environments within staging or prod
    VALUES_GLOBAL_FILE=$(find $VALUES_DIR/ -maxdepth 1 -iname "*.yaml*")
    if [ ! -z "${VALUES_GLOBAL_FILE}" ]; then
        for value in $VALUES_GLOBAL_FILE; do
            # Build the VALUES string with -f flags for helm template command
            VALUES+=$(echo "-f .$value ")
        done
    fi

    # Step 3: Collect environment-specific values files
    # These override global values for the specific environment
    VALUES_LOCAL_FILE=$(find "$VALUES_DIR/$env/" -iname "*.yaml*")
    if [ ! -z "${VALUES_LOCAL_FILE}" ]; then
        for value in $VALUES_LOCAL_FILE; do
            VALUES+=$(echo "-f .$value ")
        done
    fi

    # Step 4: Generate Kubernetes Job manifests
    # Navigate to the Helm chart directory
    cd ./$HELM_CHART_TEMPLATE_PATH

    # Run helm template to generate Job manifests
    # -s templates/job.yaml: Only render the job.yaml template
    # --name-template: Set the release name
    # --namespace: Set the target namespace
    # --set currentTag: Override the image tag
    helm template . -s templates/job.yaml --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > "jobs-$env.yaml"

    # Step 5: Split the multi-document YAML file into separate files
    # YAML documents are separated by '---' delimiter
    delimiter="---"
    # csplit options:
    #   -z: Remove empty output files
    #   -s: Suppress output messages
    #   --suppress-matched: Don't include the delimiter in output files
    csplit -zs --suppress-matched "jobs-$env.yaml" /"$delimiter"/ '{*}'

    # Step 6: Rename job files based on their 'type' field
    # csplit creates files named xx00, xx01, xx02, etc.
    for file in xx*; do
        # Extract the 'type' field from the YAML to use as filename
        file_name=$(< $file grep 'type: ' --max-count=1 | awk '{ print $2 }')
        if [ -z "$file_name" ]; then
            # If no type field found, remove the file (likely empty or invalid)
            rm "$file"
        else
            # Rename file to <type>-<env>.yaml for easy identification
            mv "$file" "${file_name}-${env}.yaml"
        fi
    done

    # Step 7: Generate Argo Workflow orchestration manifests
    # Similar to job generation, but for workflow orchestration
    helm template . -s templates/argo-workflows-orchestration.yaml --name-template=$APP_NAME --namespace=$env $VALUES --set currentTag=$IMAGE_TAG > argo-workflows-$env.yaml

    # Step 8: Split the workflow YAML into separate files
    csplit -zs --suppress-matched argo-workflows-$env.yaml /"$delimiter"/ '{*}'

    # Step 9: Extract and rename the specific workflow we need
    for file in xx*; do
        # Look for the workflow name in the Kubernetes labels
        workflow=$(< $file grep "app.kubernetes.io/name: " --max-count=1 | awk '{ print $2 }')
        if [[ "$workflow" == "$WORKFLOW_NAME" ]]; then
            # Keep and rename the matching workflow
            mv "$file" "${WORKFLOW_NAME}-${env}.yaml"
        else
            # Remove workflows we don't need
            rm "$file"
        fi
    done

    # Step 10: List generated files for verification
    ls -la
done