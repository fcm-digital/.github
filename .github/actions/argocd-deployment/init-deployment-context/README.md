# Init Deployment Context Action

Resolves `branch_name` and `env_to_deploy` from event context and validates required inputs.

## Inputs

- `branch_name` (optional): required for `workflow_dispatch` and `workflow_run`
- `env_to_deploy` (optional): required for `workflow_dispatch`

## Outputs

- `branch_name`
- `env_to_deploy`

## Notes

- `pull_request` sets `env_to_deploy=NOT_DEFINED` (use `argocd-get-env-to-deploy-on` afterwards).
- `push` to `main/master` sets `env_to_deploy=prod`.
