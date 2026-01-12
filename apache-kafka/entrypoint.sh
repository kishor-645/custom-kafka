#!/bin/bash
set -e

# Simple Kafka KRaft entrypoint for custom image
# Builds server.properties from environment variables and starts Kafka

echo "===> Starting Kafka with custom entrypoint..."
echo "===> User: $(id)"

# Extract NODE_ID from POD_NAME (kafka-0 -> 1, kafka-1 -> 2, etc.)
# KRaft node IDs must start from 1, not 0
POD_ORDINAL=${POD_NAME##*-}
POD_ORDINAL=${POD_ORDINAL:-0}
NODE_ID=$((POD_ORDINAL + 1))
echo "===> Calculated NODE_ID from POD_NAME ($POD_NAME, ordinal=$POD_ORDINAL): $NODE_ID"

# Now set the variables with proper defaults
CLUSTER_ID=${CLUSTER_ID:-$(head -c 16 /dev/urandom | base64)}
PROCESS_ROLES=${PROCESS_ROLES:-"broker,controller"}
LISTENERS=${LISTENERS:-"PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094"}

# Build ADVERTISED_LISTENERS from template if template is provided
if [ -n "$ADVERTISED_LISTENERS_TEMPLATE" ]; then
  echo "===> Using template for ADVERTISED_LISTENERS"
  # Replace %s with POD_NAME
  ADVERTISED_LISTENERS=$(printf "$ADVERTISED_LISTENERS_TEMPLATE" "$POD_NAME" "$POD_NAME" "$POD_NAME")
  echo "===> Built ADVERTISED_LISTENERS: $ADVERTISED_LISTENERS"
else
  ADVERTISED_LISTENERS=${ADVERTISED_LISTENERS:-"PLAINTEXT://kafka:9092,CONTROLLER://kafka:9093,INTERNAL://kafka:9094"}
fi

# Get CONTROLLER_QUORUM_VOTERS from ConfigMap (via KAFKA_CFG_ prefix from envFrom)
if [ -n "$KAFKA_CFG_CONTROLLER_QUORUM_VOTERS" ]; then
  CONTROLLER_QUORUM_VOTERS="$KAFKA_CFG_CONTROLLER_QUORUM_VOTERS"
  echo "===> Using CONTROLLER_QUORUM_VOTERS from ConfigMap: $CONTROLLER_QUORUM_VOTERS"
else
  echo "===> WARNING: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS not found in ConfigMap!"
  CONTROLLER_QUORUM_VOTERS="0@kafka-0.kafka-headless.default.svc.cluster.local:9093"
  echo "===> Using default: $CONTROLLER_QUORUM_VOTERS"
fi

CONTROLLER_LISTENER_NAMES=${CONTROLLER_LISTENER_NAMES:-"CONTROLLER"}
INTER_BROKER_LISTENER_NAME=${INTER_BROKER_LISTENER_NAME:-"INTERNAL"}
LISTENER_SECURITY_PROTOCOL_MAP=${LISTENER_SECURITY_PROTOCOL_MAP:-"PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,INTERNAL:PLAINTEXT"}
LOG_DIRS=${LOG_DIRS:-"/bitnami/kafka/data"}
LOG_RETENTION_HOURS=${LOG_RETENTION_HOURS:-168}
LOG_SEGMENT_BYTES=${LOG_SEGMENT_BYTES:-1073741824}
NUM_NETWORK_THREADS=${NUM_NETWORK_THREADS:-8}
NUM_IO_THREADS=${NUM_IO_THREADS:-8}
SOCKET_SEND_BUFFER_BYTES=${SOCKET_SEND_BUFFER_BYTES:-102400}
SOCKET_RECEIVE_BUFFER_BYTES=${SOCKET_RECEIVE_BUFFER_BYTES:-102400}

# Create data directory if it doesn't exist
mkdir -p "$LOG_DIRS"

# Build server.properties
CONFIG_FILE="/opt/kafka/config/server.properties"
echo "===> Building $CONFIG_FILE ..."

cat > "$CONFIG_FILE" << EOF
# Auto-generated Kafka configuration
# Built from environment variables

# KRaft Mode Settings
process.roles=$PROCESS_ROLES
node.id=$NODE_ID
cluster.id=$CLUSTER_ID
controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS

# Listeners
listeners=$LISTENERS
advertised.listeners=$ADVERTISED_LISTENERS
controller.listener.names=$CONTROLLER_LISTENER_NAMES
inter.broker.listener.name=$INTER_BROKER_LISTENER_NAME
listener.security.protocol.map=$LISTENER_SECURITY_PROTOCOL_MAP

# Storage
log.dirs=$LOG_DIRS
log.retention.hours=$LOG_RETENTION_HOURS
log.segment.bytes=$LOG_SEGMENT_BYTES

# Performance
num.network.threads=$NUM_NETWORK_THREADS
num.io.threads=$NUM_IO_THREADS
socket.send.buffer.bytes=$SOCKET_SEND_BUFFER_BYTES
socket.receive.buffer.bytes=$SOCKET_RECEIVE_BUFFER_BYTES

# Replication (for single broker, all set to 1)
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
min.insync.replicas=1

# Compression
compression.type=snappy
num.partitions=3
default.replication.factor=1

# Group Coordination
group.initial.rebalance.delay.ms=3000
EOF

echo "===> Configuration built:"
cat "$CONFIG_FILE"

# Initialize KRaft metadata if not already done
if [ ! -f "$LOG_DIRS/meta.properties" ]; then
  echo ""
  echo "===> Initializing KRaft storage..."
  /opt/kafka/bin/kafka-storage.sh format -t "$CLUSTER_ID" -c "$CONFIG_FILE" 2>&1 | head -20
  echo "===> KRaft storage formatted."
else
  echo ""
  echo "===> KRaft storage already initialized."
fi

echo ""
echo "===> Starting Kafka broker..."
exec /opt/kafka/bin/kafka-server-start.sh "$CONFIG_FILE"