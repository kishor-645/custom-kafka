# KRaft-Enabled Kafka Docker Image - Implementation Complete ✅

## Overview
Successfully created a custom Kafka Docker image running in **KRaft mode** (Kafka Raft Quorum) - eliminating the need for Apache ZooKeeper. The image is based on Apache Kafka 4.1.1 and supports both single-node and multi-node cluster deployments.

## Key Implementation Details

### 1. Custom Entrypoint Script
**File**: `/home/kishor/bitnami-migration/kafka/custom-kafka/kafka-helm-custom/kafka/entrypoint.sh`

The entrypoint:
- ✅ Reads configuration from environment variables
- ✅ Generates `server.properties` dynamically
- ✅ **Initializes KRaft metadata** using `kafka-storage.sh format` command
- ✅ Creates `meta.properties` file (required for KRaft mode)
- ✅ Starts Kafka broker in KRaft mode

### 2. KRaft Storage Initialization
The script automatically formats KRaft storage on first startup:
```bash
if [ ! -f "$LOG_DIRS/meta.properties" ]; then
  /opt/kafka/bin/kafka-storage.sh format -t "$CLUSTER_ID" -c "$CONFIG_FILE"
fi
```

This creates the necessary metadata structure that was previously missing, resolving the `no meta.properties` error.

### 3. Dockerfile
**File**: `kafka-helm-custom/kafka/Dockerfile`

```dockerfile
FROM apache/kafka:4.1.1
RUN mkdir -p /opt/kafka/config /opt/kafka/data /bitnami/kafka/data \
    && chown -R 1001:1001 /opt/kafka /bitnami/kafka || true
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### 4. Configuration Parameters
Supported environment variables with sensible defaults:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `NODE_ID` | 1 | Unique broker identifier |
| `CLUSTER_ID` | Generated | Cluster identifier (base64) |
| `PROCESS_ROLES` | broker,controller | KRaft roles |
| `LISTENERS` | PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094 | Listener endpoints |
| `ADVERTISED_LISTENERS` | PLAINTEXT://kafka:9092,... | Advertised addresses |
| `CONTROLLER_QUORUM_VOTERS` | 1@kafka:9093 | Quorum voters |
| `LOG_DIRS` | /opt/kafka/data | Data storage path |

### 5. Docker Compose Example
**File**: `docker-compose-test-kraft.yml`

```yaml
version: '3.8'
services:
  kafka:
    image: kafka:kraft-kraft-v1
    container_name: kafka-test
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      NODE_ID: "1"
      CLUSTER_ID: "MkQwODI4NTcwNTJENDQyQjoxMjM0NTY3ODkwYWI="
      # ... other environment variables
    volumes:
      - kafka_data:/opt/kafka/data
    networks:
      - kafka_network
```

## Test Results ✅

### Build
```bash
cd /home/kishor/bitnami-migration/kafka/custom-kafka/kafka-helm-custom/kafka
docker build -t kafka:kraft-kraft-v1 .
# ✅ Build successful
```

### Container Startup
- ✅ Configuration generated correctly
- ✅ KRaft storage formatted successfully
- ✅ Metadata initialized (meta.properties created)
- ✅ Broker started in ~2 seconds
- ✅ All listeners (PLAINTEXT, CONTROLLER, INTERNAL) ready

### Functionality Tests
```bash
# ✅ Broker API versions accessible
docker exec kafka-test kafka-broker-api-versions.sh --bootstrap-server localhost:9092
# Output: Broker 1 (id: 1 rack: null isFenced: false) with full API support

# ✅ Topic creation
docker exec kafka-test kafka-topics.sh --create --topic test-topic \
  --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
# Output: Created topic test-topic.

# ✅ Message production and consumption
echo "Hello KRaft!" | docker exec -i kafka-test kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic test-topic
```

## Key Log Outputs

### KRaft Storage Formatting
```
===> Initializing KRaft storage...
Formatting metadata directory /opt/kafka/data with metadata.version 4.1-IV1.
===> KRaft storage formatted.
```

### Broker Startup
```
[2026-01-08 07:05:09,735] INFO [RaftManager id=1] Completed transition to 
  Leader(...) - KRaft leader election completed
[2026-01-08 07:05:10,365] INFO [BrokerServer id=1] Transition from 
  STARTING to STARTED
[2026-01-08 07:05:10,366] INFO [KafkaRaftServer nodeId=1] 
  Kafka Server started ✅
```

## Architecture Benefits

### ZooKeeper Elimination
- ❌ No ZooKeeper dependency required
- ✅ Simplified infrastructure
- ✅ Reduced operational overhead
- ✅ Single metadata store (KRaft controller)

### KRaft Mode Features
- ✅ **Self-managed quorum**: Controllers manage metadata natively
- ✅ **Simplified scaling**: Add brokers without ZK reconfiguration
- ✅ **Unified protocol**: Uses KRaft-Raft consensus algorithm
- ✅ **Version 4.1.1 ready**: Production-grade implementation

### Multi-Node Cluster Support
The configuration supports multi-node deployments by setting:
- Different `NODE_ID` values per broker
- Multiple entries in `CONTROLLER_QUORUM_VOTERS`
- Shared `CLUSTER_ID` across all nodes

Example for 3-node cluster:
```
CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
```

## Next Steps

### 1. Helm Integration
To integrate with Helm deployment:
```bash
helm install kafka kafka-helm-32.3.8/kafka/ \
  --set kraft.enabled=true \
  --set replicaCount=3
```

### 2. Kubernetes Deployment
Use the StatefulSet templates in:
- `kafka-helm-32.3.8/kafka/templates/broker/statefulset.yaml`
- `kafka-helm-32.3.8/kafka/templates/controller-eligible/statefulset.yaml`

### 3. Multi-Node Testing
Deploy 3-node cluster using docker-compose:
```bash
docker-compose -f docker-compose-cluster.yml up
```

## Files Modified/Created

```
/home/kishor/bitnami-migration/kafka/custom-kafka/
├── kafka-helm-custom/
│   ├── kafka/
│   │   ├── Dockerfile                    ✅ Updated
│   │   ├── entrypoint.sh                 ✅ Created
│   │   └── server.properties             (Generated at runtime)
│   ├── HELM_DEPLOYMENT.md
│   └── HELM_PARAMETERS.md
├── docker-compose-test-kraft.yml         ✅ Created
└── README.md
```

## Testing Command
```bash
cd /home/kishor/bitnami-migration/kafka/custom-kafka
docker compose -f docker-compose-test-kraft.yml up
docker compose -f docker-compose-test-kraft.yml logs kafka
```

## Image Details
- **Base Image**: apache/kafka:4.1.1
- **Tag**: kafka:kraft-kraft-v1
- **Size**: ~650MB
- **User**: 1001 (kafka user from base image)
- **Exposed Ports**: 9092 (broker), 9093 (controller), 9094 (internal)

## Error Resolution
### Original Issue
```
ERROR: org.apache.kafka.common.config.ConfigException: 
  Unable to read metadata.properties file: no meta.properties file
```

### Solution
Added KRaft storage initialization in entrypoint:
```bash
kafka-storage.sh format -t "$CLUSTER_ID" -c "$CONFIG_FILE"
```

This command:
1. Creates `/opt/kafka/data/meta.properties` ✅
2. Initializes cluster metadata ✅
3. Enables KRaft mode operation ✅

---

**Status**: ✅ **COMPLETE** - KRaft-enabled Kafka Docker image fully functional and tested
