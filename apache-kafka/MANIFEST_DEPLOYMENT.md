# Kafka Manifest Deployment Guide

Quick deployment using manifest files without Helm.

## Files

- `kafka.yaml` - Kafka broker deployment (StatefulSet, services, RBAC)
- `kafka-ui.yaml` - Kafka UI deployment (web dashboard)

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured
- Storage provisioner available
- `longhorn` or your storage class available

## Quick Deploy

### 1. Update Storage Class

```bash
# Check available storage classes
kubectl get storageclass

# Update in both files if needed
sed -i 's/longhorn/YOUR_STORAGE_CLASS/g' kafka.yaml kafka-ui.yaml
```

### 2. Deploy Kafka

```bash
# Apply Kafka deployment
kubectl apply -f kafka.yaml

# Check status
kubectl get pods -n kafka-ns -w
kubectl get pvc -n kafka-ns
kubectl get svc -n kafka-ns
```

### 3. Deploy Kafka UI

```bash
# Apply UI deployment
kubectl apply -f kafka-ui.yaml

# Check status
kubectl get deployment -n kafka-ns
kubectl get svc -n kafka-ns kafka-ui-external
```

## Access Kafka

### Kafka UI (Web Dashboard)

```bash
# Get LoadBalancer IP
kubectl get svc -n kafka-ns kafka-ui-external

# Port forward (alternative)
kubectl port-forward -n kafka-ns svc/kafka-ui 8080:8080
# Visit: http://localhost:8080
```

### Kafka Broker (CLI)

```bash
# Run test client
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka:4.0.0-debian-12 \
  --restart=Never kafka-client bash

# Inside pod:
kafka-topics.sh --list --bootstrap-server kafka:9092
kafka-console-producer.sh --broker-list kafka:9092 --topic test
kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic test --from-beginning
```

## Configuration

Edit ConfigMap in `kafka.yaml` for:

| Setting | Location | Default | Notes |
|---------|----------|---------|-------|
| Storage size | `kafka.yaml` PVC | 20Gi | Per broker |
| Storage class | `kafka.yaml` PVC | longhorn | Change to your class |
| Brokers | `kafka.yaml` replicas | 1 | Scale to 3+ for prod |
| Memory | `kafka.yaml` ConfigMap | 1Gi | Adjust KAFKA_HEAP_OPTS |
| CPU | `kafka.yaml` containers | 500m-2000m | Requests and limits |
| Retention | `kafka.yaml` ConfigMap | 7 days | KAFKA_CFG_LOG_RETENTION_HOURS |

## Scaling

### Add Brokers

```bash
# Edit kafka.yaml: change replicas: 1 to replicas: 3
# Edit kafka.yaml ConfigMap: update CONTROLLER_QUORUM_VOTERS

# Then redeploy
kubectl apply -f kafka.yaml
kubectl scale statefulset kafka -n kafka-ns --replicas=3
```

## Common Tasks

### Create Topic

```bash
kubectl exec -n kafka-ns kafka-0 -- \
  kafka-topics.sh --create \
    --bootstrap-server localhost:9092 \
    --topic my-topic \
    --partitions 3 \
    --replication-factor 1
```

### List Topics

```bash
kubectl exec -n kafka-ns kafka-0 -- \
  kafka-topics.sh --list --bootstrap-server localhost:9092
```

### Check Broker Status

```bash
# Get logs
kubectl logs -n kafka-ns kafka-0 -f

# Check pod status
kubectl describe pod -n kafka-ns kafka-0

# Test connectivity
kubectl exec -n kafka-ns kafka-0 -- \
  kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### Delete/Cleanup

```bash
# Delete all resources
kubectl delete -f kafka-ui.yaml
kubectl delete -f kafka.yaml

# Delete namespace (removes everything)
kubectl delete namespace kafka-ns
```

## Troubleshooting

### Broker won't start

```bash
# Check logs
kubectl logs -n kafka-ns kafka-0

# Check PVC
kubectl describe pvc -n kafka-ns kafka-storage-kafka-0

# Check storage class
kubectl get storageclass

# Check node resources
kubectl top nodes
```

### Can't connect

```bash
# Test connectivity
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka test bash
nc -zv kafka 9092

# Check service
kubectl get svc -n kafka-ns kafka
kubectl describe svc -n kafka-ns kafka
```

### Storage issues

```bash
# Check PVC status
kubectl get pvc -n kafka-ns

# Check actual usage
kubectl exec -n kafka-ns kafka-0 -- du -sh /bitnami/kafka/data

# Resize PVC (if supported)
kubectl patch pvc kafka-storage-kafka-0 -n kafka-ns \
  -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

## Advanced Configuration

### High Throughput Setup

Edit ConfigMap in kafka.yaml:

```yaml
KAFKA_CFG_NUM_NETWORK_THREADS: "32"
KAFKA_CFG_NUM_IO_THREADS: "32"
KAFKA_CFG_SOCKET_SEND_BUFFER_BYTES: "524288"
KAFKA_CFG_LINGER_MS: "50"
```

Update resources in StatefulSet:

```yaml
resources:
  requests:
    cpu: 4000m
    memory: 8Gi
  limits:
    cpu: 8000m
    memory: 16Gi
```

### 3-Node Production Setup

Edit kafka.yaml:

```yaml
replicas: 3

# In ConfigMap:
KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: "1@kafka-0:9093,2@kafka-1:9093,3@kafka-2:9093"
KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR: "3"
KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: "3"
KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR: "2"
KAFKA_CFG_MIN_INSYNC_REPLICAS: "2"
```

### Enable SASL Authentication

Update ConfigMap listeners:

```yaml
KAFKA_CFG_LISTENERS: "SASL_PLAINTEXT://0.0.0.0:9092,..."
KAFKA_CFG_SASL_ENABLED_MECHANISMS: "PLAIN"
```

### Enable TLS Encryption

Update ConfigMap listeners:

```yaml
KAFKA_CFG_LISTENERS: "SASL_SSL://0.0.0.0:9092,..."
KAFKA_CFG_SSL_ENABLED_PROTOCOLS: "TLSv1.2,TLSv1.3"
```

## Reference

- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Bitnami Kafka Container](https://github.com/bitnami/containers/tree/main/bitnami/kafka)
- [Kubernetes Docs](https://kubernetes.io/docs/)
