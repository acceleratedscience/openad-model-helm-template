# Dockerfile Examples

This directory contains example Dockerfiles for building Python applications with support for private dependencies using SSH or Personal Access Tokens (PAT). Each example demonstrates different approaches to handling credentials in Docker builds.

## Examples Overview

### 1. SSH Dockerfile (`ssh.Dockerfile`)

This Dockerfile uses BuildKit's secret mount feature for secure SSH key handling during build time. This is the recommended approach for local development and CI/CD pipelines that support BuildKit.

#### Key Features:
- Uses multi-stage build to minimize final image size
- Leverages BuildKit's secret mounting for secure SSH key handling
- SSH key is only available during build time and not present in final image
- Uses `uv` package installer for Python dependencies

#### How to Build:
```bash
# Build the image using BuildKit
DOCKER_BUILDKIT=1 docker build \
  --secret id=ssh,src=$HOME/.ssh/id_rsa \
  -f examples/dockerfiles/ssh.Dockerfile \
  -t myapp:latest .
```

### 2. OpenShift SSH Dockerfile (`openshift-ssh.Dockerfile`)

This Dockerfile is designed for OpenShift environments where BuildKit secrets might not be available. It uses a volume mount using Buildah to pass the SSH key.

#### Key Features:
- Similar multi-stage build structure
- Uses volume mount for SSH key injection
- Suitable for OpenShift environments
- Note: Both ssh key and known_hosts should be available during build time as readonly

#### How to Build:
```bash
# Build the image using build argument
docker build \
  --build-arg SSH_PRIVATE_KEY="$(cat $HOME/.ssh/id_rsa)" \
  -f examples/dockerfiles/openshift-ssh.Dockerfile \
  -t myapp:latest .
```

### 3. OpenShift PAT Dockerfile (`pat.Dockerfile`)

This Dockerfile is optimized for OpenShift builds and uses a Github Personal Access Token (PAT) for authenticating with private repositories. It expects the PAT credentials to be injected as environment variables during the build process, which is typical in an OpenShift `BuildConfig` setup.

#### Key Features:
- Uses multi-stage build to keep the final image lean.
- Authenticates with private git repositories using a Github PAT.
- Credentials (`GITHUB_USERNAME` and `GITHUB_TOKEN`) are passed as environment variables.
- Suitable for OpenShift environments where you prefer PAT-based authentication over SSH keys.

#### How to Build:
This Dockerfile is designed to be used within an OpenShift `BuildConfig`. The `BuildConfig` should be configured to pull a secret containing `username` and `password` keys and inject them as `GITHUB_USERNAME` and `GITHUB_TOKEN` environment variables. A local build is not the primary use case, as it would require securely managing and passing these credentials to the `docker build` command.

## Running the Containers

Both containers can be run the same way after building:

```bash
docker run -p 8080:8080 myapp:latest
```

This will start the Python application and expose it on port 8080.

## Security Considerations

1. **SSH Dockerfile (Recommended for Local/CI)**
   - SSH key is only available during build time
   - Key is never stored in image layers
   - Requires BuildKit support
   - Most secure approach for handling SSH keys

2. **OpenShift SSH Dockerfile**
   - SSH key is passed asvolume mount
   - Should be used only when BuildKit secrets are not available
   - Consider using OpenShift's secrets management for production

3. **OpenShift PAT Dockerfile**
   - Github PAT is passed as environment variables during the build.
   - These variables are not persisted in the final image layers due to the multi-stage build.
   - This method relies on the security of the OpenShift build environment and its secret management.

## Best Practices

1. Always use multi-stage builds to minimize final image size
2. Prefer BuildKit secrets over build arguments for sensitive data
3. Remove SSH keys and other sensitive data before the final stage
4. Keep base images updated for security patches
5. Use specific version tags for base images instead of 'latest'
6. Regularly update dependencies and base images

## Common Issues

1. **SSH Key Permissions**: Ensure SSH keys have correct permissions (600)
2. **Host Key Verification**: The Dockerfiles include `ssh-keyscan` to prevent host key verification errors
3. **BuildKit Support**: Ensure BuildKit is enabled when using `ssh.Dockerfile`

## Environment Setup

Both Dockerfiles expect:
- A Python application with a `main.py` file
- Dependencies that can be installed via pip/uv
- SSH key or Personal Access Token (PAT) for accessing private repositories
- Port 8080 available for the application

Remember to replace or modify the default command (`CMD ["python", "main.py"]`) if your application uses a different entrypoint.
