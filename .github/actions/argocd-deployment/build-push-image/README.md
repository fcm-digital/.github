# Build & Push Docker Image Action

## Overview

This GitHub Action builds and pushes Docker images to Google Artifact Registry with intelligent caching strategies. It's designed to optimize build times while maintaining flexibility for different deployment scenarios (staging vs production, multi-stage builds, etc.).

## What This Action Does

1. **Sanitizes tags** - Ensures Docker tags are valid (removes invalid characters)
2. **Configures repository URLs** - Constructs the correct Google Artifact Registry paths
3. **Sets build arguments** - Injects metadata (commit SHA, branch, timestamp, etc.) into the build
4. **Builds Docker images** - Uses different caching strategies based on configuration
5. **Pushes to registry** - Uploads images with appropriate tags to Google Artifact Registry

## Quick Start

### Basic Usage

```yaml
- name: Build and push Docker image
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: my-application
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: v1.0.0
```

### With Custom Build Arguments

```yaml
- name: Build and push Docker image
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: my-application
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: v1.0.0
    build_args: "NODE_ENV=production,API_VERSION=v2"
    cache_type: registry
```

### Multi-Stage Build with Stage Caching

```yaml
- name: Build and push Docker image
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: my-application
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: v1.0.0
    target: builder
    cache_type: stage-and-registry
```

## Inputs

### Required Inputs

| Input         | Description                       | Example                                     |
| ------------- | --------------------------------- | ------------------------------------------- |
| `app_name`    | Name of the application to deploy | `my-service`                                |
| `branch_name` | Current branch name               | `main`, `feature/new-feature`               |
| `commit`      | Git commit SHA                    | `${{ github.sha }}`                         |
| `commit_at`   | Timestamp when commit was created | `${{ github.event.head_commit.timestamp }}` |
| `image_tag`   | Tag for the Docker image          | `v1.0.0`, `1.2.3-rc1`                       |

### Optional Inputs

| Input                      | Description                                 | Default          | Options                                            |
| -------------------------- | ------------------------------------------- | ---------------- | -------------------------------------------------- |
| `artifact_region`          | Google Artifact Registry region             | `europe`         | `europe`, `us`, `asia`, etc.                       |
| `artifact_repository_name` | Custom repository name in Artifact Registry | (auto-generated) | Any valid repository name                          |
| `build_args`               | Comma-separated build arguments             | (none)           | `KEY1=value1,KEY2=value2`                          |
| `cache_type`               | Docker build cache strategy                 | `inline`         | `none`, `inline`, `registry`, `stage-and-registry` |
| `context`                  | Build context directory                     | `./`             | Any valid path                                     |
| `file`                     | Path to Dockerfile                          | `Dockerfile`     | `Dockerfile`, `docker/Dockerfile.prod`             |
| `pull`                     | Pull images from registry for cache         | `false`          | `true`, `false`                                    |
| `push`                     | Push built image to registry                | `true`           | `true`, `false`                                    |
| `secrets`                  | Secrets to pass to Docker build             | (none)           | See [Docker secrets](#docker-secrets)              |
| `target`                   | Target stage in multi-stage build           | (none)           | Stage name from Dockerfile                         |

## Outputs

| Output                | Description                              | Example  |
| --------------------- | ---------------------------------------- | -------- |
| `sanitized_image_tag` | Sanitized version of the input image tag | `v1-0-0` |

## Understanding Cache Types

The action supports four caching strategies to optimize build times:

### 1. `none` - No Caching

- **Use case**: When you need a completely fresh build
- **Pros**: Guarantees clean build
- **Cons**: Slowest build times
- **When to use**: Debugging build issues, security concerns

### 2. `inline` (Default)

- **Use case**: General purpose caching
- **Pros**: Simple, works well for most cases
- **Cons**: Cache stored with image (increases image size slightly)
- **When to use**: Standard applications without complex multi-stage builds

### 3. `registry`

- **Use case**: Separate cache storage
- **Pros**: Cache doesn't bloat image size
- **Cons**: Requires additional registry storage
- **When to use**: When image size is critical

### 4. `stage-and-registry`

- **Use case**: Multi-stage Dockerfiles with expensive build stages
- **Pros**: Caches intermediate stages separately, fastest for multi-stage builds
- **Cons**: Most complex, requires `target` input
- **When to use**: Applications with heavy build dependencies (e.g., compiled languages)

## How Image Tags Work

The action automatically generates multiple tags for your image:

### For Non-Production Branches (feature branches, develop, etc.)

```
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-app/my-app:feature-new-feature
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-app/my-app:v1-0-0
```

### For Production Branches (main, master)

```
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-app/my-app:main
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-app/my-app:v1-0-0
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-app/my-app:latest
```

**Note**: Production branches get an additional `latest` tag for easy reference.

## Repository URL Structure

The action constructs Google Artifact Registry URLs based on your inputs:

### Default Structure (when `artifact_repository_name` is not provided)

```
{region}-docker.pkg.dev/fcm-platform-artifacts-ceba/{app_name}/{app_name}
```

Example:

```
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-service/my-service
```

### Custom Repository Structure

```
{region}-docker.pkg.dev/fcm-platform-artifacts-ceba/{artifact_repository_name}/{app_name}
```

Example with `artifact_repository_name: shared-services`:

```
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/shared-services/my-service
```

### Stage Caching Repository (when using `stage-and-registry`)

```
{region}-docker.pkg.dev/fcm-platform-artifacts-ceba/{repo_name}-{target}/{app_name}-{target}
```

Example with `target: builder`:

```
europe-docker.pkg.dev/fcm-platform-artifacts-ceba/my-service-builder/my-service-builder
```

## Build Arguments

The action automatically injects several build arguments into your Docker build:

### Automatic Build Arguments

| Argument               | Description                         | Example                |
| ---------------------- | ----------------------------------- | ---------------------- |
| `USER_BUILDER`         | GitHub user who triggered the build | `john.doe`             |
| `SANITIZED_BRANCH_TAG` | Sanitized branch name               | `feature-new-feature`  |
| `SANITIZED_IMAGE_TAG`  | Sanitized image tag                 | `v1-0-0`               |
| `APP_REVISION`         | Same as sanitized image tag         | `v1-0-0`               |
| `BRANCH`               | Original branch name                | `feature/new-feature`  |
| `COMMIT_SHA`           | Short commit SHA (7 characters)     | `abc123d`              |
| `COMMIT_AT`            | Commit timestamp                    | `2025-10-09T13:45:00Z` |

### Using Build Arguments in Your Dockerfile

```dockerfile
ARG COMMIT_SHA
ARG BRANCH
ARG COMMIT_AT
ARG APP_REVISION

LABEL org.opencontainers.image.revision="${COMMIT_SHA}"
LABEL org.opencontainers.image.version="${APP_REVISION}"
LABEL org.opencontainers.image.created="${COMMIT_AT}"
LABEL org.opencontainers.image.source="https://github.com/fcm-digital/my-repo/tree/${BRANCH}"
```

### Custom Build Arguments

Pass additional build arguments using the `build_args` input:

```yaml
with:
  build_args: "NODE_ENV=production,API_VERSION=v2,FEATURE_FLAG=true"
```

In your Dockerfile:

```dockerfile
ARG NODE_ENV
ARG API_VERSION
ARG FEATURE_FLAG

RUN echo "Building with NODE_ENV=${NODE_ENV}"
```

## Docker Secrets

For sensitive data during build (e.g., private package registry credentials), use the `secrets` input:

```yaml
- name: Build and push Docker image
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: my-application
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: v1.0.0
    secrets: |
      NPM_TOKEN=${{ secrets.NPM_TOKEN }}
      GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
```

In your Dockerfile:

```dockerfile
# Mount secrets during build (they won't be in final image)
RUN --mount=type=secret,id=NPM_TOKEN \
    echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/NPM_TOKEN)" > ~/.npmrc && \
    npm install
```

## Common Use Cases

### 1. Simple Web Application (Node.js, Python, Ruby)

```yaml
- name: Build and push
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: web-app
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: ${{ github.run_number }}
    cache_type: inline
```

### 2. Compiled Application (Go, Rust, Java)

```yaml
- name: Build and push
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: api-service
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: ${{ github.run_number }}
    target: builder
    cache_type: stage-and-registry
```

### 3. Monorepo with Multiple Services

```yaml
- name: Build service A
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: service-a
    artifact_repository_name: monorepo
    context: ./services/service-a
    file: ./services/service-a/Dockerfile
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: ${{ github.run_number }}
```

### 4. Build Without Pushing (Testing)

```yaml
- name: Test build
  uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
  with:
    app_name: my-app
    branch_name: ${{ github.ref_name }}
    commit: ${{ github.sha }}
    commit_at: ${{ github.event.head_commit.timestamp }}
    image_tag: test
    push: false
```

## Troubleshooting

### Issue: Build is very slow

**Solution**:

- Check your `cache_type` setting
- For multi-stage builds, use `stage-and-registry` with appropriate `target`
- Ensure your Dockerfile is optimized (order layers from least to most frequently changing)

### Issue: Cache not being used

**Possible causes**:

1. First build on a new branch (no cache exists yet)
2. `cache_type` set to `none`
3. Dockerfile changed significantly
4. Base image updated

**Solution**:

- Set `pull: true` to pull existing images for cache
- Verify cache images exist in Google Artifact Registry

### Issue: Image tag contains invalid characters

**Solution**:

- The action automatically sanitizes tags
- Check the `sanitized_image_tag` output to see the actual tag used
- Avoid special characters in your input tags (use alphanumeric, hyphens, underscores)

### Issue: Build fails with "permission denied"

**Solution**:

- Ensure GitHub Actions has authentication to Google Artifact Registry
- Check that the service account has `Artifact Registry Writer` role
- Verify the repository exists in Google Artifact Registry

### Issue: Secrets not available during build

**Solution**:

- Ensure secrets are passed in the correct format (see [Docker Secrets](#docker-secrets))
- Use `RUN --mount=type=secret,id=SECRET_NAME` in Dockerfile
- Verify secrets exist in GitHub repository settings

## Best Practices

### 1. Use Semantic Versioning for Tags

```yaml
image_tag: v${{ github.run_number }}  # v123
# or
image_tag: ${{ github.ref_name }}     # v1.2.3 (for tag pushes)
```

### 2. Optimize Dockerfile Layer Caching

```dockerfile
# Good: Dependencies change less frequently
COPY package.json package-lock.json ./
RUN npm install

# Then copy source code
COPY . .
```

### 3. Use Multi-Stage Builds for Compiled Languages

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o app

FROM alpine:latest
COPY --from=builder /app/app /app
CMD ["/app"]
```

### 4. Set Appropriate Cache Type

- **Simple apps**: `inline`
- **Multi-stage builds**: `stage-and-registry`
- **Size-sensitive**: `registry`

### 5. Include Metadata in Images

```dockerfile
ARG COMMIT_SHA
ARG APP_REVISION
ARG COMMIT_AT

LABEL org.opencontainers.image.revision="${COMMIT_SHA}"
LABEL org.opencontainers.image.version="${APP_REVISION}"
LABEL org.opencontainers.image.created="${COMMIT_AT}"
```

## Integration with ArgoCD

This action is part of the ArgoCD deployment workflow. After building and pushing the image:

1. The image is tagged with the sanitized version
2. ArgoCD can reference this image in Kubernetes manifests
3. The `sanitized_image_tag` output can be used in subsequent workflow steps

Example workflow integration:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.build.outputs.sanitized_image_tag }}
    steps:
      - name: Build and push
        id: build
        uses: fcm-digital/.github/.github/actions/argocd-deployment/build-push-image@main
        with:
          app_name: my-app
          branch_name: ${{ github.ref_name }}
          commit: ${{ github.sha }}
          commit_at: ${{ github.event.head_commit.timestamp }}
          image_tag: v${{ github.run_number }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Update ArgoCD manifest
        run: |
          echo "Deploying image with tag: ${{ needs.build.outputs.image_tag }}"
```

## Additional Resources

- [Docker Build Push Action Documentation](https://github.com/docker/build-push-action)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Google Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review GitHub Actions logs for detailed error messages
3. Contact the platform team for Google Artifact Registry access issues
