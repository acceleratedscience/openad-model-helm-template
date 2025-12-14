# Helm Chart for AISUITE

This Helm chart provides a standardized way to deploy AI/ML models on Kubernetes and OpenShift, with a focus on integrating with [AISUITE](https://open.accelerate.science/). It supports building models from source using OpenShift's BuildConfig or deploying pre-built container images.

## Chart Configuration Parameters

The following table lists the configurable parameters of the chart and their default values.

### Core Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of pod replicas to deploy. | `1` |
| `deploymentType` | Defines the deployment strategy. Can be either `"build"` (to build from a Git source) or `"image"` (to pull a pre-built image). | `"build"` |

---

### BuildConfig Settings (for `deploymentType: "build"`)

Configures the OpenShift `BuildConfig` to build a container image from a Git repository.

| Parameter | Description | Default |
| --- | --- | --- |
| `buildConfig.triggerBuild.enabled` | If `true`, a build is automatically triggered when changes are pushed to the repository. | `true` |
| `buildConfig.triggerBuild.type` | Trigger condition: `"gitRefChange"` (on branch changes) or `"always"` (on any ArgoCD sync). | `"gitRefChange"` |
| `buildConfig.triggerBuild.forceReplace` | If `true`, forcefully replaces any pending build pods with a new one. Useful for nodes with limited resources like GPUs. | `false` |
| `buildConfig.gitUri` | The URI of the Git repository (e.g., `"https://github.com/user/repo.git"`). | `""` |
| `buildConfig.gitRef` | The Git branch, tag, or commit to build from. It's recommended to use a tag for reproducible builds. | `"main"` |
| `buildConfig.contextDir` | The subdirectory within the Git repository to use as the build context. | `""` |
| `buildConfig.strategy` | The build strategy to use. Defaults to `"Docker"`. | `"Docker"` |
| `buildConfig.dockerfilePath` | The path to the Dockerfile within the repository. | `"Dockerfile"` |
| `buildConfig.sourceSecret.type` | The type of secret for private Git repositories: `"ssh"` (for SSH keys) or `"pat"` (for GitHub Personal Access Tokens). | `"ssh"` |
| `buildConfig.sourceSecret.name` | The name of the Kubernetes secret containing the credentials. | `""` |

---

### Image Settings (for `deploymentType: "image"`)

Configures the image to be pulled from a container registry.

| Parameter | Description | Default |
| --- | --- | --- |
| `image.name` | The name of the container image to pull (e.g., `"nginx"`). | `""` |
| `image.tag` | The tag of the image to pull (e.g., `"1.21.6"`). | `"latest"` |
| `image.pullSecret` | The name of the Kubernetes secret required to pull from a private registry. | `""` |

---

### Application Settings

General application container settings, common to both deployment types.

| Parameter | Description | Default |
| --- | --- | --- |
| `application.pullPolicy` | The image pull policy. Recommended: `"Always"` for tags like 'latest', `"IfNotPresent"` for specific versions. | `"Always"` |
| `application.env` | Environment variables to inject into the application container. | `null` |
| `application.envFrom` | A list of Secrets or ConfigMaps to inject all their key-value pairs as environment variables. | `[]` |

---

### Service and Ingress

Configuration for networking.

| Parameter | Description | Default |
| --- | --- | --- |
| `service.type` | The type of service: `ClusterIP`, `NodePort`, `LoadBalancer`, or `ExternalName`. | `"ClusterIP"` |
| `service.port` | The port the service will expose. | `80` |
| `service.targetPort` | The internal port of your application container that the service will target. | `8080` |
| `ingress.enabled` | If `true`, an Ingress resource will be created. | `false` |
| `ingress.className` | The class of the Ingress controller to use. | `""` |
| `ingress.annotations` | Annotations for the Ingress resource. | `{}` |
| `ingress.hosts` | Host configuration for the Ingress. | `[{"host": "chart-example.local", ...}]` |
| `ingress.tls` | TLS configuration for the Ingress. | `[]` |

---

### Health Checks

Configure liveness and readiness probes to monitor application health.

| Parameter | Description | Default |
| --- | --- | --- |
| `livenessProbe` | Liveness probe to check if the application is running. If it fails, the container is restarted. Set to `null` to disable. | `httpGet` on port `8081` |
| `readinessProbe` | Readiness probe to check if the application is ready to serve traffic. If it fails, the pod is removed from service. Set to `null` to disable. | `httpGet` on port `8080` |

---

### Resource Management

| Parameter | Description | Default |
| --- | --- | --- |
| `resources.limits.cpu` | Maximum CPU the container can consume. | `"2000m"` |
| `resources.limits.memory` | Maximum memory the container can consume. | `"2Gi"` |
| `resources.requests.cpu` | Minimum CPU the container is guaranteed. | `"1000m"` |
| `resources.requests.memory` | Minimum memory the container is guaranteed. | `"1Gi"` |

---

### Autoscaling

| Parameter | Description | Default |
| --- | --- | --- |
| `autoscaling.enabled` | If `true`, a Horizontal Pod Autoscaler (HPA) is created. | `false` |
| `autoscaling.minReplicas` | Minimum number of replicas. | `1` |
| `autoscaling.maxReplicas` | Maximum number of replicas. | `2` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization to trigger scaling. | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization to trigger scaling. | `80` |

---

### Storage

| Parameter | Description | Default |
| --- | --- | --- |
| `storage.create` | If `true`, a PersistentVolumeClaim (PVC) will be created. | `false` |
| `storage.name` | A unique name for the PVC. | `"s3-data-pvc"` |
| `storage.className` | The storage class to use. If empty, the default is used. | `""` |
| `storage.accessMode` | The access mode for the volume (e.g., `ReadWriteMany`). | `"ReadWriteMany"` |
| `storage.size` | The size of the persistent volume. | `"100Gi"` |
| `volumes` | Defines volumes to be mounted into the pod. | `[{"name": "s3-data-pvc", ...}]` |
| `volumeMounts` | Defines where to mount the volumes within the container. | `[{"name": "s3-data-pvc", "mountPath": "/data"}]` |

---

### S3 Sync Sidecar

Configuration for an optional sidecar container that continuously syncs data with an S3 bucket.

| Parameter | Description | Default |
| --- | --- | --- |
| `s3sync.enabled` | If `true`, the S3 sync sidecar container will be deployed. | `false` |
| `s3sync.image` | The container image for the sidecar. | `"amazon/aws-cli"` |
| `s3sync.region` | The AWS region of the S3 bucket. | `"us-east-1"` |
| `s3sync.syncInterval` | The synchronization interval in seconds. | `"60"` |
| `s3sync.targets` | A list of sync targets, each with an `s3Uri`, `localPath`, and `direction`. | `[]` |

---

### Advanced Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `serviceAccount.create` | If `true`, a ServiceAccount will be created. | `false` |
| `podAnnotations` | Custom annotations to add to the application pods. | `{}` |
| `podLabels` | Custom labels to add to the application pods. | `{}` |
| `podSecurityContext` | Security context for the entire pod. | `{}` |
| `securityContext` | Security context for the application container. | `{}` |
| `nodeSelector` | Assigns pods to specific nodes based on node labels. | `{}` |
| `tolerations` | Allows pods to be scheduled on nodes with matching taints. | `[]` |
| `affinity` | Specifies rules for pod anti-affinity and affinity. | `{}` |
