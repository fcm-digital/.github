# Checkout Repositories Action

## Overview

This GitHub Action prepares the deployment context for ArgoCD by checking out necessary repositories and initializing deployment variables. It's designed to work with multiple trigger types (push, pull request, manual dispatch) and handles environment detection automatically.

## Purpose

This action serves as the **initialization step** for ArgoCD deployments. It:

1. **Determines the deployment context** (branch, environment, image tag)
2. **Validates inputs** based on the trigger type
3. **Checks out required repositories** (application values and helm chart template)
4. **Generates standardized image tags** for container deployments

## Inputs

| Input                     | Required       | Description                                                                       |
| ------------------------- | -------------- | --------------------------------------------------------------------------------- |
| `app_name`                | ✅ Yes         | Name of the application to deploy (e.g., `my-service`)                            |
| `branch_name`             | ⚠️ Conditional | Branch to checkout. **Required for manual deployments** (`workflow_dispatch`)     |
| `env_to_deploy`           | ⚠️ Conditional | Target environment (e.g., `staging`, `prod`). **Required for manual deployments** |
| `image_tag`               | ❌ No          | Specific image tag to deploy. If omitted, a tag is auto-generated from the commit |
| `github_token_checkout`   | ✅ Yes         | GitHub token with access to checkout private repositories                         |
| `helm_chart_template_ref` | ❌ No          | Specific branch/ref of `helm-chart-template` to use                               |

## Outputs

| Output          | Description                       | Example                                   |
| --------------- | --------------------------------- | ----------------------------------------- |
| `branch_name`   | The branch being deployed         | `feature/new-api`                         |
| `env_to_deploy` | Target environment for deployment | `staging` or `prod`                       |
| `commit_at`     | Timestamp of the commit           | `2025-10-09T1020`                         |
| `commit`        | Short SHA of the commit           | `a1b2c3d`                                 |
| `image_tag`     | Full image tag to deploy          | `feature-new-api-2025-10-09T1020-a1b2c3d` |

## How It Works

### Step 1: Initialize Context Variables

The action determines the branch and environment based on the GitHub event type:

#### Manual Deployment (`workflow_dispatch`)

- **Requires** both `branch_name` and `env_to_deploy` inputs
- Fails if either is missing
- Use this for ad-hoc deployments or rollbacks

#### Pull Request (`pull_request`)

- Extracts branch from `github.head_ref`
- Sets `env_to_deploy` to `NOT_DEFINED` (must be set by `argocd-get-env-to-deploy-on` action)
- Useful for preview environments

#### Push to Branch (`push`)

- Extracts branch from `github.ref_name`
- **Auto-detects environment:**
  - `master` or `main` → `prod`
  - Any other branch → uses branch name as environment
- This is the standard CI/CD flow

### Step 2: Sanitize Image Tag

- Converts the branch name to a Docker-compatible tag format
- Uses the `sanitize-docker-tag` action to ensure compliance with Docker tag naming rules
- Example: `feature/MY-123_new-api` → `feature-my-123-new-api`

### Step 3: Set Outputs

Generates the final image tag using one of two methods:

#### Auto-generated Tag (default)

If `image_tag` input is **not provided**:

```
<sanitized-branch>-<commit-timestamp>-<short-sha>
```

Example: `staging-2025-10-09T1020-a1b2c3d`

#### Custom Tag

If `image_tag` input **is provided**:

```
<sanitized-branch>
```

**Safety Check:** Prevents deploying `master` or `latest` tags to production.

### Step 4: Checkout Repositories

The action checks out up to 3 repositories:

1. **Application Source** (always)

   - The repository containing the workflow

2. **Helm Values - Production** (conditional)

   - Repository: `fcm-digital/helm-chart-<app_name>-values`
   - Branch: Same as deployment branch
   - Path: `helm-chart-<app_name>-values-prod`
   - **Only checked out when:**
     - Event is `push` to `master`/`main`
     - Deploying to `prod` environment

3. **Helm Values - Staging** (always)

   - Repository: `fcm-digital/helm-chart-<app_name>-values`
   - Branch: `staging`
   - Path: `helm-chart-<app_name>-values-staging`

4. **Helm Chart Template** (conditional)
   - Repository: `fcm-digital/helm-chart-template`
   - Branch: Specified by `helm_chart_template_ref` input
   - Path: `helm-chart-template`
   - **Only checked out when:** `helm_chart_template_ref` is provided

## Usage Examples

### Example 1: Standard CI/CD (Push to Branch)

```yaml
name: Deploy to Staging
on:
  push:
    branches:
      - staging

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout and Initialize
        id: checkout
        uses: fcm-digital/.github/.github/actions/argocd-deployment/checkout-repositories@main
        with:
          app_name: my-service
          github_token_checkout: ${{ secrets.GITHUB_TOKEN }}

      - name: Use outputs
        run: |
          echo "Deploying branch: ${{ steps.checkout.outputs.branch_name }}"
          echo "To environment: ${{ steps.checkout.outputs.env_to_deploy }}"
          echo "Image tag: ${{ steps.checkout.outputs.image_tag }}"
```

### Example 2: Manual Deployment

```yaml
name: Manual Deploy
on:
  workflow_dispatch:
    inputs:
      branch_name:
        description: "Branch to deploy"
        required: true
      env_to_deploy:
        description: "Environment (staging/prod)"
        required: true
        type: choice
        options:
          - staging
          - prod
      image_tag:
        description: "Specific image tag (optional)"
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout and Initialize
        id: checkout
        uses: fcm-digital/.github/.github/actions/argocd-deployment/checkout-repositories@main
        with:
          app_name: my-service
          branch_name: ${{ inputs.branch_name }}
          env_to_deploy: ${{ inputs.env_to_deploy }}
          image_tag: ${{ inputs.image_tag }}
          github_token_checkout: ${{ secrets.GITHUB_TOKEN }}
```

### Example 3: Using Custom Helm Chart Template

```yaml
- name: Checkout with Custom Template
  uses: fcm-digital/.github/.github/actions/argocd-deployment/checkout-repositories@main
  with:
    app_name: my-service
    github_token_checkout: ${{ secrets.GITHUB_TOKEN }}
    helm_chart_template_ref: feature/new-template-version
```

## Common Scenarios

### Scenario 1: Deploying to Production

- **Trigger:** Push to `master` or `main` branch
- **Environment:** Automatically set to `prod`
- **Repositories checked out:** Source + Production values + Staging values
- **Image tag:** Auto-generated with timestamp and commit SHA

### Scenario 2: Deploying to Staging

- **Trigger:** Push to `staging` branch
- **Environment:** Automatically set to `staging`
- **Repositories checked out:** Source + Staging values
- **Image tag:** Auto-generated

### Scenario 3: Rollback to Previous Version

- **Trigger:** Manual dispatch
- **Inputs:**
  - `branch_name`: The branch that was previously deployed
  - `env_to_deploy`: Target environment
  - `image_tag`: The specific tag to rollback to
- **Repositories checked out:** Based on environment
- **Image tag:** Uses the provided `image_tag`

## Error Handling

The action will **fail** with a clear error message if:

1. **Missing branch name** in manual deployment

   ```
   🚨 Checkout failed
   Reason: Branch name not provided in a workflow_dispatch event.
   ```

2. **Missing environment** in manual deployment

   ```
   🚨 Checkout failed
   Reason: Environment not provided in a workflow_dispatch event.
   ```

3. **Unsupported event type**

   ```
   🚨 Checkout failed
   Reason: Event <event_name> not supported.
   ```

4. **Deploying master/latest to production**
   ```
   🚨 Deployment failed
   Reason: You can't deploy master or latest image on PROD
   ```

## Troubleshooting

### Issue: "Repository not found" error

**Cause:** The GitHub token doesn't have access to the helm chart repositories.

**Solution:** Ensure `github_token_checkout` has read access to:

- `fcm-digital/helm-chart-<app_name>-values`
- `fcm-digital/helm-chart-template` (if using custom ref)

### Issue: "env_to_deploy is NOT_DEFINED" in PR workflows

**Cause:** Pull request events don't automatically determine the environment.

**Solution:** Use the `argocd-get-env-to-deploy-on` action after this action to determine the target environment.

### Issue: Image tag format is incorrect

**Cause:** The branch name contains characters that aren't Docker-compatible.

**Solution:** The action automatically sanitizes tags. Check the `sanitize-docker-tag` action logs for details.

## Dependencies

- **actions/checkout@v5**: GitHub's official checkout action
- **fcm-digital/.github/.github/actions/sanitize-docker-tag**: Internal action for Docker tag sanitization

## Best Practices

1. **Always use this action first** in your ArgoCD deployment workflows
2. **Store the action outputs** in step outputs for use in subsequent steps
3. **Use manual dispatch carefully** - prefer automated triggers for consistency
4. **Never hardcode image tags** - let the action generate them for traceability
5. **Review the GitHub Step Summary** on failures for detailed error information

## Related Actions

- `argocd-get-env-to-deploy-on`: Determines environment from branch name in PR workflows
- `sanitize-docker-tag`: Sanitizes branch names for Docker compatibility
- `argocd-deployment/*`: Other actions in the ArgoCD deployment suite

## Support

For issues or questions:

1. Check the GitHub Actions run logs and step summary
2. Review this README for common scenarios
3. Contact the Platform/SRE team for assistance
