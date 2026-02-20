# Resolve Deployment Image Tag Action

Builds `image_tag`, `commit_at`, and `commit` values for ArgoCD deployment steps.

## Inputs

- `branch_name` (required)
- `env_to_deploy` (required)
- `image_tag` (optional)

## Outputs

- `image_tag`
- `commit_at`
- `commit`

## Notes

- Uses `sanitize-docker-tag` with `branch_name`.
- Keeps the existing production guardrail: `master/latest` cannot be deployed to `prod`.
