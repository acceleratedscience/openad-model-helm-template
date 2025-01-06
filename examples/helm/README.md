# OpenAD Model Helm Chart Values

This document describes the configurable values for the OpenAD Model Helm chart. The example `values.yaml` provides a template for deploying OpenAD models on Kubernetes/OpenShift clusters.

## Core Configuration

### Replica Count
```yaml
replicaCount: 1
```
Number of pod replicas to run. Adjust based on your scaling needs.

### BuildConfig (OpenShift)
```yaml
buildConfig:
  name: example-model-build
  gitUri: "https://github.com/username/repo"
  gitRef: "main"
  strategy: Docker
  dockerfilePath: Dockerfile
  sourceSecret: {}
```
- `name`: Name of the BuildConfig resource
- `gitUri`: Git repository URL containing your model code
- `gitRef`: Git branch, tag, or commit to build from
- `strategy`: Build strategy (Docker or Source)
- `dockerfilePath`: Path to the Dockerfile in your repository
- `sourceSecret`: Git credentials if needed for private repositories

### Image Configuration
```yaml
image:
  repository: example-model-service
  tag: "latest"
  pullPolicy: IfNotPresent
  env:
    - HF_HOME: "/tmp/.cache/huggingface"
    - MPLCONFIGDIR: "/tmp/.config/matplotlib"
    - LOGGING_CONFIG_PATH: "/tmp/app.log"
    - gt4sd_local_cache_path: "/data/.openad_models"
    - ENABLE_CACHE_RESULTS: "False"
```
- `repository`: Name of your container image
- `tag`: Image tag to use
- `pullPolicy`: When to pull new images
- `env`: Environment variables:
  - `HF_HOME`: HuggingFace cache directory
  - `MPLCONFIGDIR`: Matplotlib configuration directory
  - `LOGGING_CONFIG_PATH`: Application log file path
  - `gt4sd_local_cache_path`: OpenAD models cache path (important: mount checkpoints here)
  - `ENABLE_CACHE_RESULTS`: Enable caching of inference results (for deterministic models only)

## Networking

### Service Configuration
```yaml
service:
  type: ClusterIP
  port: 80
  targetPort: 8080
```
- `type`: Service type (ClusterIP, NodePort, LoadBalancer)
- `port`: External port for the service
- `targetPort`: Container port the service forwards to

### Ingress Configuration
```yaml
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: model-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
```
Configure ingress if you need external access to your model service.

## Resources and Scaling

### Resource Requests and Limits
```yaml
resources:
  limits:
    cpu: 10000m
    memory: "10Gi"
  requests:
    cpu: 1000m
    memory: "3Gi"
```
Adjust CPU and memory based on your model's requirements. Uncomment `nvidia.com/gpu` settings if GPU support is needed.

### Autoscaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 2
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```
Configure Horizontal Pod Autoscaling (HPA) settings.

## Storage

### Volumes and Mounts
```yaml
volumes:
  - name: s3-data-pvc

volumeMounts:
  - name: s3-data-pvc
    mountPath: "/data"
```
Configure persistent storage for your model data.

## Health Checks

### Liveness and Readiness Probes
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8081
  initialDelaySeconds: 10
  periodSeconds: 15

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
```
Health check configuration to ensure your model service is running properly.

## Advanced Configuration

### Node Selection and Tolerations
```yaml
nodeSelector: {}
tolerations: []
affinity: {}
```
Configure pod scheduling preferences:
- Use `nodeSelector` to run on specific nodes
- Use `tolerations` for running on tainted nodes (e.g., GPU nodes)
- Use `affinity` rules for advanced scheduling requirements

### Security Context
```yaml
podSecurityContext: {}
securityContext: {}
```
Configure security settings for pods and containers.

### Service Account
```yaml
serviceAccount:
  create: false
  automount: true
  annotations: {}
  name: ""
```
Configure service account settings if your model needs specific Kubernetes API permissions.
