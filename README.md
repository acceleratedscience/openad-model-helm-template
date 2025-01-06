# Helm chart default template for openad models on Openshift

## Install This Template
```shell
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git
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