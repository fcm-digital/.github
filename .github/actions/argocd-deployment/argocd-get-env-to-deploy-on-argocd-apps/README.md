# ArgoCD Get Environment to Deploy On (Staging Apps)

This action discovers staging environment(s) for an app by reading ArgoCD Applications directly and matching `.spec.sources[0].helm.valuesObject.currentTag` against the sanitized branch tag.

## Inputs

| Input                         | Required | Default              | Description |
| ----------------------------- | -------- | -------------------- | ----------- |
| `allow_multiple_environments` | No       | `false`              | Allow multiple environments in output |
| `app_name`                    | Yes      | -                    | Application name (ArgoCD app prefix) |
| `app_region`                  | No       | `euw1`               | Region used by app naming convention |
| `argocd_auth_token`           | Yes      | -                    | ArgoCD token with app read permission |
| `argocd_url`                  | No       | `argocd.fcm.digital` | ArgoCD server URL |
| `branch_name`                 | Yes      | -                    | Branch to match after sanitization |

## Output

- `env_to_deploy_on`: JSON array string with staging environments, e.g. `["abc", "ath"]`.

## Match rule

A staging app matches when current tag is:

1. exactly equal to sanitized branch tag, or
2. starts with `sanitized_tag-`.

Examples:

- sanitized: `feature-sc-123`
- matches: `feature-sc-123`, `feature-sc-123-2026-02-19t1501-a1b2c3d`

## Behavior

- Staging-only discovery: app name pattern `${app_name}-*-stg-${app_region}`.
- If no app/environment matches: success, no output.
- If one environment matches: outputs JSON array with one item.
- If multiple environments match and `allow_multiple_environments=false`: logs error message and does not set output (same behavior as existing `argocd-get-env-to-deploy-on`).

## Usage

```yaml
- id: get-env-to-deploy-on
  uses: fcm-digital/.github/.github/actions/argocd-deployment/argocd-get-env-to-deploy-on-argocd-apps@main
  with:
    app_name: sam-ui-rendered
    app_region: euw1
    argocd_auth_token: ${{ secrets.ARGOCD_TOKEN }}
    branch_name: ${{ github.head_ref }}
    allow_multiple_environments: true
```
