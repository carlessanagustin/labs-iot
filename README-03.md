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
# TODO: carles
**Step 1: Create stable and canary services**

```yaml
# rollouts/services.yaml
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
# rollouts/telemetry-ingestion-rollout.yaml
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
kubectl apply -f rollouts/services.yaml
kubectl apply -f rollouts/telemetry-ingestion-rollout.yaml
```

---

### Milestone 3 — Create an AnalysisTemplate

The AnalysisTemplate queries Prometheus to ensure the canary's HTTP error rate stays below 5% before each promotion step.

```yaml
# rollouts/analysis-error-rate.yaml
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
kubectl apply -f rollouts/analysis-error-rate.yaml
kubectl get analysistemplates -n iot-platform
```

> ✅ **Checkpoint:** `kubectl get analysistemplates -n iot-platform` shows `telemetry-error-rate`.

---

### Milestone 4 — Trigger and Observe a Canary Rollout

**Step 1: Trigger a new version by updating the image**

```bash
kubectl argo rollouts set image telemetry-ingestion \
  telemetry-ingestion=nginx:1.25 \
  -n iot-platform
```

**Step 2: Watch the rollout progress**

```bash
kubectl argo rollouts get rollout telemetry-ingestion \
  -n iot-platform \
  --watch
```

**Step 3: Open the Argo Rollouts dashboard**

```bash
kubectl argo rollouts dashboard &
# Opens at http://localhost:3100
```

**Step 4: Manually promote past a pause step**

```bash
kubectl argo rollouts promote telemetry-ingestion -n iot-platform
```

**Step 5: Test aborting a bad rollout**

```bash
kubectl argo rollouts set image telemetry-ingestion \
  telemetry-ingestion=nginx:broken-tag-999 \
  -n iot-platform

# Monitor AnalysisRun failing, then abort
kubectl argo rollouts abort telemetry-ingestion -n iot-platform
kubectl argo rollouts undo telemetry-ingestion -n iot-platform
```

> ✅ **Checkpoint:** The rollout automatically rolls back to the stable version when the AnalysisRun fails. The dashboard shows a red analysis result and the stable pods re-scale.

---

### Milestone 5 — Blue-Green for the Firmware Update Service

```yaml
# rollouts/firmware-update-bluegreen.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: firmware-update-service
  namespace: iot-platform
spec:
  replicas: 3
  selector:
    matchLabels:
      app: firmware-update
  template:
    metadata:
      labels:
        app: firmware-update
    spec:
      containers:
        - name: firmware-update
          image: nginx:1.24
          ports:
            - containerPort: 80
  strategy:
    blueGreen:
      activeService: firmware-update-active
      previewService: firmware-update-preview
      autoPromotionEnabled: false        # require manual approval
      scaleDownDelaySeconds: 30
      previewReplicaCount: 2
      prePromotionAnalysis:
        templates:
          - templateName: telemetry-error-rate
        args:
          - name: service-name
            value: firmware-update
```

```bash
kubectl apply -f rollouts/firmware-update-bluegreen.yaml

# After verifying preview environment:
kubectl argo rollouts promote firmware-update-service -n iot-platform
```

> ✅ **Checkpoint:** Blue and green environments are visible in the dashboard. Manual promotion switches live traffic with zero downtime.

---

### Lab 3 — Review Questions

1. When would you choose a canary strategy over a blue-green strategy for an IoT service?
2. What happens to the canary pods when an AnalysisRun reports failure?
3. How does `prePromotionAnalysis` differ from an inline `analysis` step in the canary steps array?
