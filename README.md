# Helm chart template for OpenAD models

This repo is made to serve as a bootstrap for OpenAD models that run inference on OpenShift. It implements many templates that can take a project and have it running on Openshift in minutes.

## Install This Template
cd into your OpenAD model project root directory and run the following command:
```shell
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git .
```

## Configuration
1. Update the [values.yaml](./helm-chart/values.yaml) file with your model configuration. Replace all instances of `<MODEL_NAME>` with a unique identifier for your model.

2. Update the configuation as you see fit for your model deployment. This is just a baseline to get inference running.


### Example
```yaml
buildConfig:
  name: my-model-build
  gitUri: "" # add github url here
  gitRef: "main" # using main branch.
  strategy: Docker
  dockerfilePath: Dockerfile # path to by Dockefile. (root dir by default)
  sourceSecret: {} # if using ssh for private repos enable this.

image:
  repository: my-model-service
  tag: "latest"
  pullPolicy: IfNotPresent
  env:
    - HF_HOME: "/tmp/.cache/huggingface"
    - MPLCONFIGDIR: "/tmp/.config/matplotlib"
    - LOGGING_CONFIG_PATH: "/tmp/app.log"
    - gt4sd_local_cache_path: "/data/.openad_models"  # !important mount checkpoints to this Volume
    - ENABLE_CACHE_RESULTS: "True"  # enable cache for inference results, enable only for deterministic models. (False by default.)
```

These changes should be enough to run a default OpenAD model.

### SSH Example
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

Update `buildConfig` in the [values.yaml](./helm-chart/values.yaml) configuration.
```yaml
buildConfig:
  ...
  sourceSecret:
    name: my-ssh-privatekey-name
```

## Install the Helm Chart on Openshift
Install the Helm Chart
```shell
helm install <MODEL_NAME> ./helm-chart
```

Start a new build
```shell
oc start-build <MODEL_NAME>-build
```