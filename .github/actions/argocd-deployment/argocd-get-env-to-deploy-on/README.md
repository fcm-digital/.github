# ArgoCD Get Environment to Deploy On Action

## Overview

This GitHub Action automatically detects which staging environment(s) are currently using a specific branch/image tag. It searches through Helm values files to find environments that have already deployed the current branch, helping determine where to deploy updates.

## Purpose

This action serves as an **environment discovery step** for ArgoCD deployments in staging. It:

1. **Identifies active environments** that are currently running the branch being deployed
2. **Validates deployment targets** to prevent conflicts or unintended multi-environment deployments
3. **Provides environment context** for subsequent deployment steps
4. **Ensures deployment consistency** by matching image tags to existing deployments

## Inputs

| Input                         | Required | Default | Description                                                                                     |
| ----------------------------- | -------- | ------- | ----------------------------------------------------------------------------------------------- |
| `allow_multiple_environments` | ❌ No    | `false` | Allow deployment to multiple environments simultaneously. Set to `true` for multi-env deploys   |
| `app_name`                    | ✅ Yes   | -       | Name of the application (e.g., `my-service`). Used to locate the correct Helm values directory |
| `branch_name`                 | ✅ Yes   | -       | Branch name to search for. Will be sanitized to match Docker tag format                        |

## Outputs

| Output             | Description                                                                     | Example                          |
| ------------------ | ------------------------------------------------------------------------------- | -------------------------------- |
| `env_to_deploy_on` | JSON array of environment names where the branch is currently deployed          | `["env1", "env2"]`               |
|                    | Empty/undefined if no environments are found                                    | (no output)                      |

## How It Works

### Step 1: Sanitize Image Tag

The action first sanitizes the branch name to match Docker tag naming conventions:

- Uses the `sanitize-docker-tag` action to convert branch names
- Example transformations:
  - `feature/MY-123_new-api` → `feature-my-123-new-api`
  - `bugfix/TICKET-456` → `bugfix-ticket-456`

This ensures the search matches the actual Docker tags used in Helm values files.

### Step 2: Search Helm Values Files

The action searches for the sanitized tag in the staging environment:

1. **Locates the values directory:**
   ```
   ./helm-chart-<app_name>-values-staging/staging/
   ```

2. **Finds tag files:**
   - Searches for all files matching the pattern `*tag.*`
   - These files typically contain the Docker image tag for each environment

3. **Matches the tag:**
   - Reads each tag file and searches for the sanitized branch name
   - Extracts the environment name from the file path (parent directory name)

4. **Builds environment list:**
   - Collects all matching environments into a JSON array
   - Example: `["env1", "env2"]`

### Step 3: Validate and Output

The action validates the results based on the `allow_multiple_environments` setting:

#### Single Environment Mode (default)

- **If 0 environments found:** ✅ Success - outputs nothing
- **If 1 environment found:** ✅ Success - outputs the environment
- **If 2+ environments found:** ❌ Error - fails the workflow

#### Multiple Environments Mode

- **If 0 environments found:** ✅ Success - outputs nothing
- **If 1+ environments found:** ✅ Success - outputs all environments

## Usage Examples

### Example 1: Standard Single Environment Detection

```yaml
name: Deploy to Staging
on:
  pull_request:
    branches:
      - staging

jobs:
  deploy:`
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repositories
        uses: fcm-digital/.github/.github/actions/argocd-deployment/checkout-repositories@main
        with:
          app_name: my-service
          github_token_checkout: ${{ secrets.GITHUB_TOKEN }}

      - name: Detect environment
        id: detect-env
        uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on@main
        with:
          app_name: my-service
          branch_name: ${{ github.head_ref }}

      - name: Deploy to detected environment
        if: steps.detect-env.outputs.env_to_deploy_on != ''
        run: |
          echo "Deploying to: ${{ steps.detect-env.outputs.env_to_deploy_on }}"
          # Your deployment logic here
```

### Example 2: Allow Multiple Environments

```yaml
- name: Detect all environments using this branch
  id: detect-env
  uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on@main
  with:
    app_name: my-service
    branch_name: ${{ github.head_ref }}
    allow_multiple_environments: "true"

- name: Deploy to all detected environments
  if: steps.detect-env.outputs.env_to_deploy_on != ''
  run: |
    ENVIRONMENTS='${{ steps.detect-env.outputs.env_to_deploy_on }}'
    echo "Deploying to environments: $ENVIRONMENTS"
    # Parse JSON array and deploy to each environment
```

### Example 3: Handle No Environment Found

```yaml
- name: Detect environment
  id: detect-env
  uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on@main
  with:
    app_name: my-service
    branch_name: ${{ github.head_ref }}

- name: Deploy if environment found
  if: steps.detect-env.outputs.env_to_deploy_on != ''
  run: echo "Deploying to ${{ steps.detect-env.outputs.env_to_deploy_on }}"

- name: Skip deployment if no environment
  if: steps.detect-env.outputs.env_to_deploy_on == ''
  run: echo "No environment found for this branch - skipping deployment"
```

## Common Scenarios

### Scenario 1: PR Workflow - Update Existing Environment

**Context:** A developer pushes changes to a feature branch that's already deployed to a staging environment.

**Flow:**
1. PR is opened/updated
2. Action searches for the branch's Docker tag in staging values
3. Finds environment `staging-env-3` is using this branch
4. Outputs `["staging-env-3"]`
5. Deployment proceeds to update `staging-env-3`

### Scenario 2: New Branch - No Environment Found

**Context:** A new feature branch is created that hasn't been deployed anywhere yet.

**Flow:**
1. PR is opened
2. Action searches for the branch's Docker tag
3. No matching environments found
4. Outputs nothing (empty)
5. Workflow skips deployment or uses a default environment

### Scenario 3: Multi-Environment Deployment

**Context:** A shared branch (e.g., `staging`) is deployed to multiple environments.

**Flow:**
1. Push to `staging` branch
2. Action searches with `allow_multiple_environments: true`
3. Finds `["staging-env-1", "staging-env-2", "staging-env-3"]`
4. Deployment updates all three environments

### Scenario 4: Conflict Detection

**Context:** A branch is accidentally deployed to multiple environments, but only single deployment is expected.

**Flow:**
1. Action searches for the branch
2. Finds `["staging-env-1", "staging-env-2"]`
3. `allow_multiple_environments` is `false` (default)
4. **Action fails** with error message
5. SRE must investigate and resolve the conflict

## Error Handling

The action provides clear error messages for common issues:

### Error: Multiple Environments Found (Unexpected)

```
Error: More than one environment found for branch feature/my-branch -> "env1", "env2"
```

**Cause:** The branch is deployed to multiple environments, but `allow_multiple_environments` is `false`.

**Resolution:**
- If multi-environment deployment is intended: Set `allow_multiple_environments: "true"`
- If not intended: Investigate why the branch is in multiple environments and clean up

### Success Messages

The action logs informative messages on success:

```
OK: Environment(s) found for branch feature/my-branch -> "staging-env-1"
```

```
OK: No environment found for branch feature/new-feature
```

## Understanding the File Structure

The action expects a specific directory structure in the Helm values repository:

```
helm-chart-<app_name>-values-staging/
└── staging/
    ├── env1/
    │   ├── values.yaml
    │   └── tag.yaml          # Contains: image.tag: "feature-my-branch-2025-10-09T1020-a1b2c3d"
    ├── env2/
    │   ├── values.yaml
    │   └── tag.yaml
    └── env3/
        ├── values.yaml
        └── image.tag.yaml    # Alternative naming: also searched
```

**Key points:**
- Each environment has its own subdirectory under `staging/`
- Tag files match the pattern `*tag.*` (e.g., `tag.yaml`, `image.tag.yaml`)
- The action extracts the environment name from the parent directory of the tag file

## Troubleshooting

### Issue: "No environment found" but branch is deployed

**Possible Causes:**
1. Tag file naming doesn't match `*tag.*` pattern
2. Branch name sanitization changed the tag format
3. Tag file is in the wrong directory structure
4. Helm values repository not checked out

**Debugging Steps:**
```bash
# 1. Check if values repo is checked out
ls -la ./helm-chart-<app_name>-values-staging/

# 2. Find all tag files
find ./helm-chart-<app_name>-values-staging/staging -name '*tag.*'

# 3. Check tag file contents
cat ./helm-chart-<app_name>-values-staging/staging/<env>/tag.yaml

# 4. Verify sanitized tag format
# Compare branch name with what's in the tag file
```

### Issue: "More than one environment found" error

**Cause:** The same branch/tag is deployed to multiple environments.

**Investigation:**
1. Check which environments are using the tag:
   ```bash
   grep -r "your-branch-name" ./helm-chart-<app_name>-values-staging/staging/*/tag.*
   ```

2. Determine if this is intentional:
   - **Intentional:** Set `allow_multiple_environments: "true"`
   - **Unintentional:** Clean up old deployments or redeploy with unique tags

### Issue: Action fails silently or outputs nothing

**Cause:** The Helm values repository might not be checked out.

**Solution:** Ensure the `checkout-repositories` action runs before this action:
```yaml
- name: Checkout repositories
  uses: fcm-digital/.github/.github/actions/argocd-deployment/checkout-repositories@main
  with:
    app_name: my-service
    github_token_checkout: ${{ secrets.GITHUB_TOKEN }}

- name: Detect environment
  uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on@main
  with:
    app_name: my-service
    branch_name: ${{ github.head_ref }}
```

## Prerequisites

This action requires:

1. **Helm values repository checked out:**
   - Path: `./helm-chart-<app_name>-values-staging/`
   - Usually done by the `checkout-repositories` action

2. **Proper tag file structure:**
   - Tag files must match pattern `*tag.*`
   - Must contain the Docker image tag

3. **Sanitized branch names:**
   - Branch names must be sanitized to Docker tag format
   - Handled automatically by the action

## Dependencies

- **fcm-digital/.github/.github/actions/sanitize-docker-tag**: Sanitizes branch names to Docker-compatible tags

## Best Practices

1. **Always run after checkout-repositories:**
   - This action depends on the Helm values repository being available

2. **Handle empty outputs gracefully:**
   - Use conditional steps to handle cases where no environment is found
   - Example: `if: steps.detect-env.outputs.env_to_deploy_on != ''`

3. **Use allow_multiple_environments carefully:**
   - Default (`false`) prevents accidental multi-environment deployments
   - Only set to `true` when you intentionally want to deploy to multiple environments

4. **Log the detected environments:**
   - Always echo the output for debugging and audit trails

5. **Combine with other ArgoCD actions:**
   - Use as part of a complete deployment workflow
   - Typically runs between `checkout-repositories` and actual deployment steps

## Output Format

The `env_to_deploy_on` output is a **JSON array string**:

```json
["env1", "env2"]
```

To parse in bash:
```bash
ENVIRONMENTS='${{ steps.detect-env.outputs.env_to_deploy_on }}'
echo "$ENVIRONMENTS" | jq -r '.[]' | while read env; do
  echo "Deploying to $env"
  # Deploy to $env
done
```

To use in GitHub Actions matrix:
```yaml
- name: Detect environments
  id: detect-env
  uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on@main
  with:
    app_name: my-service
    branch_name: ${{ github.head_ref }}
    allow_multiple_environments: "true"

- name: Deploy to each environment
  strategy:
    matrix:
      environment: ${{ fromJson(steps.detect-env.outputs.env_to_deploy_on) }}
  runs-on: ubuntu-latest
  steps:
    - name: Deploy
      run: echo "Deploying to ${{ matrix.environment }}"
```

## Related Actions

- **checkout-repositories**: Checks out Helm values repositories (prerequisite)
- **sanitize-docker-tag**: Sanitizes branch names for Docker compatibility (used internally)
- **argocd-deployment/***: Other actions in the ArgoCD deployment suite

## Support

For issues or questions:

1. Check the GitHub Actions run logs for detailed error messages
2. Review this README for common scenarios and troubleshooting
3. Verify the Helm values repository structure matches expectations
4. Contact the Platform/SRE team for assistance

## Limitations

- **Staging only:** This action is designed for staging environments only (searches in `staging/` directory)
- **Tag file naming:** Requires tag files to match the `*tag.*` pattern
- **Single repository:** Only searches in one app's Helm values repository at a time
- **Exact match:** Requires exact tag match (after sanitization) - no partial matching
