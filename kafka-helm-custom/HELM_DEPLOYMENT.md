# Kafka Helm Chart - Deployment Guide

Simple, production-ready Helm chart for Apache Kafka.

## ⚠️ NAMESPACE REQUIREMENT

**Important**: The `-n` flag must match the `namespace` value in your command!

```bash
# ✅ CORRECT
helm install kafka . -n kfk --create-namespace \
  --set namespace=kfk \
  ...

# ❌ WRONG (causes "invalid ownership metadata" error)
helm install kafka . -n kfk --create-namespace \
  ...missing --set namespace=kfk
```

See **HELM_INSTALLATION_TROUBLESHOOTING.md** for solutions if you encounter namespace errors.

---

## Prerequisites

- Kubernetes 1.19+
- Helm 3+
- kubectl configured
- Storage provisioner available

## Chart Structure

```
kafka-helm-custom/
└── kafka/
    ├── Chart.yaml              # Chart metadata
    ├── values.yaml              # Configuration parameters
    └── templates/
        ├── rbac.yaml            # ServiceAccount, ClusterRole, ClusterRoleBinding
        ├── configmap.yaml       # Kafka configuration
        ├── statefulset.yaml     # Kafka broker deployment
        ├── service.yaml         # Services (headless, ClusterIP, LoadBalancer)
        └── kafka-ui.yaml        # Kafka UI deployment
```

## Quick Start

### 1. Install Helm Chart

```bash
# Navigate to chart directory
cd kafka-helm-custom

# Install with default values
helm install kafka ./kafka -n kafka-ns --create-namespace

# Or with custom values
helm install kafka ./kafka -n kafka-ns --create-namespace \
  -f kafka/values.yaml \
  --set kafka.replicas=3 \
  --set kafka.storage.size=50Gi
```

### 2. Check Status

```bash
# Get pod status
kubectl get pods -n kafka-ns -w

# Get services
kubectl get svc -n kafka-ns

# Get helm release
helm list -n kafka-ns
helm status kafka -n kafka-ns
```

### 3. Access Services

```bash
# Kafka UI (web dashboard)
kubectl port-forward -n kafka-ns svc/kafka-ui 8080:8080
# Visit: http://localhost:8080

# Kafka broker (CLI)
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka:4.0.0-debian-12 \
  --restart=Never kafka-client bash
```

## Configuration

### Basic Configuration Parameters

Edit `values.yaml` or use `--set` flags:

```bash
# Image configuration (use custom or different Docker images)
--set image.registry="docker.io"               # Docker registry (leave empty for default)
--set image.repository="kafka"                 # Image name
--set image.tag="kraft-kraft-v1"               # Image tag/version
--set image.pullPolicy=IfNotPresent             # When to pull: Always, IfNotPresent, Never

# Image examples:
# Using local/custom image
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="" \
  --set image.repository="kafka" \
  --set image.tag="kraft-kraft-v1"

# Using Docker Hub Apache Kafka image
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="apache/kafka" \
  --set image.tag="4.1.1"

# Using private registry
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="my-private-registry.com" \
  --set image.repository="kafka" \
  --set image.tag="v1.0-custom"

# Kafka UI image
--set kafkaUI.image.registry="docker.io"
--set kafkaUI.image.repository="provectuslabs/kafka-ui"
--set kafkaUI.image.tag="latest"

# Storage configuration
--set kafka.storage.size=50Gi
--set kafka.storage.className=longhorn

# Replicas (brokers)
--set kafka.replicas=3

# Memory
--set kafka.jvmHeap.min=1G
--set kafka.jvmHeap.max=2G

# CPU & Memory limits
--set kafka.resources.requests.cpu=1000m
--set kafka.resources.requests.memory=2Gi
--set kafka.resources.limits.cpu=4000m
--set kafka.resources.limits.memory=4Gi

# Replication (for production with 3+ brokers)
--set kafka.replication.offsetsTopicReplicationFactor=3
--set kafka.replication.minInSyncReplicas=2

# Network threads (performance tuning)
--set kafka.performance.networkThreads=16
--set kafka.performance.ioThreads=16

# Kafka UI
--set kafkaUI.enabled=true
--set kafkaUI.replicas=1
```

### Using Custom values.yaml

Create `custom-values.yaml`:

```yaml
kafka:
  replicas: 3
  storage:
    size: 100Gi
    className: longhorn
  jvmHeap:
    min: 2G
    max: 4G
  replication:
    offsetsTopicReplicationFactor: 3
    minInSyncReplicas: 2
  performance:
    networkThreads: 16
    ioThreads: 16

kafkaUI:
  enabled: true
  replicas: 1
  service:
    type: LoadBalancer
```

Deploy with custom values:

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace -f custom-values.yaml
```

## Common Deployment Scenarios

### Development (Single Broker, No Auth)

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=1 \
  --set kafka.storage.size=20Gi \
  --set kafka.jvmHeap.min=512M \
  --set kafka.jvmHeap.max=1G \
  --set kafkaUI.enabled=true
```

### Staging (3 Brokers, Basic Config)

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=3 \
  --set kafka.storage.size=50Gi \
  --set kafka.replication.offsetsTopicReplicationFactor=3 \
  --set kafka.replication.minInSyncReplicas=2 \
  --set kafka.jvmHeap.min=1G \
  --set kafka.jvmHeap.max=2G \
  --set kafka.resources.requests.cpu=1000m \
  --set kafka.resources.limits.cpu=2000m
```

### Production (5 Brokers, High Performance)

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=5 \
  --set kafka.storage.size=200Gi \
  --set kafka.storage.className=longhorn \
  --set kafka.replication.offsetsTopicReplicationFactor=5 \
  --set kafka.replication.minInSyncReplicas=3 \
  --set kafka.jvmHeap.min=4G \
  --set kafka.jvmHeap.max=8G \
  --set kafka.resources.requests.cpu=4000m \
  --set kafka.resources.requests.memory=8Gi \
  --set kafka.resources.limits.cpu=8000m \
  --set kafka.resources.limits.memory=16Gi \
  --set kafka.performance.networkThreads=32 \
  --set kafka.performance.ioThreads=32 \
  --set kafka.performance.lingerMs=50
```

## Helm Commands

### Install

```bash
# Basic installation
helm install kafka ./kafka -n kafka-ns --create-namespace

# With values file
helm install kafka ./kafka -n kafka-ns --create-namespace -f values.yaml

# With parameter overrides
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=3 \
  --set kafka.storage.size=50Gi
```

### Upgrade

```bash
# Upgrade chart (scale brokers)
helm upgrade kafka ./kafka -n kafka-ns \
  --set kafka.replicas=5

# Upgrade with new values file
helm upgrade kafka ./kafka -n kafka-ns -f new-values.yaml

# Upgrade and reuse existing values
helm upgrade kafka ./kafka -n kafka-ns -f values.yaml --reuse-values
```

### Uninstall

```bash
# Remove chart (keeps PVCs)
helm uninstall kafka -n kafka-ns

# Remove chart and PVCs
kubectl delete pvc -n kafka-ns --all
kubectl delete namespace kafka-ns
```

### Status & Debugging

```bash
# Get release status
helm status kafka -n kafka-ns

# List releases
helm list -n kafka-ns

# Get values (installed)
helm get values kafka -n kafka-ns

# Get manifest
helm get manifest kafka -n kafka-ns > kafka-manifest.yaml

# Test (dry-run)
helm install kafka ./kafka --dry-run --debug -n kafka-ns
```

## Configuration Reference

### Namespace

```yaml
namespace: kafka-ns
```

### Image

```yaml
image:
  registry: docker.io
  repository: bitnami/kafka
  tag: "4.0.0-debian-12"
  pullPolicy: IfNotPresent
```

### Kafka Configuration

```yaml
kafka:
  replicas: 1                    # Number of brokers
  clusterId: "..."               # Unique cluster identifier
  processRoles: "broker,controller"

  listeners:
    client:
      port: 9092
      protocol: "PLAINTEXT"
    controller:
      port: 9093
      protocol: "PLAINTEXT"
    internal:
      port: 9094
      protocol: "PLAINTEXT"

  replication:
    offsetsTopicReplicationFactor: 1
    transactionLogReplicationFactor: 1
    minInSyncReplicas: 1
    defaultReplicationFactor: 1

  storage:
    enabled: true
    size: "20Gi"
    className: "longhorn"
    mountPath: "/bitnami/kafka/data"
    logs:
      retentionHours: 168
      segmentBytes: "1073741824"

  performance:
    networkThreads: 8
    ioThreads: 8
    socketSendBufferBytes: "102400"
    socketReceiveBufferBytes: "102400"
    batchSize: "16384"
    lingerMs: "10"

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

  jvmHeap:
    min: "512M"
    max: "1G"
```

### Kafka UI Configuration

```yaml
kafkaUI:
  enabled: true
  replicas: 1
  image:
    registry: docker.io
    repository: provectuslabs/kafka-ui
    tag: "latest"
  resources:
    requests:
      cpu: "250m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
  service:
    type: LoadBalancer
    port: 8080
```

### Service

```yaml
service:
  type: LoadBalancer          # ClusterIP, NodePort, LoadBalancer
  port: 9092
  internalPort: 9094
```

### Security

```yaml
security:
  securityContext:
    enabled: true
    runAsUser: 1001
    runAsNonRoot: true
    fsGroup: 1001

rbac:
  enabled: true
```

### Health Checks

```yaml
healthChecks:
  enabled: true
  liveness:
    enabled: true
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    enabled: true
    initialDelaySeconds: 10
    periodSeconds: 5
```

### Affinity

```yaml
affinity:
  podAntiAffinity:
    enabled: true
    type: "preferred"          # preferred or required
```

## Troubleshooting

### Broker won't start

```bash
# Check logs
kubectl logs -n kafka-ns kafka-0

# Check pod status
kubectl describe pod -n kafka-ns kafka-0

# Check events
kubectl get events -n kafka-ns
```

### Can't connect to broker

```bash
# Test from another pod
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka test bash
nc -zv kafka 9092

# Check service
kubectl get svc -n kafka-ns
```

### Storage issues

```bash
# Check PVC
kubectl get pvc -n kafka-ns
kubectl describe pvc -n kafka-ns kafka-data-kafka-0

# Check storage class
kubectl get storageclass
```

### Upgrade issues

```bash
# Rollback to previous release
helm rollback kafka -n kafka-ns

# Verify upgrade
helm diff upgrade kafka ./kafka -n kafka-ns
```

## Advanced: Custom values Examples

### High Availability (5 nodes)

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=5 \
  --set kafka.replication.offsetsTopicReplicationFactor=5 \
  --set kafka.replication.minInSyncReplicas=3 \
  --set kafka.storage.size=200Gi \
  --set kafka.performance.networkThreads=32
```

### Low Latency Setup

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.performance.lingerMs=0 \
  --set kafka.performance.batchSize=8192 \
  --set kafka.jvmHeap.min=2G \
  --set kafka.jvmHeap.max=4G
```

### High Throughput Setup

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.performance.networkThreads=32 \
  --set kafka.performance.ioThreads=32 \
  --set kafka.performance.lingerMs=50 \
  --set kafka.performance.batchSize=32768 \
  --set kafka.jvmHeap.min=4G \
  --set kafka.jvmHeap.max=8G
```

### Using Custom Docker Images

**Local/Custom KRaft Kafka Image:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="" \
  --set image.repository="kafka" \
  --set image.tag="kraft-kraft-v1" \
  --set kafka.replicas=1
```

**Apache Kafka from Docker Hub:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="apache/kafka" \
  --set image.tag="4.1.1" \
  --set kafka.replicas=3
```

**Bitnami Kafka Image:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="bitnami/kafka" \
  --set image.tag="4.1.1-debian-12" \
  --set kafka.replicas=3
```

**Private Registry:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="my-registry.company.com" \
  --set image.repository="kafka/production" \
  --set image.tag="v1.0" \
  --set image.pullPolicy=Always \
  --set kafka.replicas=3
```

**Mixed Images (Kafka + Kafka UI from different registries):**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="apache/kafka" \
  --set image.tag="4.1.1" \
  --set kafkaUI.image.registry="my-registry.io" \
  --set kafkaUI.image.repository="kafka-ui" \
  --set kafkaUI.image.tag="custom-v1" \
  --set kafka.replicas=3
```

## Using Custom values.yaml with Images

Create `custom-values.yaml`:

```yaml
# Kafka broker image
image:
  registry: my-registry.io
  repository: kafka/custom
  tag: v2.0
  pullPolicy: Always

# Kafka UI image
kafkaUI:
  enabled: true
  image:
    registry: my-registry.io
    repository: kafka-ui
    tag: v1.2.0
    pullPolicy: Always

# Cluster settings
kafka:
  replicas: 3
  storage:
    size: 100Gi
    className: longhorn
```

Deploy with custom values:
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace -f custom-values.yaml
```

## Useful Commands

```bash
# Quick test client
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka:4.0.0-debian-12 \
  --restart=Never kafka-client bash

# Create topic
kafka-topics.sh --create --bootstrap-server kafka:9092 \
  --topic test --partitions 3 --replication-factor 1

# List topics
kafka-topics.sh --list --bootstrap-server kafka:9092

# Produce message
kafka-console-producer.sh --broker-list kafka:9092 --topic test

# Consume messages
kafka-console-consumer.sh --bootstrap-server kafka:9092 \
  --topic test --from-beginning

# Port forward UI
kubectl port-forward -n kafka-ns svc/kafka-ui 8080:8080

# Check broker status
kubectl logs -n kafka-ns kafka-0 -f

# Scale to 3 brokers
helm upgrade kafka ./kafka -n kafka-ns --set kafka.replicas=3
```

## References

- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Bitnami Kafka Container](https://github.com/bitnami/containers/tree/main/bitnami/kafka)
- [Helm Documentation](https://helm.sh/docs/)
