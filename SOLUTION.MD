The reason you are seeing **ClusterRole** and **ClusterRoleBinding** is likely because the template was inherited from a chart (like the original Bitnami or a common boilerplate) that needed to perform cluster-wide tasks, such as discovering Nodes for external IPs or managing Persistent Volumes.

For most standard Kafka setups, **you actually don't need a ClusterRole.** A namespace-scoped **Role** is usually enough.

Here is how to fix the conflict and why you should make these names dynamic.

### 1. The Best Fix: Use Dynamic Naming
You should always prefix your resources with the Helm release name (using the `fullname` helper). This ensures that if you deploy "kafka-prod" and "kafka-test" in the same namespace, or different namespaces, the global names don't clash.

**Update `templates/clusterrole.yaml`:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # CHANGE THIS: Use the fullname helper instead of a static "kafka"
  name: {{ include "kafka.fullname" . }}-role 
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "services"]
    verbs: ["get", "list", "watch"]
```

**Update `templates/clusterrolebinding.yaml`:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "kafka.fullname" . }}-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "kafka.fullname" . }}-role  # Must match the ClusterRole name above
subjects:
  - kind: ServiceAccount
    name: {{ include "kafka.fullname" . }}    # Should match your ServiceAccount name
    namespace: {{ .Release.Namespace }}
```

---

### 2. Better Practice: Use `Role` instead of `ClusterRole`
Since you are deploying Kafka into specific namespaces (`k2`, `k3`), it is more secure and avoids "global" name conflicts to use a **Role** and **RoleBinding** instead of the `Cluster` version.

*   **ClusterRole:** Visible across the whole K8s cluster. Only one "kafka" can exist.
*   **Role:** Exists only inside the namespace. Each namespace can have its own "kafka" Role.

**I recommend changing the templates to namespaced Roles:**

**Update `templates/role.yaml` (Rename from `clusterrole.yaml`):**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role  # Changed from ClusterRole
metadata:
  name: {{ include "kafka.fullname" . }}
  namespace: {{ .Release.Namespace }}
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"] # Removed "nodes" as nodes are global
    verbs: ["get", "list", "watch"]
```

**Update `templates/rolebinding.yaml` (Rename from `clusterrolebinding.yaml`):**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding  # Changed from ClusterRoleBinding
metadata:
  name: {{ include "kafka.fullname" . }}
  namespace: {{ .Release.Namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role       # Changed from ClusterRole
  name: {{ include "kafka.fullname" . }}
subjects:
  - kind: ServiceAccount
    name: {{ include "kafka.fullname" . }}
    namespace: {{ .Release.Namespace }}
```

---

### 3. Do you actually need RBAC at all?
Kafka itself (the broker process) does **not** usually need to talk to the Kubernetes API to function.

You only need these files if:
1.  **Init Containers:** You have an init-container that tries to look up other Pod IPs via the K8s API (rare if using Headless Service).
2.  **Metrics Exporter:** You use a sidecar like `jmx-exporter` that auto-discovers other pods using the API.
3.  **External Load Balancers:** You have a script that needs to "Patch" or "Label" pods based on their assigned LoadBalancer IP.

**If you aren't doing any of the above, you can actually delete `clusterrole.yaml` and `clusterrolebinding.yaml` entirely.** This would be the cleanest way to fix your conflicts.

### Recommendation:
1.  **Switch to `Role` and `RoleBinding`** (Namespaced).
2.  **Prefix every name** with `{{ include "kafka.fullname" . }}`. 
3.  Deploy again—you will no longer have conflicts across namespaces.