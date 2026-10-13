# OpenTelemetry Collector Helm Chart Deployment Guide

This repository contains the official Kubernetes Helm chart for deploying the **OpenTelemetry Collector** (Chart version `0.174.2`, Collector version `0.161.0`).

Use this guide to configure, install, customize, and upgrade the OpenTelemetry Collector across Kubernetes environments.

---

## 📋 Table of Contents

1. [Mandatory & Recommended Values](#mandatory--recommended-values)
2. [Prerequisites](#prerequisites)
3. [Quick Start Installation](#quick-start-installation)
4. [Deployment Patterns](#deployment-patterns)
   - [Option A: Deployment Mode (Gateway / Aggregator)](#option-a-deployment-mode-gateway--aggregator)
   - [Option B: DaemonSet Mode (Node Agent)](#option-b-daemonset-mode-node-agent)
5. [Commands Reference](#commands-reference)
   - [Validating and Linting](#validating-and-linting)
   - [Installing the Chart](#installing-the-chart)
   - [Updating Configuration](#updating-configuration)
   - [Updating the Docker Image / Tag](#updating-the-docker-image--tag)
   - [Checking Status & Logs](#checking-status--logs)
   - [Rollback & Uninstall](#rollback--uninstall)
6. [Ready-to-Use Values Files](#ready-to-use-values-files)

---

## 🔑 Mandatory & Recommended Values

When deploying this chart, the default `values.yaml` leaves certain fields empty to allow teams to choose their topology. The following values **must** or **should** be supplied:

### 1. Mandatory Values

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `mode` | `string` | **Yes** | Deployment topology. Must be set to `deployment`, `daemonset`, or `statefulset`. If omitted, no pods will be deployed. |
| `image.repository` | `string` | **Yes** | Docker image repository. Must be explicitly set (e.g., `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s` or `otel/opentelemetry-collector-contrib`). |
| `command.name` | `string` | **Yes** | Executable name inside the container. Must match the image binary: `otelcol-k8s` for the k8s image, `otelcol-contrib` for contrib, or `otelcol` for core. |

### 2. Recommended Production Values

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `image.tag` | `string` | Chart `appVersion` (`0.161.0`) | Specific version tag for the collector container. |
| `image.pullPolicy` | `string` | `IfNotPresent` | Image pull policy (`IfNotPresent`, `Always`). |
| `resources.limits.memory` | `string` | none | **Crucial:** Used by `useGOMEMLIMIT` and the collector's `memory_limiter` processor to prevent OOM errors. |
| `resources.limits.cpu` | `string` | none | Maximum CPU allowed for collector pod. |
| `resources.requests` | `object` | none | Initial CPU and Memory reservations for scheduling. |
| `replicaCount` | `int` | `1` | Number of replicas (used when `mode: deployment`). |
| `serviceAccount.create` | `bool` | `true` | Creates dedicated service account for RBAC. |
| `clusterRole.create` | `bool` | `false` (or auto via presets) | Creates ClusterRole and bindings (required when scraping k8s attributes/events/kubelet). |
| `config.exporters` | `object` | `debug: {}` | Destination observability backends (e.g. OTLP, Prometheus, Tempo, Datadog, etc.). |

---

## 🛠️ Prerequisites

- **Kubernetes**: 1.24+
- **Helm**: 3.x+ or 4.x+
- **kubectl** configured with access to your target Kubernetes cluster

---

## 🚀 Quick Start Installation

### Step 1: Clone or Download the Repository

```bash
git clone <your-git-repo-url>
cd helmworkspace
```

### Step 2: Create a Custom `my-values.yaml`

Choose either [Gateway Mode](#option-a-deployment-mode-gateway--aggregator) or [Node Agent Mode](#option-b-daemonset-mode-node-agent) and create a `my-values.yaml` file (or use the pre-built files in the `examples/` directory).

### Step 3: Install the Chart

```bash
helm install opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  --create-namespace \
  -f my-values.yaml
```

---

## 🏗️ Deployment Patterns

### Option A: Deployment Mode (Gateway / Aggregator)

Best for:
- Receiving OTLP traces, metrics, and logs from application microservices SDKs
- Centralized data routing, enrichment, filtering, and load-balancing
- Multiple replicas behind a Kubernetes Service

**Sample Configuration (`examples/values-deployment.yaml`):**

```yaml
mode: deployment

image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
  tag: "0.161.0"
  pullPolicy: IfNotPresent

command:
  name: "otelcol-k8s"

replicaCount: 2

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 512Mi

service:
  type: ClusterIP

ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318

config:
  exporters:
    debug:
      verbosity: basic
    # Example external OTLP endpoint (e.g., Tempo, Grafana Cloud, Datadog)
    # otlp:
    #   endpoint: "tempo.monitoring.svc.cluster.local:4317"
    #   tls:
    #     insecure: true

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [debug]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [debug]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [debug]
```

---

### Option B: DaemonSet Mode (Node Agent)

Best for:
- Scraping host system metrics (CPU, RAM, disk, network)
- Scraping container `stdout`/`stderr` logs from `/var/log/pods`
- Scraping Kubelet stats and adding Kubernetes metadata (`k8s_attributes`)

**Sample Configuration (`examples/values-daemonset.yaml`):**

```yaml
mode: daemonset

image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
  tag: "0.161.0"
  pullPolicy: IfNotPresent

command:
  name: "otelcol-k8s"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

presets:
  logsCollection:
    enabled: true
    storeCheckpoints: true
  hostMetrics:
    enabled: true
  kubeletMetrics:
    enabled: true
  kubernetesAttributes:
    enabled: true
    extractAllPodLabels: true

serviceAccount:
  create: true

clusterRole:
  create: true
```

---

## 💻 Commands Reference

### 1. Validating and Linting

Before applying any changes, always test the chart syntax and rendered YAML output:

```bash
# Lint the chart against your values file
helm lint ./charts/opentelemetry-collector -f my-values.yaml

# Render templates locally to preview the generated Kubernetes manifests
helm template otel ./charts/opentelemetry-collector -f my-values.yaml > rendered.yaml
```

---

### 2. Installing the Chart

To install the chart into a target namespace:

```bash
helm install opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  --create-namespace \
  -f my-values.yaml
```

---

### 3. Updating Configuration

Whenever you modify `my-values.yaml` (e.g. adding exporters, changing resource limits, or tuning batch processor):

```bash
helm upgrade opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  -f my-values.yaml
```

---

### 4. Updating the Docker Image / Tag

#### Method 1: Via Values File (Recommended)
Edit `my-values.yaml`:
```yaml
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
  tag: "0.162.0" # updated version
```
Then run:
```bash
helm upgrade opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  -f my-values.yaml
```

#### Method 2: On-the-Fly via CLI Flags
To quickly test or roll out a new image version without modifying the file:
```bash
helm upgrade opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  -f my-values.yaml \
  --set image.tag="0.162.0"
```

To switch image repository to contrib:
```bash
helm upgrade opentelemetry-collector ./charts/opentelemetry-collector \
  --namespace opentelemetry \
  -f my-values.yaml \
  --set image.repository="otel/opentelemetry-collector-contrib" \
  --set command.name="otelcol-contrib"
```

---

### 5. Checking Status & Logs

```bash
# Check pod status and rollout
kubectl get pods -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector

# Tail live collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector -f

# Check Kubernetes Service endpoints
kubectl get svc -n opentelemetry
```

---

### 6. Rollback & Uninstall

```bash
# View deployment revision history
helm history opentelemetry-collector -n opentelemetry

# Rollback to previous revision
helm rollback opentelemetry-collector 1 -n opentelemetry

# Uninstall / Delete the release completely
helm uninstall opentelemetry-collector -n opentelemetry
```

---

## 📁 Ready-to-Use Values Files

Three pre-tested configurations are provided in the `examples/` directory:
- `examples/values-deployment.yaml`: Pre-configured for gateway mode.
- `examples/values-daemonset.yaml`: Pre-configured for node-agent mode with logs, host metrics, and kubelet metrics.
- `examples/values-gcp-cloud-monitoring.yaml`: Pre-configured for pulling/scraping metrics from **Google Cloud Monitoring** API or exporting metrics to GCP.

---

## ☁️ Google Cloud Monitoring Integration

To collect metrics directly from **Google Cloud Monitoring** (Compute Engine, Cloud SQL, Pub/Sub, Cloud Run, GKE, etc.):

1. **Use the Contrib Image**: The `googlecloudmonitoring` receiver is bundled in `otel/opentelemetry-collector-contrib` (`command.name: otelcol-contrib`).
2. **Deploy as a Single Replica**: Run with `mode: deployment` and `replicaCount: 1` to prevent duplicate metric queries and avoid double API billing.
3. **Grant IAM Permissions**: The service account requires `roles/monitoring.viewer` (to read/pull metrics) or `roles/monitoring.metricWriter` (to push metrics).
4. **Deploy**:
   ```bash
   helm upgrade --install otel-gcp ./charts/opentelemetry-collector \
     --namespace opentelemetry \
     --create-namespace \
     -f ./examples/values-gcp-cloud-monitoring.yaml
   ```

