#!/bin/bash
set -e

# Kafka KRaft entrypoint
# NODE_ID and CONTROLLER_QUORUM_VOTERS are pre-calculated by the container command

echo "===> Starting Kafka Broker"
echo "===> NODE_ID: ${NODE_ID:-NOT_SET}"
echo "===> CONTROLLER_QUORUM_VOTERS: ${CONTROLLER_QUORUM_VOTERS:-NOT_SET}"
echo "===> User: $(id)"

# Ensure critical variables are set
if [ -z "$NODE_ID" ]; then
  echo "ERROR: NODE_ID not set!"
  exit 1
fi

if [ -z "$CONTROLLER_QUORUM_VOTERS" ]; then
  echo "ERROR: CONTROLLER_QUORUM_VOTERS not set!"
  exit 1
fi

# Set defaults for other variables
CLUSTER_ID=${CLUSTER_ID:-"MkU3OEVBNTcwNTJENDM2Qk"}
PROCESS_ROLES=${PROCESS_ROLES:-"broker,controller"}
LISTENERS=${LISTENERS:-"PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094"}
ADVERTISED_LISTENERS=${ADVERTISED_LISTENERS:-"PLAINTEXT://kafka:9092,CONTROLLER://kafka:9093,INTERNAL://kafka:9094"}
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

# Replication (defaults for single broker, override via env)
offsets.topic.replication.factor=${OFFSETS_TOPIC_REPLICATION_FACTOR:-1}
transaction.state.log.replication.factor=${TRANSACTION_STATE_LOG_REPLICATION_FACTOR:-1}
transaction.state.log.min.isr=${TRANSACTION_STATE_LOG_MIN_ISR:-1}
min.insync.replicas=${MIN_INSYNC_REPLICAS:-1}

# Compression
compression.type=snappy
num.partitions=3
default.replication.factor=${DEFAULT_REPLICATION_FACTOR:-1}

# Group Coordination
group.initial.rebalance.delay.ms=3000
EOF

echo "===> Configuration built:"
cat "$CONFIG_FILE"

# Initialize KRaft metadata if not already done
if [ ! -f "$LOG_DIRS/meta.properties" ]; then
  echo ""
  echo "===> Initializing KRaft storage..."
  /opt/kafka/bin/kafka-storage.sh format -t "$CLUSTER_ID" -c "$CONFIG_FILE" 2>&1 | head -30
  echo "===> KRaft storage formatted."
else
  echo ""
  echo "===> KRaft storage already initialized."
fi

echo ""
echo "===> Starting Kafka broker..."
exec /opt/kafka/bin/kafka-server-start.sh "$CONFIG_FILE"


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