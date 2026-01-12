# Helm Chart - Configuration Reference

Quick parameter reference for Helm deployment.

## ⚠️ IMPORTANT: Namespace Configuration

The `-n` flag in `helm install` must match the `namespace` value:

```bash
# ✅ CORRECT - Both are 'kfk'
helm install kafka ./kafka -n kfk --create-namespace \
  --set namespace=kfk \
  --set kafka.replicas=1

# ❌ WRONG - 'kfk' vs 'kafka-ns' mismatch (causes ownership error)
helm install kafka ./kafka -n kfk --create-namespace \
  --set kafka.replicas=1
# Missing: --set namespace=kfk
```

**Rule**: `helm install ... -n <NAMESPACE>` must use `--set namespace=<NAMESPACE>`

---

## Installation Commands

### Development Setup
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set namespace=kafka-ns \
  --set kafka.replicas=1 \
  --set kafka.storage.size=20Gi
```

### Production Setup (3 Brokers)
```bash
helm install kafka ./kafka -n production --create-namespace \
  --set namespace=production \
  --set kafka.replicas=3 \
  --set kafka.storage.size=100Gi \
  --set kafka.replication.offsetsTopicReplicationFactor=3 \
  --set kafka.replication.minInSyncReplicas=2 \
  --set kafka.resources.requests.cpu=1000m \
  --set kafka.resources.requests.memory=2Gi
```

### High Performance Setup (5 Brokers)
```bash
helm install kafka ./kafka -n production --create-namespace \
  --set namespace=production \
  --set kafka.replicas=5 \
  --set kafka.storage.size=200Gi \
  --set kafka.replication.offsetsTopicReplicationFactor=5 \
  --set kafka.replication.minInSyncReplicas=3 \
  --set kafka.performance.networkThreads=32 \
  --set kafka.performance.ioThreads=32 \
  --set kafka.jvmHeap.min=4G \
  --set kafka.jvmHeap.max=8G \
  --set kafka.resources.requests.cpu=4000m \
  --set kafka.resources.requests.memory=8Gi \
  --set kafka.resources.limits.cpu=8000m \
  --set kafka.resources.limits.memory=16Gi
```

## Key Parameters

### Namespace Configuration (⚠️ IMPORTANT)
```bash
# MUST match the -n flag in helm install command
--set namespace=kfk                             # Use with: helm install ... -n kfk
--set namespace=production                      # Use with: helm install ... -n production
--set namespace=staging                         # Use with: helm install ... -n staging

# If mismatch, you'll get: "invalid ownership metadata" error
# Always remember: helm -n <NAMESPACE> ... --set namespace=<NAMESPACE>
```

### Image Configuration
```bash
# Use custom Kafka image (default: test-kfk:latest)
--set image.registry="docker.io"               # Registry URL (leave empty for default)
--set image.repository="kafka"                 # Image repository name
--set image.tag="kraft-kraft-v1"               # Image tag/version
--set image.pullPolicy=IfNotPresent             # Pull policy: Always, IfNotPresent, Never

# Examples:
# Local image
--set image.registry="" --set image.repository="kafka" --set image.tag="kraft-kraft-v1"

# Docker Hub
--set image.registry="docker.io" --set image.repository="apache/kafka" --set image.tag="4.1.1"

# Private registry
--set image.registry="my-registry.com" --set image.repository="kafka" --set image.tag="v1.0"
```

### Kafka UI Image Configuration
```bash
# Kafka UI image settings
--set kafkaUI.image.registry="docker.io"      # Registry URL
--set kafkaUI.image.repository="provectuslabs/kafka-ui"  # Repository
--set kafkaUI.image.tag="latest"               # Tag/version
--set kafkaUI.image.pullPolicy=IfNotPresent   # Pull policy
```

### Cluster & Storage
```bash
--set kafka.replicas=3                          # Number of brokers
--set kafka.storage.size=100Gi                  # Storage per broker
--set kafka.storage.className=longhorn          # Storage class name
```

### Memory & CPU
```bash
--set kafka.jvmHeap.min=1G                      # Min JVM heap
--set kafka.jvmHeap.max=2G                      # Max JVM heap
--set kafka.resources.requests.cpu=1000m        # CPU request
--set kafka.resources.requests.memory=2Gi       # Memory request
--set kafka.resources.limits.cpu=2000m          # CPU limit
--set kafka.resources.limits.memory=4Gi         # Memory limit
```

### Replication (Production: 3+ brokers)
```bash
--set kafka.replication.offsetsTopicReplicationFactor=3
--set kafka.replication.transactionLogReplicationFactor=3
--set kafka.replication.minInSyncReplicas=2
--set kafka.replication.defaultReplicationFactor=3
```

### Performance Tuning
```bash
--set kafka.performance.networkThreads=32       # Network threads
--set kafka.performance.ioThreads=32            # I/O threads
--set kafka.performance.batchSize=32768         # Batch size (bytes)
--set kafka.performance.lingerMs=50             # Wait time for batching
```

### Services
```bash
--set service.type=LoadBalancer                 # Kafka service type
--set kafkaUI.service.type=LoadBalancer         # UI service type
--set kafka.listeners.client.port=9092          # Kafka port
--set kafkaUI.service.port=8080                 # UI port
```

### Kafka UI
```bash
--set kafkaUI.enabled=true                      # Enable UI
--set kafkaUI.replicas=1                        # UI replicas
```

## Common Update Commands

### Scale Up (1 → 3 brokers)
```bash
helm upgrade kafka ./kafka -n kafka-ns \
  --set kafka.replicas=3 \
  --set kafka.replication.offsetsTopicReplicationFactor=3 \
  --set kafka.replication.minInSyncReplicas=2
```

### Increase Storage
```bash
helm upgrade kafka ./kafka -n kafka-ns \
  --set kafka.storage.size=200Gi
```

### Performance Tuning
```bash
helm upgrade kafka ./kafka -n kafka-ns \
  --set kafka.performance.networkThreads=16 \
  --set kafka.performance.ioThreads=16
```

### Increase Memory
```bash
helm upgrade kafka ./kafka -n kafka-ns \
  --set kafka.jvmHeap.min=2G \
  --set kafka.jvmHeap.max=4G \
  --set kafka.resources.requests.memory=4Gi \
  --set kafka.resources.limits.memory=8Gi
```

## Configuration File (values.yaml)

Create `my-values.yaml`:

```yaml
kafka:
  replicas: 3
  
  storage:
    size: 100Gi
    className: longhorn
  
  jvmHeap:
    min: 2G
    max: 4G
  
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  
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

Install with values file:
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace -f my-values.yaml
```

## Helm Commands

```bash
# List releases
helm list -n kafka-ns

# Check status
helm status kafka -n kafka-ns

# Get values
helm get values kafka -n kafka-ns

# Get manifest
helm get manifest kafka -n kafka-ns

# Test (dry-run)
helm install kafka ./kafka --dry-run --debug -n kafka-ns

# Upgrade
helm upgrade kafka ./kafka -n kafka-ns --set kafka.replicas=5

# Rollback
helm rollback kafka -n kafka-ns

# Uninstall
helm uninstall kafka -n kafka-ns
```

## Listener Configuration

Default: PLAINTEXT (no auth/encryption)

For SASL/TLS, edit `values.yaml`:

```yaml
kafka:
  listeners:
    client:
      protocol: "SASL_SSL"  # or SASL_PLAINTEXT, SSL
```

## Parameter Defaults

| Parameter | Default | Notes |
|-----------|---------|-------|
| replicas | 1 | Single broker |
| storage.size | 20Gi | Per broker |
| storage.className | longhorn | Change to your class |
| jvmHeap.min | 512M | Min heap |
| jvmHeap.max | 1G | Max heap |
| resources.cpu.request | 500m | Min CPU |
| resources.memory.request | 1Gi | Min memory |
| offsets.replicationFactor | 1 | Single broker setting |
| replication.minInSyncReplicas | 1 | Single broker setting |

For production (3+ brokers), increase replication factors to 3.

## Storage Classes

Check available classes:
```bash
kubectl get storageclass
```

Common values:
- AWS EKS: `gp3`, `gp2`, `ebs-sc`
- Azure AKS: `default`, `managed-premium`
- GCP GKE: `standard-rwo`, `premium-rwo`
- Local: `longhorn`, `local-path-provisioner`

Update with:
```bash
--set kafka.storage.className=YOUR_CLASS
```

## Troubleshooting

```bash
# Check pod logs
kubectl logs -n kafka-ns kafka-0

# Check events
kubectl get events -n kafka-ns | grep kafka

# Describe pod
kubectl describe pod -n kafka-ns kafka-0

# Test connectivity
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka test bash
nc -zv kafka 9092
```

## Quick Reference Snippets

Access Kafka UI:
```bash
kubectl port-forward -n kafka-ns svc/kafka-ui 8080:8080
```

Access Kafka CLI:
```bash
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka:4.0.0-debian-12 \
  --restart=Never kafka-client bash
```

Create topic:
```bash
kafka-topics.sh --create --bootstrap-server kafka:9092 \
  --topic test --partitions 3 --replication-factor 1
```

List topics:
```bash
kafka-topics.sh --list --bootstrap-server kafka:9092
```

Produce messages:
```bash
kafka-console-producer.sh --broker-list kafka:9092 --topic test
```

Consume messages:
```bash
kafka-console-consumer.sh --bootstrap-server kafka:9092 \
  --topic test --from-beginning
```

## Image Registry Examples

### Using Custom Kafka Image

**Deploy with local/custom image:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="" \
  --set image.repository="kafka" \
  --set image.tag="kraft-kraft-v1" \
  --set image.pullPolicy=IfNotPresent
```

**Deploy with Docker Hub Apache Kafka:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="apache/kafka" \
  --set image.tag="4.1.1"
```

**Deploy with Bitnami Kafka:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="docker.io" \
  --set image.repository="bitnami/kafka" \
  --set image.tag="4.1.1-debian-12"
```

**Deploy with private registry:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="my-private-registry.com" \
  --set image.repository="kafka" \
  --set image.tag="v1.0-custom" \
  --set image.pullPolicy=Always
```

**Deploy with Kafka UI from different registry:**
```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafkaUI.image.registry="my-registry.com" \
  --set kafkaUI.image.repository="kafka-ui" \
  --set kafkaUI.image.tag="v0.7.1"
```

### Image Pull Policies

- **IfNotPresent**: Pull only if image doesn't exist locally (default)
- **Always**: Always pull the latest image from registry
- **Never**: Only use locally available images

Example:
```bash
--set image.pullPolicy=Always              # Always pull latest
--set image.pullPolicy=Never               # Never pull, local only
--set image.pullPolicy=IfNotPresent        # Default: pull if needed
```

### Complete Custom Installation

```bash
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set image.registry="my-registry.io" \
  --set image.repository="kafka/custom" \
  --set image.tag="v2.0" \
  --set image.pullPolicy=Always \
  --set kafkaUI.image.registry="my-registry.io" \
  --set kafkaUI.image.repository="kafka-ui" \
  --set kafkaUI.image.tag="custom" \
  --set kafka.replicas=3 \
  --set kafka.storage.size=100Gi \
  --set kafka.replication.offsetsTopicReplicationFactor=3
```
