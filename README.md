# Kafka on Kubernetes - Deployment Options

Two ways to deploy Apache Kafka on Kubernetes:

## 1. Manifest Files (Simple)

**Location:** `apache-kafka/`

Use when you want quick, straightforward deployment.

**Files:**
- `kafka.yaml` - Kafka broker deployment
- `kafka-ui.yaml` - Kafka UI dashboard

**Deploy:**
```bash
cd apache-kafka
kubectl apply -f kafka.yaml
kubectl apply -f kafka-ui.yaml
```

**Documentation:** See `MANIFEST_DEPLOYMENT.md`

---

## 2. Helm Chart (Recommended)

**Location:** `kafka-helm-custom/kafka/`

Use for production, scaling, and version management.

**Deploy:**
```bash
cd kafka-helm-custom
helm install kafka ./kafka -n kafka-ns --create-namespace
```

**Documentation:** See `HELM_DEPLOYMENT.md`

---

## Quick Comparison

| Aspect | Manifest | Helm |
|--------|----------|------|
| Setup | 5 minutes | 5 minutes |
| Flexibility | Limited | Excellent |
| Upgrades | Manual | Automated |
| Rollback | Manual | One command |
| Scaling | Edit YAML | One command |
| Reusability | Low | High |
| Production | Basic | Recommended |

---

## Choose Your Path

### For Development/Quick Test
```bash
cd apache-kafka
kubectl apply -f kafka.yaml
kubectl apply -f kafka-ui.yaml
```

### For Production/Scaling
```bash
cd kafka-helm-custom
helm install kafka ./kafka -n kafka-ns --create-namespace \
  --set kafka.replicas=3 \
  --set kafka.storage.size=100Gi
```

---

## Access Services

```bash
# Kafka UI (both methods)
kubectl port-forward -n kafka-ns svc/kafka-ui 8080:8080
# Visit: http://localhost:8080

# Kafka broker CLI
kubectl run -n kafka-ns -it --rm --image=bitnami/kafka:4.0.0-debian-12 \
  --restart=Never kafka-client bash
```

---

## Common Tasks

### Manifest Method
- Edit `kafka.yaml` and redeploy with `kubectl apply`
- Scale: Edit replicas, then apply

### Helm Method
```bash
# Scale
helm upgrade kafka ./kafka -n kafka-ns --set kafka.replicas=3

# Check status
helm status kafka -n kafka-ns

# Rollback
helm rollback kafka -n kafka-ns

# Uninstall
helm uninstall kafka -n kafka-ns
```

---

## Documentation

- **Manifest Guide:** `apache-kafka/MANIFEST_DEPLOYMENT.md`
- **Helm Guide:** `kafka-helm-custom/HELM_DEPLOYMENT.md`
