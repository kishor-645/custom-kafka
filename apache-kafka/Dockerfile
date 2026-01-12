FROM apache/kafka:4.1.1

# Ensure config and data directories are writable by kafka user (1001)
USER root
RUN mkdir -p /opt/kafka/config /opt/kafka/data /bitnami/kafka/data \
    && chown -R 1001:1001 /opt/kafka /bitnami/kafka || true

# Copy custom entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run as kafka user (1001)
USER 1001

# Use custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
