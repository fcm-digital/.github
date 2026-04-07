# Resolve Deployment Image Tag Action

Builds `image_tag`, `commit_at`, and `commit` values for ArgoCD deployment steps.

## Inputs

- `branch_name` (required)
- `image_tag` (optional)

## Outputs

- `image_tag`
- `commit_at`
- `commit`

## Notes

- Uses `sanitize-docker-tag` with `branch_name`.
- **Prerequisites**: When `image_tag` is not provided, this action runs `git show` and `git rev-parse` to derive the commit timestamp and short SHA. The calling workflow must include an `actions/checkout` step before calling this action, otherwise those commands will fail with "not a git repository".
