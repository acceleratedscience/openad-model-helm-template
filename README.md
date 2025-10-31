# Helm chart template for OpenAD models

This repo is made to serve as a bootstrap for OpenAD models that run inference on OpenShift. It implements many templates that can take a project and have it running on Openshift in minutes.

## Dependencies

- [Helm](https://helm.sh/)
- [Helmfile](https://github.com/helmfile/helmfile)
- [`oc` cli tool](https://docs.openshift.com/container-platform/4.17/cli_reference/openshift_cli/getting-started-cli.html)
- [yq](https://github.com/mikefarah/yq)

Install all Helmfile dependencies:
```bash
helmfile init
```

## Setup

### 1. Install This Template

In your project root run the install wizard
> check out the install script [here](./scripts/install.sh)

```shell
curl -sSL https://ibm.biz/BdG3Ab | bash
```

<!-- ```shell
curl -sSL https://raw.githubusercontent.com/acceleratedscience/openad-model-helm-template/refs/heads/main/scripts/install.sh | bash
``` -->

### 2. Configuration

A few defaults have already been configured for serving models in openad but configure as you wish.


1. Update the [values](./helm/values.yaml) file with your configuration.

2. Optionally update the [helmfile](./helmfile.yaml)

### 3. (Optional) Configure A Private Repo

There are two ways to configure a private repo: using an SSH key or a Personal Access Token (PAT). For detailed examples of Dockerfiles that handle these authentication methods, see the [Dockerfile Examples documentation](./examples/dockerfiles/README.md).

#### Using SSH Key
Create ssh key secret `my-ssh-privatekey-name` (create a unique name).

```shell
oc create secret generic my-ssh-privatekey-name \
  --from-file=ssh-privatekey=$HOME/.ssh/YOUR_PRIVATE_SSH_KEY_HERE \
  --type=kubernetes.io/ssh-auth
```

Grant Access to the Builder Service Account for the Secret
```shell
oc secrets link builder my-ssh-privatekey-name
```

Update `buildConfig` with the `sourceSecret` in the [values](./helm/values.yaml) configuration.

> check out an example Dockerfile [here](./examples/dockerfiles/openshift-ssh.Dockerfile)
```yaml
buildConfig:
  ...
  sourceSecret:
    type: ssh
    name: my-ssh-privatekey-name
```

#### Using Github Personal Access Token (PAT)
Create auth secret `github-credentials` from github token.
```bash
oc create secret generic github-credentials \
  --from-literal=username=__token__ \
  --from-literal=password=<your-token> \
  --type=kubernetes.io/basic-auth
```

Update `buildConfig` with the `sourceSecret` in the [values](./helm/values.yaml) configuration.

> check out an example Dockerfile [here](./examples/dockerfiles/pat.Dockerfile)

```yaml
buildConfig:
  strategy: Docker
  dockerfilePath: openshift/Dockerfile.openshift
  sourceSecret:  # Secret containing the credentials
    type: pat    # "ssh" or "pat"
    name: github-credentials
```

## Storage

This Helm chart can be configured to create a `PersistentVolumeClaim` (PVC) for storing data. Please refer to the `storage` section in `helm/values.yaml` for configuration options.

**Important Note:** When you create a PVC with this chart, it will not be deleted when you uninstall the Helm release. This is to prevent accidental data loss. You must manually delete the PVC if you no longer need the data.

## Best Practices

### Choosing a Git Reference (`gitRef`)

When `deploymentType` is set to `build`, the `buildConfig.gitRef` determines which version of your code is built. The strategy you choose depends on your environment.

#### For Production Environments
It is strongly recommended to use Git tags (e.g., `v1.0.0`) for production builds. This ensures that your deployments are predictable, consistent, and tied to a specific, immutable version of your code.

```yaml
buildConfig:
  gitRef: "v1.0.0"  # <-- Recommended for production
```

#### For Development and CI/CD Environments
Using a branch name (e.g., `main` or `develop`) is suitable for development or continuous integration workflows. This allows you to automatically build and deploy the latest code from a branch. This template includes an optional `trigger-build-job.yaml` that can be enabled in `values.yaml`. When used with ArgoCD, this job will automatically start a new build after every sync, which is ideal for tracking a branch.

```yaml
buildConfig:
  gitRef: "main"  # <-- Suitable for development/CI
```


## ArgoCD Deployment

This template can be used with ArgoCD to manage deployments.

### 1. Prerequisites

Before deploying with ArgoCD, you need to grant the necessary permissions.

**Grant ArgoCD Permissions**

The ArgoCD application controller needs permissions to manage resources in your target namespace (e.g., `openad-models`).

```shell
oc adm policy add-role-to-user edit \
  -n openad-models \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
```

**Grant Service Account Permissions**

If your application includes jobs or builds that run under a service account (like the `default` service account), it may also need permissions.

```shell
oc adm policy add-role-to-user edit -n openad-models -z default
```

### 2. Deploy the Application

After running the install wizard, an ArgoCD `Application` manifest will be created at `charts/argocd/application.yaml`.

To deploy your application, apply this manifest to your cluster:

```shell
oc apply -f charts/argocd/application.yaml
```

ArgoCD will then pick up this application and deploy the Helm chart based on the configuration.

## Manual Deployment with Helmfile
Install the Helm Chart
```shell
helmfile -f charts/helmfile.yaml apply
```

Start a new build to have running deployment
```shell
oc start-build RELEASE_NAME
```

## Troubleshooting

### SSH build fails
SSH can cause a lot of headaches for building your projects. One issue with OpenShift is passing your ssh key secret through to your Dockefile build. You can create a seperate Dockefile for this approach and point the values config `dockerfilePath` to it. *This currently works using the example for an ssh key secret but may not be suitable for production builds.*

```Dockerfile
# Copy the SSH key from the secret environment variable
# Not best practice to store ssh key. will need to change for prod.
ARG SSH_PRIVATE_KEY
RUN mkdir -p /root/.ssh && \
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa

# Setup SSH and install dependencies using BuildKit secret mount
RUN ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
# install dependencies
RUN pip install -e .
```
