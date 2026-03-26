## Lab 3 — Intermediate: Safe IoT Service Rollouts with Argo Rollouts

**Level:** ⭐⭐⭐ Intermediate
**Duration:** 90–120 minutes
**Argo Tools:** Argo Rollouts
**IoT Focus:** Use canary deployments to safely release new versions of the IoT telemetry ingestion service, with automatic Prometheus-backed analysis before each promotion step.

### Learning Objectives

- Install Argo Rollouts and the kubectl plugin
- Replace a standard Deployment with a Rollout manifest
- Configure a canary strategy with progressive traffic splitting
- Add an AnalysisTemplate that queries Prometheus metrics
- Promote, pause, and abort a rollout
- Implement a blue-green strategy for the firmware update service

---

### Milestone 1 — Install Argo Rollouts

**Step 1: Install the controller**

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Step 2: Install the kubectl plugin**

* Mac installation

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
chmod +x kubectl-argo-rollouts-darwin-amd64
mv kubectl-argo-rollouts-darwin-amd64 ls $HOME/.local/bin/kubectl-argo-rollouts
# test
kubectl argo rollouts version
```

**Step 3: Install Prometheus for AnalysisTemplates**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

```bash
# Get Grafana 'admin' user password by running:
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
# OR
kubectl --namespace monitoring get secret -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo

# Access Grafana local instance:
kubectl --namespace monitoring port-forward $(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname) 3000
```

> ✅ **Checkpoint:** `kubectl get pods -n argo-rollouts` shows the controller running. `kubectl argo rollouts version` returns the installed version.

---

### Milestone 2 — Deploy the Telemetry Ingestion Service as a Rollout

**Step 1: Create stable and canary services**

```yaml
# rollouts/telemetry-ingestion-canary-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: telemetry-ingestion-stable
  namespace: iot-platform
spec:
  selector:
    app: telemetry-ingestion
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: telemetry-ingestion-canary
  namespace: iot-platform
spec:
  selector:
    app: telemetry-ingestion
  ports:
    - port: 80
      targetPort: 80
```

**Step 2: Create the Rollout with a canary strategy**

```yaml
# rollouts/telemetry-ingestion-canary.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: telemetry-ingestion
  namespace: iot-platform
  labels:
    app: telemetry-ingestion
    component: iot-core
spec:
  replicas: 5
  selector:
    matchLabels:
      app: telemetry-ingestion
  template:
    metadata:
      labels:
        app: telemetry-ingestion
        version: "v1.0.0"
    spec:
      containers:
        - name: telemetry-ingestion
          image: kennethreitz/httpbin:latest
          ports:
            - containerPort: 80
          env:
            - name: APP_VERSION
              value: "1.0.0"
            - name: MQTT_BROKER
              value: "mosquitto.iot-platform.svc.cluster.local:1883"
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
          readinessProbe:
            httpGet:
              path: /status/200
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5

  strategy:
    canary:
      stableService: telemetry-ingestion-stable
      canaryService: telemetry-ingestion-canary
      steps:
        - setWeight: 10           # 10% of traffic to canary
        - pause: {duration: 2m}
        - analysis:
            templates:
              - templateName: telemetry-error-rate
            args:
              - name: service-name
                value: telemetry-ingestion
        - setWeight: 30
        - pause: {duration: 2m}
        - setWeight: 60
        - pause: {duration: 1m}
        - setWeight: 100
```

```bash
kubectl apply -f rollouts/telemetry-ingestion-canary-services.yaml
kubectl apply -f rollouts/telemetry-ingestion-canary.yaml
```

---

### Milestone 3 — Create an AnalysisTemplate

The AnalysisTemplate queries Prometheus to ensure the canary's HTTP error rate stays below 5% before each promotion step.

```yaml
# rollouts/analysis-error-rate-prometheus.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: telemetry-error-rate
  namespace: iot-platform
spec:
  args:
    - name: service-name
  metrics:
    - name: http-error-rate
      interval: 30s
      count: 3
      successCondition: result[0] < 0.05
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
          query: |
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              status=~"5.."
            }[2m]))
            /
            sum(rate(http_requests_total{
              service="{{args.service-name}}"
            }[2m]))

    - name: mqtt-message-lag
      interval: 60s
      count: 2
      successCondition: result[0] < 1000
      provider:
        prometheus:
          address: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
          query: |
            mqtt_broker_messages_queued{
              service="{{args.service-name}}"
            }
```

```bash
kubectl apply -f rollouts/analysis-error-rate-prometheus.yaml
kubectl get analysistemplates -n iot-platform
```

> ✅ **Checkpoint:** `kubectl get analysistemplates -n iot-platform` shows `telemetry-error-rate`.

---

### Milestone 4 — Trigger and Observe a Canary Rollout

**Step 1: Trigger a new version by updating the image**

```shell
kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=nginx:1.25 -n iot-platform
# kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=kennethreitz/httpbin:latest -n iot-platform
# kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=kennethreitz/httpbin:test -n iot-platform
```

**Step 2: Watch the rollout progress**

```shell
kubectl argo rollouts get rollout telemetry-ingestion --watch -n iot-platform 
```

**Step 3: Open the Argo Rollouts dashboard**

```bash
kubectl argo rollouts dashboard &
# Opens at http://localhost:3100/rollouts/iot-platform
```

**Step 4: Manually promote past a pause step**

```bash
kubectl argo rollouts promote telemetry-ingestion -n iot-platform
```

**Step 5: Test aborting a bad rollout**

```bash
kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=nginx:broken-tag-999 -n iot-platform

# Monitor AnalysisRun failing, then abort
kubectl argo rollouts abort telemetry-ingestion -n iot-platform
kubectl argo rollouts undo telemetry-ingestion -n iot-platform
```

> ✅ **Checkpoint:** The rollout automatically rolls back to the stable version when the AnalysisRun fails. The dashboard shows a red analysis result and the stable pods re-scale.

---

## Milestone 5 — Blue-Green Deployment for the Telemetry Ingestion Service

**Prerequisites:** Milestones 1–4 completed. The following objects must exist in the cluster:

- Namespace `iot-platform`
- Rollout `telemetry-ingestion` (canary strategy, from Milestone 2)
- Services `telemetry-ingestion-stable` and `telemetry-ingestion-canary` (from Milestone 2)
- AnalysisTemplate `telemetry-error-rate` (from Milestone 3)

In Milestones 2–4 you used a canary strategy to progressively shift traffic to a new version. In this milestone you will convert the **same telemetry-ingestion service** to a blue-green strategy — replacing the entire environment atomically instead of gradually — and observe how that changes the deployment experience.

---

### Step 1: Remove the existing canary Rollout

Argo Rollouts does not allow changing the strategy on a live Rollout in place. Delete it first so you can redeploy with a blue-green strategy. The `telemetry-ingestion-stable` and `telemetry-ingestion-canary` Services and the `telemetry-error-rate` AnalysisTemplate are kept — they are reused below.

```bash
kubectl delete rollout telemetry-ingestion -n iot-platform
# Confirm pods are gone
kubectl get pods -n iot-platform -l app=telemetry-ingestion
```

> ✅ **Checkpoint:** No `telemetry-ingestion` pods remain. Services and AnalysisTemplate are still present.

```bash
kubectl get svc -n iot-platform | grep telemetry
kubectl get analysistemplates -n iot-platform
```

---

### Step 2: Create active and preview Services

Blue-green needs two services: one receiving live traffic (active) and one pointing at the new version for pre-promotion testing (preview). Create them alongside the two canary services that already exist.

```yaml
# rollouts/telemetry-ingestion-bluegreen-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: telemetry-ingestion-active
  namespace: iot-platform
spec:
  selector:
    app: telemetry-ingestion
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: telemetry-ingestion-preview
  namespace: iot-platform
spec:
  selector:
    app: telemetry-ingestion
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f rollouts/telemetry-ingestion-bluegreen-services.yaml
kubectl get svc -n iot-platform | grep telemetry
```

> ✅ **Checkpoint:** Four telemetry services exist: `stable`, `canary` (from Milestone 2, now unused), `active`, and `preview`.

---

### Step 3: Deploy the blue-green Rollout

The Rollout below reuses the same image, resource requests, and readiness probe from Milestone 2. The `prePromotionAnalysis` block reuses the `telemetry-error-rate` AnalysisTemplate from Milestone 3 — because `kennethreitz/httpbin` exposes HTTP endpoints, the error-rate query is meaningful against this service.

```yaml
# rollouts/telemetry-ingestion-bluegreen.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: telemetry-ingestion
  namespace: iot-platform
  labels:
    app: telemetry-ingestion
    component: iot-core
spec:
  replicas: 5
  selector:
    matchLabels:
      app: telemetry-ingestion
  template:
    metadata:
      labels:
        app: telemetry-ingestion
    spec:
      containers:
        - name: telemetry-ingestion
          image: kennethreitz/httpbin:latest
          ports:
            - containerPort: 80
          env:
            - name: APP_VERSION
              value: "1.0.0"
            - name: MQTT_BROKER
              value: "mosquitto.iot-platform.svc.cluster.local:1883"
            - name: PORT
              value: "80"
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
          readinessProbe:
            httpGet:
              path: /status/200
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
  strategy:
    blueGreen:
      activeService: telemetry-ingestion-active
      previewService: telemetry-ingestion-preview
      autoPromotionEnabled: false       # require manual approval
      scaleDownDelaySeconds: 30
      previewReplicaCount: 2
      prePromotionAnalysis:
        templates:
          - templateName: telemetry-error-rate   # reused from Milestone 3
        args:
          - name: service-name
            value: telemetry-ingestion
```

```bash
kubectl apply -f rollouts/telemetry-ingestion-bluegreen.yaml
# and watch the rollout in a separate terminal...
kubectl argo rollouts get rollout telemetry-ingestion -n iot-platform -w
```

> ✅ **Checkpoint:** 5 pods running, `telemetry-ingestion-active` endpoints populated, status shows `Healthy`.

---

### Step 4: Trigger a blue-green rollout by updating the image

Update the image to produce a new (green) revision. Argo Rollouts will bring up `previewReplicaCount: 2` green pods behind `telemetry-ingestion-preview` while all 5 blue pods continue serving live traffic through `telemetry-ingestion-active`.

```bash
kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=jaredwray/mockhttp:latest -n iot-platform
# kubectl argo rollouts set image telemetry-ingestion telemetry-ingestion=kennethreitz/httpbin:latest -n iot-platform
```

> This uses the same image tag to force a new ReplicaSet. In a real scenario this would be a new version tag.
> ✅ **Checkpoint:** Two ReplicaSets running simultaneously. The rollout status shows `Paused` — waiting for manual promotion.

---

### Step 5: Inspect the preview (green) environment

Before promoting, verify the new revision is healthy by querying the preview service directly.

```bash
# Confirm preview endpoints point to the new (green) pods
kubectl get endpoints telemetry-ingestion-preview -n iot-platform

# Port-forwarding commands...
kubectl -n iot-platform port-forward svc/telemetry-ingestion-active 8081:80
kubectl -n iot-platform port-forward svc/telemetry-ingestion-preview 8082:80

# See blue endpoint
curl -I http://127.0.0.1:8082/status/200

# Compare with green endpoint
curl -I http://127.0.0.1:8081/status/200
```

Open the Argo Rollouts dashboard to see both environments:

```bash
kubectl argo rollouts dashboard &
# Opens at http://localhost:3100/rollouts/iot-platform
```

> ✅ **Checkpoint:** Both services return HTTP 200. The dashboard shows two revision stacks with their pod counts.

---

### Step 6: Promote green to active

The `prePromotionAnalysis` run will execute first (querying `telemetry-error-rate` against the preview pods). Once it passes, Argo Rollouts switches `telemetry-ingestion-active` endpoints to the green pods and scales down the blue pods after 30 seconds.

```bash
kubectl argo rollouts promote telemetry-ingestion -n iot-platform
```

Watch the AnalysisRun, then the traffic switch:

```bash
kubectl get analysisruns -n iot-platform --watch
kubectl argo rollouts get rollout telemetry-ingestion --watch -n iot-platform
```

Confirm live traffic now hits the green pods:

```bash
kubectl get endpoints telemetry-ingestion-active -n iot-platform
kubectl argo rollouts get rollout telemetry-ingestion -n iot-platform
```

> ✅ **Checkpoint:** Single ReplicaSet running with 5 replicas. `telemetry-ingestion-active` endpoints updated. Old blue pods terminated after the scale-down delay.

---

# TODO carles

### Step 7: Simulate a bad release and observe automatic rollback

Update to a non-existent image tag. The 2 preview pods will fail to pull the image. The `prePromotionAnalysis` readiness check will fail (error rate cannot be measured against a crashing pod), aborting the rollout automatically before live traffic is ever affected.

```bash
kubectl argo rollouts set image telemetry-ingestion \
  telemetry-ingestion=kennethreitz/httpbin:broken-tag-999 -n iot-platform

# Watch the AnalysisRun report failure
kubectl get analysisruns -n iot-platform --watch

# Rollout aborts automatically — stable active pods are untouched
kubectl argo rollouts get rollout telemetry-ingestion -n iot-platform
```

If needed, manually abort and restore:

```bash
kubectl argo rollouts abort telemetry-ingestion -n iot-platform
kubectl argo rollouts undo telemetry-ingestion -n iot-platform
```

> ✅ **Checkpoint:** Rollout status shows `Degraded` on the bad revision, then returns to `Healthy` on the previous stable image. Active traffic was never interrupted. The dashboard shows a red analysis result on the aborted revision.

---

### Canary vs Blue-Green — What you observed

| | Canary (Milestones 2–4) | Blue-Green (Milestone 5) |
|---|---|---|
| Traffic shift | Progressive (10% → 30% → 60% → 100%) | Atomic (0% → 100%) |
| Resource cost during rollout | 1–2 extra pods (canary only) | Full second environment (5 + 2 pods) |
| Rollback speed | Gradual, weighted back to stable | Instant endpoint switch |
| Pre-promotion testing | Analysis runs mid-step | Full preview environment available |
| Good for | Gradual risk reduction, A/B traffic | Zero-downtime hard cutover, staging parity |

### Review Questions

1. Why can't you change the rollout strategy (canary → blue-green) on a live Rollout without deleting and recreating it?
2. With `previewReplicaCount: 2` and `replicas: 5`, how many pods are running during the pause phase? Why is this asymmetric?
3. What does `scaleDownDelaySeconds: 30` protect against, and how does it relate to connection draining?
4. How does `prePromotionAnalysis` in blue-green differ from the inline `analysis` step used in the canary steps array in Milestone 3?


> ✅ **Checkpoint:** Blue and green environments are visible in the dashboard. Manual promotion switches live traffic with zero downtime.

---

### Lab 3 — Review Questions

1. When would you choose a canary strategy over a blue-green strategy for an IoT service?
2. What happens to the canary pods when an AnalysisRun reports failure?
3. How does `prePromotionAnalysis` differ from an inline `analysis` step in the canary steps array?
