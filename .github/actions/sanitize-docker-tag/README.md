# Sanitize Docker Tag Action

## Overview

This GitHub Action sanitizes and validates Docker image tags to ensure they conform to Docker's official tag naming rules. It's designed to prevent CI/CD pipeline failures caused by invalid tag names.

## Why This Action Exists

Docker has strict rules for image tags. Invalid tags can cause:

- **Build failures** when pushing images to registries
- **Deployment issues** when pulling images
- **Inconsistent behavior** across different Docker registries

Common problematic scenarios:

- Branch names with special characters (e.g., `feature/add-new-api`)
- Git refs with slashes (e.g., `refs/heads/main`)
- Uppercase characters (Docker Hub normalizes to lowercase)
- Tags starting with periods or dashes
- Tags exceeding length limits

## Docker Tag Rules

Valid Docker tags must:

- Contain only: `A-Z`, `a-z`, `0-9`, `_`, `.`, `-`
- **Not** start with `.` or `-`
- Be maximum **128 characters** long
- Be lowercase (recommended for Docker Hub compatibility)

## Inputs

| Input             | Required | Default  | Description                                           |
| ----------------- | -------- | -------- | ----------------------------------------------------- |
| `tag`             | ✅ Yes   | -        | The Docker image tag to sanitize                      |
| `force-lowercase` | ❌ No    | `true`   | Convert tag to lowercase (recommended for Docker Hub) |
| `fallback`        | ❌ No    | `latest` | Fallback tag if sanitization results in empty string  |

## Outputs

| Output          | Description                                            |
| --------------- | ------------------------------------------------------ |
| `sanitized_tag` | The sanitized Docker image tag, guaranteed to be valid |

## How It Works

The action performs the following transformations in order:

1. **Lowercase conversion** (if `force-lowercase: true`)

   - Converts all characters to lowercase
   - Example: `Feature-Branch` → `feature-branch`

2. **Character replacement**

   - Replaces invalid characters with `-`
   - Example: `feature/add-api` → `feature-add-api`

3. **Leading character removal**

   - Removes leading `.` or `-` characters
   - Example: `.hidden-tag` → `hidden-tag`

4. **Length truncation**

   - Truncates to 128 characters maximum
   - Example: `very-long-tag-name...` → `very-long-tag-name...` (first 128 chars)

5. **Fallback handling**

   - Uses fallback tag if result is empty
   - Applies same sanitization rules to fallback

6. **Final validation**
   - Ensures only valid characters remain
   - Ultimate fallback to `latest` if all else fails

## Usage Examples

### Basic Usage

```yaml
- name: Sanitize branch name for Docker tag
  id: sanitize
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: ${{ github.ref_name }}

- name: Build and push Docker image
  run: |
    docker build -t myapp:${{ steps.sanitize.outputs.sanitized_tag }} .
    docker push myapp:${{ steps.sanitize.outputs.sanitized_tag }}
```

### With Custom Fallback

```yaml
- name: Sanitize tag with custom fallback
  id: sanitize
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: ${{ github.event.pull_request.head.ref }}
    fallback: "dev"
```

### Preserve Case (Not Recommended)

```yaml
- name: Sanitize without forcing lowercase
  id: sanitize
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: ${{ github.sha }}
    force-lowercase: "false"
```

### Common CI/CD Patterns

#### Pattern 1: Branch-based tagging

```yaml
- name: Create tag from branch name
  id: tag
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: ${{ github.ref_name }}
# Input: feature/add-authentication
# Output: feature-add-authentication
```

#### Pattern 2: PR-based tagging

```yaml
- name: Create tag from PR number
  id: tag
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: pr-${{ github.event.pull_request.number }}
# Input: pr-123
# Output: pr-123
```

#### Pattern 3: Git SHA tagging

```yaml
- name: Create tag from commit SHA
  id: tag
  uses: ./.github/actions/sanitize-docker-tag
  with:
    tag: ${{ github.sha }}
    force-lowercase: "true"
# Input: A1B2C3D4E5F6...
# Output: a1b2c3d4e5f6...
```

## Transformation Examples

| Input Tag                | Output Tag               | Reason                    |
| ------------------------ | ------------------------ | ------------------------- |
| `feature/add-api`        | `feature-add-api`        | Slash replaced with dash  |
| `Feature-Branch`         | `feature-branch`         | Converted to lowercase    |
| `.hidden-tag`            | `hidden-tag`             | Leading period removed    |
| `--double-dash`          | `double-dash`            | Leading dashes removed    |
| `tag@with#special$chars` | `tag-with-special-chars` | Special chars replaced    |
| `refs/heads/main`        | `refs-heads-main`        | Slashes replaced          |
| `` (empty)               | `latest`                 | Fallback applied          |
| `v1.2.3`                 | `v1.2.3`                 | Already valid, no changes |

## Troubleshooting

### Warning: "Sanitized tag became empty"

**Cause**: The input tag contained only invalid characters or became empty after sanitization.

**Solution**:

- Check your input tag value
- Provide a meaningful `fallback` tag
- Review the transformation rules above

### Warning: "Sanitized tag contains unexpected characters after processing"

**Cause**: Edge case where final validation detected remaining invalid characters.

**Solution**: This is automatically handled by replacing invalid characters with `-`. If you see this warning frequently, review your input tag sources.

### Tag still fails in Docker registry

**Possible causes**:

1. **Registry-specific rules**: Some registries have additional restrictions
2. **Case sensitivity**: Set `force-lowercase: "true"` for Docker Hub
3. **Reserved names**: Some registries reserve certain tag names (e.g., `latest`, `scratch`)

## Best Practices

1. **Always sanitize user-generated content**

   - Branch names
   - PR titles
   - Git refs

2. **Use meaningful fallbacks**

   - Avoid generic `latest` when possible
   - Use environment-specific fallbacks (e.g., `dev`, `staging`)

3. **Enable lowercase conversion**

   - Keep `force-lowercase: "true"` for maximum compatibility
   - Only disable if you have specific case-sensitive requirements

4. **Validate in CI/CD**

   - Use this action early in your workflow
   - Store sanitized tag in a variable for reuse

5. **Document your tagging strategy**
   - Define clear tagging conventions for your team
   - Use consistent patterns across projects

## Integration with Other Actions

This action is commonly used with:

- **Docker build actions**: Sanitize tags before building images
- **ArgoCD deployment**: Ensure valid tags for Kubernetes deployments
- **Image scanning**: Validate tags before security scanning
- **Multi-registry pushes**: Ensure compatibility across registries

## Technical Details

- **Shell**: Bash
- **Dependencies**: None (uses standard Unix utilities)
- **Execution**: Runs as composite action
- **Performance**: Near-instant (simple string operations)

## Security Considerations

- **No external dependencies**: Reduces supply chain risk
- **Deterministic output**: Same input always produces same output
- **No secrets handling**: Safe to use with public repositories
- **Audit trail**: All transformations logged in workflow output

## Contributing

When modifying this action:

1. Test with edge cases (empty strings, special characters, etc.)
2. Ensure backward compatibility
3. Update this README with new examples
4. Validate against Docker's official tag specification

## References

- [Docker Tag Naming Rules](https://docs.docker.com/engine/reference/commandline/tag/)
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)
- [GitHub Actions Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
