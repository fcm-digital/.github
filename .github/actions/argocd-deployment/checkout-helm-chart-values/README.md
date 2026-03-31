# Checkout Helm Chart Values Action

Checks out `helm-chart-<app_name>-values` for staging (always) and production (conditionally), then exposes checkout-path outputs.

## Inputs

- `app_name` (required)
- `branch_name` (required)
- `env_to_deploy` (required)
- `release_name` (optional)
- `github_organization_name` (optional, default `fcm-digital`)
- `token` (required)

## Outputs

- `staging_values_path`: path to staging values checkout
- `prod_values_path`: path to prod values checkout, or empty when skipped
- `checked_out_prod`: `true` when prod values checkout exists, otherwise `false`

## Notes

- Preserves existing production checkout logic (main/master push/manual conditions).
- Supports manual release flow (`release_name` on `workflow_dispatch`).
