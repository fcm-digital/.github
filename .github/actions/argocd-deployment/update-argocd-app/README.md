# Update ArgoCD App Action

## Overview

This GitHub Action updates ArgoCD Applications with a new Docker image tag and source branch revision. It's designed for flexible deployment scenarios across staging and production environments, with intelligent handling of multi-environment updates.

## What This Action Does

1. **Updates image tags** - Sets the Docker image tag in ArgoCD Application's Helm values
2. **Updates branch revisions** - Changes the target branch for the values source repository
3. **Handles multiple environments** - Supports deploying to single environments, production, or all staging environments at once
4. **Prevents conflicts** - Validates branch/environment combinations to prevent accidental production deployments
5. **Tracks changes** - Outputs the previous image tag for potential rollbacks

## Quick Start

### Basic Usage - Single Staging Environment

```yaml
- name: Update ArgoCD app
  uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
  with:
    app_name: my-service
    app_region: euw1
    argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
    branch_name: ${{ github.ref_name }}
    env_to_deploy: sandbox
    image_tag: v1.0.0
```

### Production Deployment

```yaml
- name: Update ArgoCD app for production
  uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
  with:
    app_name: my-service
    app_region: euw1
    argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
    branch_name: main
    env_to_deploy: prod
    image_tag: v1.0.0
```

### Deploy to All Staging Environments

```yaml
- name: Update all staging environments
  id: update-all
  uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
  with:
    app_name: my-service
    app_region: euw1
    argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
    branch_name: main
    env_to_deploy: ALL_ENV
    image_tag: v1.0.0
    synced_envs_as_outputs: "true"

- name: Show synchronized environments
  run: echo "Updated environments: ${{ steps.update-all.outputs.synced_staging_envs }}"
```

## Inputs

### Required Inputs

| Input               | Description                                                | Example                  |
| ------------------- | ---------------------------------------------------------- | ------------------------ |
| `app_name`          | Name of the application to deploy                          | `my-service`             |
| `argocd_auth_token` | ArgoCD auth token with get/sync permissions                | `${{ secrets.TOKEN }}`   |
| `branch_name`       | Branch name to set as targetRevision for the values source | `main`, `feature/my-123` |
| `env_to_deploy`     | Target environment (`<env>`, `prod`, or `ALL_ENV`)         | `sandbox`, `prod`        |
| `image_tag`         | Docker image tag to deploy                                 | `v1.0.0`, `main-123`     |

### Optional Inputs

| Input                    | Description                                  | Default              | Options              |
| ------------------------ | -------------------------------------------- | -------------------- | -------------------- |
| `app_region`             | Region of the app to deploy                  | `euw1`               | `euw1`, `euw9`, etc. |
| `argocd_url`             | ArgoCD server URL                            | `argocd.fcm.digital` | Any valid ArgoCD URL |
| `synced_envs_as_outputs` | Output the list of synchronized staging envs | `false`              | `true`, `false`      |

## Outputs

| Output                | Description                                                    | Example          |
| --------------------- | -------------------------------------------------------------- | ---------------- |
| `old_image_tag`       | Previous image tag (for rollback)                              | `v0.9.9`         |
| `synced_staging_envs` | Comma-separated list of staging environments that were updated | `sandbox,dev,qa` |

## Understanding `env_to_deploy`

The `env_to_deploy` input controls which ArgoCD Applications are updated:

### Single Staging Environment

```yaml
env_to_deploy: sandbox
```

Updates the ArgoCD Application: `my-service-sandbox-stg-euw1`

### Production

```yaml
env_to_deploy: prod
```

Updates the ArgoCD Application: `my-service-pro-euw1`

**Requirements:**

- `branch_name` must be `main` or `master`
- Fails if attempting to deploy non-main branches to production

### All Staging Environments

```yaml
env_to_deploy: ALL_ENV
```

Updates **all** staging ArgoCD Applications matching: `my-service-*-stg-euw1`

**Behavior:**

- Only updates environments currently running `master`, `main`, or `latest` tags
- Always updates `sandbox` environment regardless of current tag
- Skips environments running feature branch tags (prevents overwriting active development)
- Requires `branch_name` to be `main` or `master`

## How It Works

### ArgoCD Application Structure

This action assumes ArgoCD Applications use **multiple sources**:

1. **Source 1 (Helm Chart)**: The Helm chart repository
   - Updated via `--helm-set-string currentTag=<image_tag>`

2. **Source 2 (Values)**: The values repository containing environment-specific configuration
   - Updated via `--revision <branch_name>`

### Update Process

The action performs updates in a specific order to minimize risk:

1. **Update branch revision first** (Source 2)
   - Less impactful change
   - Won't trigger deployment until image tag changes

2. **Update image tag second** (Source 1)
   - Triggers the actual deployment
   - If this fails, app still has old image tag (safer state)

### Safety Validations

The action enforces several safety rules:

```bash
# Cannot deploy to prod from feature branches
if env_to_deploy == "prod" && branch_name != "main|master":
  ERROR

# Cannot deploy to ALL_ENV from feature branches
if env_to_deploy == "ALL_ENV" && branch_name != "main|master":
  ERROR

# Cannot deploy to environments named "master" or "main"
if env_to_deploy == "master|main":
  ERROR
```

## Common Use Cases

### 1. Feature Branch Deployment to Sandbox

```yaml
name: Deploy Feature to Sandbox
on:
  push:
    branches:
      - "feature/**"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Update ArgoCD
        uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
        with:
          app_name: my-service
          app_region: euw1
          argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
          branch_name: ${{ github.ref_name }}
          env_to_deploy: sandbox
          image_tag: ${{ github.ref_name }}-${{ github.run_number }}
```

### 2. Production Deployment with Rollback Info

```yaml
- name: Deploy to production
  id: prod-deploy
  uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
  with:
    app_name: my-service
    app_region: euw1
    argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
    branch_name: main
    env_to_deploy: prod
    image_tag: v${{ github.run_number }}

- name: Save rollback tag
  run: |
    echo "Previous tag: ${{ steps.prod-deploy.outputs.old_image_tag }}"
    echo "ROLLBACK_TAG=${{ steps.prod-deploy.outputs.old_image_tag }}" >> $GITHUB_ENV
```

### 3. Update All Staging After Main Merge

```yaml
name: Update All Staging
on:
  push:
    branches:
      - main

jobs:
  update-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Update all staging environments
        id: update
        uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
        with:
          app_name: my-service
          app_region: euw1
          argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
          branch_name: main
          env_to_deploy: ALL_ENV
          image_tag: main-${{ github.run_number }}
          synced_envs_as_outputs: "true"

      - name: Notify team
        run: |
          echo "Updated environments: ${{ steps.update.outputs.synced_staging_envs }}"
```

### 4. Multi-Region Deployment

```yaml
strategy:
  matrix:
    region: [euw1, euw9]
steps:
  - name: Update ArgoCD in ${{ matrix.region }}
    uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
    with:
      app_name: my-service
      app_region: ${{ matrix.region }}
      argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
      branch_name: main
      env_to_deploy: prod
      image_tag: v${{ github.run_number }}
```

## ArgoCD Application Naming Convention

The action constructs ArgoCD Application names using this pattern:

### Staging Environments

```
{app_name}-{env}-stg-{region}
```

Examples:

- `my-service-sandbox-stg-euw1`
- `my-service-dev-stg-euw1`
- `my-service-qa-stg-euw9`

### Production

```
{app_name}-pro-{region}
```

Examples:

- `my-service-pro-euw1`
- `my-service-pro-euw9`

## ALL_ENV Behavior Details

When using `env_to_deploy: ALL_ENV`, the action:

1. **Queries ArgoCD** for all apps matching: `{app_name}-*-stg-{region}`

2. **For each found app:**
   - Extracts the environment name from the app name
   - Gets the current image tag
   - Checks if the tag prefix is `master`, `main`, or `latest`
   - **Updates if:**
     - Current tag is `master`, `main`, or `latest` (standard environments)
     - OR environment is `sandbox` (always updated)
   - **Skips if:**
     - Current tag is a feature branch (e.g., `feature-my-123-456`)

3. **Outputs:**
   - `old_image_tag`: Tag from the first app (they should all match)
   - `synced_staging_envs`: Comma-separated list of updated environments

### Example Scenario

Given these staging environments:

| Environment | Current Tag       | Action                |
| ----------- | ----------------- | --------------------- |
| `sandbox`   | `feature-abc-123` | ✅ Updated (sandbox)  |
| `dev`       | `main-456`        | ✅ Updated (main tag) |
| `qa`        | `feature-xyz-789` | ❌ Skipped (feature)  |
| `uat`       | `latest`          | ✅ Updated (latest)   |

Result: Updates `sandbox`, `dev`, and `uat`. Skips `qa`.

## Error Handling

The action provides clear error messages and handles failures gracefully:

### Partial Update Failure

If the branch revision update succeeds but image tag update fails:

```
✗ Failed to update image tag (branch revision was already updated)
⚠ App may be in inconsistent state - manual intervention may be required
```

**Resolution:** Check ArgoCD UI and manually sync or revert the app.

### No Staging Apps Found

```
Warning: No staging apps found matching pattern: my-service-*-stg-euw1
```

**Resolution:** Verify the app name and region are correct.

### Invalid Production Branch

```
Error: The Environment to Deploy cannot be 'prod' if the branch is not 'master' or 'main'.
```

**Resolution:** Only deploy to production from `main` or `master` branches.

## Troubleshooting

### Issue: "Failed to update branch revision"

**Possible Causes:**

1. ArgoCD auth token lacks permissions
2. ArgoCD Application doesn't exist
3. Network connectivity issues

**Debugging:**

```bash
# Verify app exists
argocd app get my-service-sandbox-stg-euw1 --server argocd.fcm.digital --auth-token $TOKEN

# Check token permissions
argocd account get-user-info --server argocd.fcm.digital --auth-token $TOKEN
```

### Issue: "old_image_tag is 'unknown'"

**Cause:** The ArgoCD Application doesn't have `currentTag` set in Helm values.

**Resolution:** Ensure the Helm chart uses `valuesObject.currentTag` in the Application spec.

### Issue: ALL_ENV updates wrong environments

**Cause:** Environments have unexpected tag formats.

**Investigation:**

```bash
# Check current tags for all environments
argocd app list --server argocd.fcm.digital --auth-token $TOKEN | grep my-service
```

### Issue: Regex injection in app name

**Fixed in latest version:** The action now escapes special regex characters in `app_name` and `app_region` to prevent injection vulnerabilities.

## Prerequisites

1. **ArgoCD CLI installed** (handled by `argocd-cli-install` action)
2. **jq installed** (available on GitHub-hosted runners)
3. **ArgoCD auth token** with permissions:
   - `applications, get`
   - `applications, update`
4. **ArgoCD Applications** must use multi-source structure:
   - Source 1: Helm chart
   - Source 2: Values repository

## Security Considerations

- **Auth tokens:** Always use GitHub Secrets for `argocd_auth_token`
- **Production protection:** The action enforces branch restrictions for production
- **Regex escaping:** App names and regions are sanitized to prevent injection attacks
- **Audit trail:** All updates are logged in GitHub Actions and ArgoCD audit logs

## Best Practices

1. **Use semantic versioning for image tags:**

   ```yaml
   image_tag: v${{ github.run_number }}
   ```

2. **Always capture old_image_tag for rollbacks:**

   ```yaml
   - id: deploy
     uses: .../update-argocd-app@main
   - run: echo "Rollback tag: ${{ steps.deploy.outputs.old_image_tag }}"
   ```

3. **Enable synced_envs_as_outputs for ALL_ENV:**

   ```yaml
   synced_envs_as_outputs: "true"
   ```

4. **Use matrix strategy for multi-region:**

   ```yaml
   strategy:
     matrix:
       region: [euw1, euw9]
   ```

5. **Combine with sync action for complete deployment:**

   ```yaml
   - name: Update ArgoCD app
     uses: .../update-argocd-app@main

   - name: Sync and wait
     uses: .../argocd-cli-sync-app@main
   ```

## Integration with Other Actions

This action is typically used as part of a complete deployment workflow:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # 1. Install ArgoCD CLI
      - uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-cli-install@main

      # 2. Update the ArgoCD Application (this action)
      - uses: fcm-digital/.github/.github/actions/argocd-deployment/update-argocd-app@main
        with:
          app_name: my-service
          argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
          branch_name: ${{ github.ref_name }}
          env_to_deploy: prod
          image_tag: v${{ github.run_number }}

      # 3. Sync and wait for deployment
      - uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-cli-sync-app@main
        with:
          app_name: my-service
          argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
          env_to_deploy: prod
```

## Limitations

- **Multi-source only:** Requires ArgoCD Applications with at least 2 sources
- **Helm-based:** Assumes source 1 uses Helm with `valuesObject`
- **Naming convention:** Relies on specific app naming patterns
- **Single region per call:** Must call action multiple times for multi-region deployments
- **No automatic sync:** Only updates the Application spec; doesn't trigger sync (use `argocd-cli-sync-app` for that)

## Related Actions

- **argocd-cli-install**: Installs ArgoCD CLI (prerequisite)
- **argocd-cli-sync-app**: Syncs and waits for ArgoCD Application
- **build-push-image**: Builds and pushes Docker images
- **argocd-get-env-to-deploy-on**: Detects which environments are using a branch

## Support

For issues or questions:

1. Check the GitHub Actions run logs for detailed error messages
2. Review this README for common scenarios and troubleshooting
3. Verify ArgoCD Application structure matches expectations
4. Contact the Platform/SRE team for ArgoCD access or configuration issues
