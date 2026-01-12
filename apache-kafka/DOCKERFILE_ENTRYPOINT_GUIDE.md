# Docker Build & Entrypoint Flow - Simple Guide

## What is This?
This document explains how the **Kafka Docker container** is built and started. It shows:
- **How the Dockerfile builds the image**
- **How parameters flow into the container**
- **How the entrypoint script configures Kafka**
- **What happens when the container starts**

---

## 1️⃣ THE DOCKERFILE - Building the Image

### File: `Dockerfile`

```dockerfile
FROM apache/kafka:4.1.1
```
**What it does**: Starts with an existing Kafka image (version 4.1.1) as the base.

---

### Step 1: Set User to Root (for setup)
```dockerfile
USER root
```
**What it does**: Temporarily switch to `root` user to create directories and set permissions.

---

### Step 2: Create Directories
```dockerfile
RUN mkdir -p /opt/kafka/config /opt/kafka/data /bitnami/kafka/data \
    && chown -R 1001:1001 /opt/kafka /bitnami/kafka || true
```
**What it does**:
- Creates three important folders inside the container:
  - `/opt/kafka/config` → Where `server.properties` config file will be stored
  - `/opt/kafka/data` → Where Kafka stores message logs
  - `/bitnami/kafka/data` → Backup data directory

- `chown -R 1001:1001` → Makes sure user `1001` (kafka user) owns these folders
- `|| true` → Don't fail if this command has issues

---

### Step 3: Copy the Entrypoint Script
```dockerfile
COPY entrypoint.sh /entrypoint.sh
```
**What it does**: Copies your `entrypoint.sh` script from your computer into the container root folder.

---

### Step 4: Make Script Executable
```dockerfile
RUN chmod +x /entrypoint.sh
```
**What it does**: Gives permission to execute the entrypoint.sh file.

---

### Step 5: Switch to Kafka User
```dockerfile
USER 1001
```
**What it does**: Switch to user `1001` (kafka user) - Kafka will run as this user, not root.

---

### Step 6: Set the Entry Point
```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
```
**What it does**: When container starts, automatically run `/entrypoint.sh` script.

---

## 2️⃣ HOW PARAMETERS FLOW INTO THE CONTAINER

### Docker Compose Example

```yaml
services:
  kafka:
    image: kafka:kraft-kraft-v1
    environment:
      NODE_ID: "1"
      CLUSTER_ID: "MkQwODI4NTcwNTJENDQyQjoxMjM0NTY3ODkwYWI="
      PROCESS_ROLES: "broker,controller"
      LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
```

### How It Works

1. **Docker-compose reads the `environment:` section**
2. **Sets environment variables inside the container** (like `NODE_ID=1`)
3. **Container starts → executes `/entrypoint.sh`**
4. **The script reads these variables** using `$NODE_ID`, `$CLUSTER_ID`, etc.

---

## 3️⃣ THE ENTRYPOINT SCRIPT - Main Logic

### File: `entrypoint.sh`

#### Phase 1: Read Parameters or Set Defaults

```bash
NODE_ID=${NODE_ID:-1}
CLUSTER_ID=${CLUSTER_ID:-$(head -c 16 /dev/urandom | base64)}
PROCESS_ROLES=${PROCESS_ROLES:-"broker,controller"}
LISTENERS=${LISTENERS:-"PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094"}
```

**What this means**: `${VARIABLE:-default_value}`
- If `VARIABLE` is set (from docker-compose), use it
- If `VARIABLE` is NOT set, use the default value

**Examples**:
```
NODE_ID=1                    (from docker-compose OR default to 1)
CLUSTER_ID=abc123...         (from docker-compose OR randomly generate)
PROCESS_ROLES=broker         (from docker-compose OR default to "broker,controller")
```

| Parameter | What It Does | Default Value |
|-----------|-------------|----------------|
| `NODE_ID` | Unique ID for this Kafka broker | `1` |
| `CLUSTER_ID` | ID for entire Kafka cluster | Random base64 string |
| `PROCESS_ROLES` | What roles this broker plays | `broker,controller` |
| `LISTENERS` | Which ports to listen on | `PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094` |
| `LOG_DIRS` | Where to store data | `/opt/kafka/data` |
| `LOG_RETENTION_HOURS` | How long to keep messages | `168` (1 week) |

---

#### Phase 2: Create the Config File

```bash
CONFIG_FILE="/opt/kafka/config/server.properties"
cat > "$CONFIG_FILE" << EOF
# Auto-generated Kafka configuration
process.roles=$PROCESS_ROLES
node.id=$NODE_ID
cluster.id=$CLUSTER_ID
...
EOF
```

**What it does**:
1. Creates a file at `/opt/kafka/config/server.properties`
2. Fills it with all the parameters you provided
3. The `$VARIABLE` parts get replaced with actual values

**Example**: If `NODE_ID=1` and `CLUSTER_ID=abc123`:
```properties
process.roles=broker,controller
node.id=1
cluster.id=abc123
```

---

#### Phase 3: Initialize KRaft Metadata (First Time Only)

```bash
if [ ! -f "$LOG_DIRS/meta.properties" ]; then
  echo "===> Initializing KRaft storage..."
  /opt/kafka/bin/kafka-storage.sh format -t "$CLUSTER_ID" -c "$CONFIG_FILE"
  echo "===> KRaft storage formatted."
else
  echo "===> KRaft storage already initialized."
fi
```

**What it does**:
- **Checks**: Does file `/opt/kafka/data/meta.properties` exist?
  - **YES** → Skip (already initialized)
  - **NO** → Initialize for the first time

- **Initialization** creates metadata needed for KRaft (Kafka Raft Quorum)
  - This is like setting up the cluster for the first time
  - Only happens once per container

---

#### Phase 4: Start Kafka

```bash
echo "===> Starting Kafka broker..."
exec /opt/kafka/bin/kafka-server-start.sh "$CONFIG_FILE"
```

**What it does**:
- Starts the actual Kafka broker using the config file
- `exec` means this process becomes the main container process
- Container will stop when Kafka stops

---

## 4️⃣ COMPLETE FLOW - Step by Step

### When You Run Docker Compose

```bash
docker compose -f docker-compose-test-kraft.yml up
```

### What Happens:

```
1. Docker reads docker-compose.yml
   ↓
2. Docker builds image (if needed) using Dockerfile
   ↓
3. Docker creates container from image
   ↓
4. Docker sets environment variables (NODE_ID=1, etc.)
   ↓
5. Container starts → executes /entrypoint.sh
   ↓
6. Script reads environment variables
   ↓
7. Script sets defaults for variables NOT provided
   ↓
8. Script creates /opt/kafka/config/server.properties
   ↓
9. Script initializes KRaft metadata (first time only)
   ↓
10. Script starts Kafka broker
   ↓
11. Kafka runs and serves requests on ports 9092, 9093, 9094
```

---

## 5️⃣ REAL EXAMPLE - Single Node

### Docker Compose File
```yaml
version: '3.8'
services:
  kafka:
    image: kafka:kraft-kraft-v1
    ports:
      - "9092:9092"
    environment:
      NODE_ID: "1"
      CLUSTER_ID: "MkQwODI4NTcwNTJENDQyQjoxMjM0NTY3ODkwYWI="
      PROCESS_ROLES: "broker,controller"
      LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094"
      ADVERTISED_LISTENERS: "PLAINTEXT://localhost:9092,CONTROLLER://kafka:9093,INTERNAL://kafka:9094"
    volumes:
      - kafka_data:/opt/kafka/data
```

### What Gets Created

**Inside Container**:
```
/opt/kafka/config/server.properties (generated)
  ├─ process.roles=broker,controller
  ├─ node.id=1
  ├─ cluster.id=MkQwODI4NTcwNTJENDQyQjoxMjM0NTY3ODkwYWI=
  ├─ listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,INTERNAL://0.0.0.0:9094
  └─ ... (all other settings)

/opt/kafka/data (created at startup)
  ├─ meta.properties (created by kafka-storage.sh)
  ├─ __cluster_metadata-0/ (metadata logs)
  └─ ... (message logs created as topics are created)
```

---

## 6️⃣ PARAMETER REFERENCE TABLE

### Basic KRaft Parameters

| Parameter | Sets Kafka Property | Purpose | Example |
|-----------|---------------------|---------|---------|
| `NODE_ID` | `node.id` | Unique broker identifier | `1`, `2`, `3` |
| `CLUSTER_ID` | `cluster.id` | Cluster identifier | Base64 string |
| `PROCESS_ROLES` | `process.roles` | Broker roles | `broker,controller` or just `broker` |

### Network Parameters

| Parameter | Sets Kafka Property | Purpose | Example |
|-----------|---------------------|---------|---------|
| `LISTENERS` | `listeners` | Ports the broker listens on | `PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093` |
| `ADVERTISED_LISTENERS` | `advertised.listeners` | Ports clients connect to | `PLAINTEXT://kafka:9092,CONTROLLER://kafka:9093` |
| `CONTROLLER_QUORUM_VOTERS` | `controller.quorum.voters` | Which brokers are in the quorum | `1@kafka-1:9093,2@kafka-2:9093` |

### Storage Parameters

| Parameter | Sets Kafka Property | Purpose | Example |
|-----------|---------------------|---------|---------|
| `LOG_DIRS` | `log.dirs` | Where to store message logs | `/opt/kafka/data` |
| `LOG_RETENTION_HOURS` | `log.retention.hours` | How long to keep messages | `168` (1 week) |
| `LOG_SEGMENT_BYTES` | `log.segment.bytes` | Max size of one log segment | `1073741824` (1GB) |

### Performance Parameters

| Parameter | Sets Kafka Property | Purpose | Default |
|-----------|---------------------|---------|---------|
| `NUM_NETWORK_THREADS` | `num.network.threads` | Network threads | `8` |
| `NUM_IO_THREADS` | `num.io.threads` | IO threads | `8` |
| `SOCKET_SEND_BUFFER_BYTES` | `socket.send.buffer.bytes` | Send buffer size | `102400` |
| `SOCKET_RECEIVE_BUFFER_BYTES` | `socket.receive.buffer.bytes` | Receive buffer size | `102400` |

---

## 7️⃣ QUICK LOOKUP - How to Change Things

### Change broker port:
```yaml
environment:
  LISTENERS: "PLAINTEXT://0.0.0.0:9999"  # Changed from 9092 to 9999
```

### Change data retention to 30 days:
```yaml
environment:
  LOG_RETENTION_HOURS: "720"  # 30 days × 24 hours
```

### Change broker ID for cluster:
```yaml
environment:
  NODE_ID: "2"  # Will be broker #2 in cluster
```

### Change cluster ID (must be same for all brokers):
```yaml
environment:
  CLUSTER_ID: "MyClusterID123456789012="
```

---

## 8️⃣ TROUBLESHOOTING

### Problem: Container won't start
**Check**: 
1. Do you have the `entrypoint.sh` file?
2. Is `entrypoint.sh` executable? (`chmod +x entrypoint.sh`)
3. Do you have write permission to `/opt/kafka/data`?

### Problem: Port already in use
**Check**: Change `LISTENERS` port:
```yaml
environment:
  LISTENERS: "PLAINTEXT://0.0.0.0:9095"  # Use different port
```

### Problem: Can't connect from outside Docker
**Check**: Set correct `ADVERTISED_LISTENERS`:
```yaml
environment:
  ADVERTISED_LISTENERS: "PLAINTEXT://your-hostname:9092"  # Use actual hostname/IP
```

---

## 9️⃣ SUMMARY

```
┌─────────────────────────────────────────────────────────────┐
│              DOCKER BUILD & ENTRYPOINT FLOW                 │
└─────────────────────────────────────────────────────────────┘

DOCKERFILE (builds image):
  1. Start with apache/kafka:4.1.1
  2. Create /opt/kafka/config and /opt/kafka/data directories
  3. Copy entrypoint.sh into container
  4. Make entrypoint.sh executable
  5. Set entrypoint to /entrypoint.sh

DOCKER COMPOSE (runs container):
  1. Set environment variables (NODE_ID, CLUSTER_ID, etc.)
  2. Start container → executes /entrypoint.sh

ENTRYPOINT.SH (configures & starts Kafka):
  1. Read environment variables (or use defaults)
  2. Generate /opt/kafka/config/server.properties
  3. Initialize KRaft metadata (first time only)
  4. Start Kafka broker

RESULT:
  ✅ Kafka runs with your custom configuration
  ✅ Can connect on PLAINTEXT://localhost:9092
  ✅ Can connect on CONTROLLER://localhost:9093
  ✅ Can connect on INTERNAL://localhost:9094
```

---

## 🔟 ENVIRONMENT VARIABLES CHEAT SHEET

Copy & paste to use:

```yaml
# Basic setup (single node)
environment:
  NODE_ID: "1"
  CLUSTER_ID: "MkQwODI4NTcwNTJENDQyQjoxMjM0NTY3ODkwYWI="
  PROCESS_ROLES: "broker,controller"
  
# Multi-node cluster (3 nodes)
environment:
  CONTROLLER_QUORUM_VOTERS: "1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093"
  
# Change retention
environment:
  LOG_RETENTION_HOURS: "720"  # 30 days
  
# Change ports
environment:
  LISTENERS: "PLAINTEXT://0.0.0.0:9999,CONTROLLER://0.0.0.0:9998"
  ADVERTISED_LISTENERS: "PLAINTEXT://myhost:9999,CONTROLLER://kafka:9998"
```

---

**That's it!** You now understand the complete flow from Dockerfile → Docker Compose → Entrypoint → Kafka Running! 🚀
