## Lab 1 — Beginner: GitOps Deployment of the IoT Telemetry Stack with Argo CD

**Level:** ⭐ Beginner
**Duration:** 60–90 minutes
**Argo Tools:** Argo CD
**IoT Focus:** Deploy the MQTT broker and telemetry ingestion service onto Kubernetes using GitOps principles.

### Learning Objectives

- Install and access Argo CD
- Connect a Git repository as the source of truth
- Deploy an MQTT broker (Mosquitto) and a telemetry API
- Understand sync policies, health checks, and application state
- Perform a manual rollback via Argo CD

---

### Milestone 1 — Install Argo CD

**Step 1: Create the Argo CD namespace and install**

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Step 2: Wait for all pods to be Running**

```bash
kubectl get pods -n argocd -w
```

**Step 3: Expose the Argo CD API server**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

**Step 4: Retrieve the initial admin password**

```bash
ADMIN_PASS=$(argocd admin initial-password -n argocd)
echo ${ADMIN_PASS}
ADMIN_PASS=$(echo ${ADMIN_PASS} | head -n 1)
```

**Step 5: Login via CLI**

```bash
argocd login localhost:8080 \
  --username admin \
  --password ${ADMIN_PASS} \
  --insecure
```

> ✅ **Checkpoint:** Open `https://localhost:8080` in a browser. The Argo CD UI loads and shows an empty Applications dashboard.

---

### Milestone 2 — Set Up the IoT GitOps Repository

**Step 1: Create the Git repository structure**

```bash
#mkdir iot-gitops && cd iot-gitops
#git init
mkdir -p apps/mqtt-broker apps/telemetry-api
```

**Step 2: Create the MQTT broker manifests**

```yaml
# apps/mqtt-broker/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: iot-platform
```

```yaml
# apps/mqtt-broker/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mosquitto
  namespace: iot-platform
  labels:
    app: mosquitto
    tier: messaging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mosquitto
  template:
    metadata:
      labels:
        app: mosquitto
        tier: messaging
    spec:
      containers:
        - name: mosquitto
          image: eclipse-mosquitto:2.0.18
          ports:
            - containerPort: 1883
              name: mqtt
            - containerPort: 9001
              name: websocket
          volumeMounts:
            - name: mosquitto-config
              mountPath: /mosquitto/config
      volumes:
        - name: mosquitto-config
          configMap:
            name: mosquitto-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mosquitto-config
  namespace: iot-platform
data:
  mosquitto.conf: |
    listener 1883
    allow_anonymous true
    listener 9001
    protocol websockets
---
apiVersion: v1
kind: Service
metadata:
  name: mosquitto
  namespace: iot-platform
spec:
  selector:
    app: mosquitto
  ports:
    - name: mqtt
      port: 1883
      targetPort: 1883
    - name: websocket
      port: 9001
      targetPort: 9001
```

**Step 3: Create the telemetry API manifests**

```yaml
# apps/telemetry-api/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetry-api
  namespace: iot-platform
  labels:
    app: telemetry-api
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: telemetry-api
  template:
    metadata:
      labels:
        app: telemetry-api
        version: "1.0.0"
    spec:
      containers:
        - name: telemetry-api
          image: kennethreitz/httpbin:latest
          ports:
            - containerPort: 80
          env:
            - name: MQTT_BROKER_HOST
              value: "mosquitto.iot-platform.svc.cluster.local"
            - name: MQTT_BROKER_PORT
              value: "1883"
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: telemetry-api
  namespace: iot-platform
spec:
  selector:
    app: telemetry-api
  ports:
    - port: 80
      targetPort: 80
```

**Step 4: Push to GitHub (or any Git remote)**

```bash
git add .
git commit -m "feat: initial IoT platform manifests"
```

---

### Milestone 3 — Create Argo CD Applications

**Step 1: Register your Git repo with Argo CD**

```bash
argocd repo add https://github.com/carlessanagustin/labs-iot.git
#https://github.com/YOUR_ORG/iot-gitops.git \
#  --username YOUR_GITHUB_USER \
#  --password YOUR_GITHUB_TOKEN
```

**Step 2: Create the MQTT Broker Application**

```yaml
# argocd-apps/mqtt-broker-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mqtt-broker
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/iot-gitops.git
    targetRevision: main
    path: apps/mqtt-broker
  destination:
    server: https://kubernetes.default.svc
    namespace: iot-platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f apps/mqtt-broker/app.yaml
```

**Step 3: Create the Telemetry API Application**

```yaml
# argocd-apps/telemetry-api-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: telemetry-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/iot-gitops.git
    targetRevision: main
    path: apps/telemetry-api
  destination:
    server: https://kubernetes.default.svc
    namespace: iot-platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
kubectl apply -f apps/telemetry-api/app.yaml
```

**Step 4: Watch Argo CD sync both applications**

```bash
argocd app list
argocd app get mqtt-broker
argocd app get telemetry-api
```

> ✅ **Checkpoint:** Both applications show `Synced` and `Healthy` in the Argo CD UI and CLI.

---

### Milestone 4 — Test Self-Healing and Rollback

**Step 1: Manually delete a pod to test self-healing**

```bash
kubectl delete pod -l app=mosquitto -n iot-platform
kubectl get pods -n iot-platform -w
```

Argo CD's `selfHeal: true` detects the drift and re-creates the pod within seconds.

**Step 2: Simulate a bad deployment**

In your Git repo, change the MQTT broker image to a non-existent tag:

```yaml
image: eclipse-mosquitto:99.99.99-nonexistent
```

```bash
git add . && git commit -m "bad: broken image tag" && git push
```

**Step 3: Observe the degraded state in the UI, then roll back**

```bash
argocd app history mqtt-broker
argocd app rollback mqtt-broker 1
argocd app sync mqtt-broker telemetry-api
```

> ✅ **Checkpoint:** Argo CD rolls back to the last healthy revision. The MQTT broker returns to `Running`.

---

### Lab 1 — Review Questions

1. What is the difference between `prune: true` and `selfHeal: true` in a sync policy?
2. Why is Git the single source of truth in a GitOps model?
3. How does Argo CD detect that the live state has drifted from the desired state?
