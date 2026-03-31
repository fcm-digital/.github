# Create Shared Repo Token Action

Creates a GitHub App installation token that can be reused by other ArgoCD deployment actions.

## Inputs

- `github_app_id` (required)
- `github_app_private_key` (required)
- `github_organization_name` (optional, default `fcm-digital`)
- `repositories` (required): comma or newline-separated repository names

## Outputs

- `token`

## Example

```yaml
- id: repo-token
  uses: fcm-digital/.github/.github/actions/argocd-deployment/create-shared-repo-token@main
  with:
    github_app_id: ${{ secrets.APP_ID }}
    github_app_private_key: ${{ secrets.APP_PRIVATE_KEY }}
    repositories: |
      helm-chart-template
      helm-chart-my-app-values
```
