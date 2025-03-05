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
curl -sSL https://raw.githubusercontent.com/acceleratedscience/openad-model-helm-template/refs/heads/main/scripts/install.sh | bash
```

### 2. Configuration

1. Update the [values](./helm-chart/values.yaml) file with your configuration.

2. Optionally update the [helmfile](./helmfile.yaml)

### 3. (Optional) Configure A Private Repo
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

Update `buildConfig` with the `sourceSecret` in the [values](./helm-chart/values.yaml) configuration.
```yaml
buildConfig:
  ...
  sourceSecret:
    name: my-ssh-privatekey-name
```

## Install the Helm Chart on Openshift
Install the Helm Chart
```shell
helmfile apply
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