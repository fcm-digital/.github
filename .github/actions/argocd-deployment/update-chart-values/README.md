# ArgoCD Deployment GitHub Action

## Introduction
This GitHub Action automates the deployment of applications using ArgoCD by updating Helm chart values. It supports various deployment scenarios, including staging, production, and multi-environment deployments.

## Inputs
- **app_name**: The name of the application to be deployed. *(required)*
- **branch_name**: The name of the branch currently being deployed. *(required)*
- **deploy_on_sandbox**: Set to "true" to enable deployment to the sandbox environment during the ALL_ENV stage. Default is `true`.
- **env_to_deploy**: Specifies the target environment for deployment. Use 'ALL_ENV' to update all environments, or 'NO_SYNC' to only update common staging values. *(required)*
- **image_tag**: The specific image tag to deploy.
- **manual**: Set to true if the deployment is manual, to reflect this in the commit message.
- **rollout**: Set to true if the deployment is a rollout, to reflect this in the commit message.
- **synced_envs_as_outputs**: Set to true to output the list of environments that were synchronized. Default is `false`.
- **update_deployed_at**: Set to "true" to update the DEPLOYED_AT environment variable with the current date and time. Default is `false`.
- **release_version**: The version of the PROD release to be deployed.

## Outputs
- **synced_staging_envs**: Outputs the list of environments that were successfully synchronized.
- **old_image_tag**: Outputs the old image tag for a possible rollback.

## Usage Example
```yaml
name: Deploy Application

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Deploy to ArgoCD
        uses: ./.github/actions/argocd-deployment/update-chart-values
        with:
          app_name: 'my-app'
          branch_name: 'main'
          env_to_deploy: 'prod'
          image_tag: 'v1.0.0'
          manual: 'true'
```