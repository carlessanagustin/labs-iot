# IoT Platform — Practice Labs

## Table of Contents

- [IoT Platform — Practice Labs](#iot-platform--practice-labs)
  - [Table of Contents](#table-of-contents)
  - [Architecture Overview](#architecture-overview)
  - [Prerequisites (All Labs)](#prerequisites-all-labs)
  - [Lab 1 — Beginner: GitOps Deployment of the IoT Telemetry Stack with Argo CD](#lab-1--beginner-gitops-deployment-of-the-iot-telemetry-stack-with-argo-cd)
    - [Learning Objectives](#learning-objectives)
    - [Milestone 1 — Install Argo CD](#milestone-1--install-argo-cd)
    - [Milestone 2 — Set Up the IoT GitOps Repository](#milestone-2--set-up-the-iot-gitops-repository)
    - [Milestone 3 — Create Argo CD Applications](#milestone-3--create-argo-cd-applications)
    - [Milestone 4 — Test Self-Healing and Rollback](#milestone-4--test-self-healing-and-rollback)
    - [Lab 1 — Review Questions](#lab-1--review-questions)
  - [Lab 2 — Beginner–Intermediate: IoT Telemetry Data Pipeline with Argo Workflows](#lab-2--beginnerintermediate-iot-telemetry-data-pipeline-with-argo-workflows)
    - [Learning Objectives](#learning-objectives-1)
    - [Milestone 1 — Install Argo Workflows](#milestone-1--install-argo-workflows)
    - [Milestone 2 — Submit Your First IoT Workflow](#milestone-2--submit-your-first-iot-workflow)
    - [Milestone 3 — Build a Multi-Step Telemetry DAG](#milestone-3--build-a-multi-step-telemetry-dag)
    - [Milestone 4 — Schedule with CronWorkflow](#milestone-4--schedule-with-cronworkflow)
    - [Lab 2 — Review Questions](#lab-2--review-questions)
  - [Lab 3 — Intermediate: Safe IoT Service Rollouts with Argo Rollouts](#lab-3--intermediate-safe-iot-service-rollouts-with-argo-rollouts)
    - [Learning Objectives](#learning-objectives-2)
    - [Milestone 1 — Install Argo Rollouts](#milestone-1--install-argo-rollouts)
    - [Milestone 2 — Deploy the Telemetry Ingestion Service as a Rollout](#milestone-2--deploy-the-telemetry-ingestion-service-as-a-rollout)
    - [Milestone 3 — Create an AnalysisTemplate](#milestone-3--create-an-analysistemplate)
    - [Milestone 4 — Trigger and Observe a Canary Rollout](#milestone-4--trigger-and-observe-a-canary-rollout)
    - [Milestone 5 — Blue-Green for the Firmware Update Service](#milestone-5--blue-green-for-the-firmware-update-service)
    - [Lab 3 — Review Questions](#lab-3--review-questions)
  - [Lab 4 — Intermediate–Advanced: IoT Developer Portal with Backstage and Crossplane](#lab-4--intermediateadvanced-iot-developer-portal-with-backstage-and-crossplane)
    - [Learning Objectives](#learning-objectives-3)
    - [Milestone 1 — Scaffold the Backstage Developer Portal](#milestone-1--scaffold-the-backstage-developer-portal)
    - [Milestone 2 — Register IoT Services in the Catalog](#milestone-2--register-iot-services-in-the-catalog)
    - [Milestone 3 — Define the Crossplane IoT Fleet XRD and Composition](#milestone-3--define-the-crossplane-iot-fleet-xrd-and-composition)
    - [Milestone 4 — Create the Backstage Software Template](#milestone-4--create-the-backstage-software-template)
    - [Lab 4 — Review Questions](#lab-4--review-questions)
  - [Lab 5 — Advanced: Full IoT GitOps Platform — Argo Workflows + CD + Rollouts + Backstage + Crossplane](#lab-5--advanced-full-iot-gitops-platform--argo-workflows--cd--rollouts--backstage--crossplane)
    - [Learning Objectives](#learning-objectives-4)
    - [Milestone 1 — Provision ML Pipeline Infrastructure with Crossplane](#milestone-1--provision-ml-pipeline-infrastructure-with-crossplane)
    - [Milestone 2 — ML Anomaly Detection Training Workflow](#milestone-2--ml-anomaly-detection-training-workflow)
    - [Milestone 3 — App-of-Apps: Argo CD Managing the Full IoT Stack](#milestone-3--app-of-apps-argo-cd-managing-the-full-iot-stack)
    - [Milestone 4 — Canary Rollout Triggered by Argo CD Sync](#milestone-4--canary-rollout-triggered-by-argo-cd-sync)
    - [Milestone 5 — Backstage TechDocs: Document the Full Platform](#milestone-5--backstage-techdocs-document-the-full-platform)
    - [Lab 5 — Review Questions](#lab-5--review-questions)
  - [Summary Table](#summary-table)
  - [Recommended Learning Path](#recommended-learning-path)

---

> **IoT Architecture Context:** All labs are set in an industrial IoT platform scenario: a fleet of edge devices (temperature sensors, vibration monitors, and gateway nodes) streams telemetry to a Kubernetes-hosted data pipeline. The platform team manages infrastructure with Crossplane, exposes a developer portal via Backstage, deploys services with Argo CD, runs data processing with Argo Workflows, and promotes new firmware/software releases safely with Argo Rollouts.

---

## Architecture Overview

```
IoT Devices (Edge)
    │
    ▼
MQTT Broker (Mosquitto)
    │
    ▼
Telemetry Ingestion Service  ◄──── Argo Rollouts (canary / blue-green)
    │
    ▼
Stream Processor (Kafka)
    │
    ├── Argo Workflows (batch analytics, ML model training)
    │
    ▼
Time-Series DB (InfluxDB) + PostgreSQL
    │
    ▼
Dashboard / API (Grafana + REST)
    │
    ▼
Backstage Developer Portal  ◄──── Service Catalog + Software Templates
    │
    ▼
Crossplane  ◄──── Cloud infra (IoT Core, S3, RDS, Kafka MSK)
    │
    ▼
Argo CD  ◄──── GitOps delivery for all of the above
```

## Prerequisites (All Labs)

| Tool | Version | Purpose |
|---|---|---|
| `kubectl` | v1.28+ | Cluster access |
| `helm` | v3.12+ | Package installation |
| `kind` or managed K8s | — | Local or cloud cluster |
| Crossplane CLI (`crossplane`) | v1.14+ | Package management |
| Argo CLI (`argo`) | v3.5+ | Workflow submission |
| `argocd` CLI | v2.9+ | CD management |
| Node.js | v18+ | Backstage portal |
| AWS CLI | v2 | Cloud provider (Labs 3–5) |

---

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

---
---

## Lab 2 — Beginner–Intermediate: IoT Telemetry Data Pipeline with Argo Workflows

**Level:** ⭐⭐ Beginner–Intermediate
**Duration:** 90–120 minutes
**Argo Tools:** Argo Workflows
**IoT Focus:** Build a multi-step DAG workflow that ingests raw sensor data, validates it, enriches it with device metadata, and stores aggregated metrics.

### Learning Objectives

- Install Argo Workflows and access the UI
- Submit a simple single-step workflow
- Build a multi-step DAG for telemetry data processing
- Use workflow templates for reusability
- Implement conditional steps and error handling
- Schedule a recurring workflow with `CronWorkflow`

---

### Milestone 1 — Install Argo Workflows

**Step 1: Install into the argo namespace**

```bash
kubectl create namespace argo

kubectl apply -n argo -f \
  https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
```

**Step 2: Patch the auth mode for local access**

```bash
kubectl patch deployment \
  argo-server \
  --namespace argo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server"
]}]'
```

**Step 3: Forward the UI port**

```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746 &
```

**Step 4: Verify with the Argo CLI**

```bash
argo version
argo list -n argo
```

> ✅ **Checkpoint:** Open `https://localhost:2746`. The Argo Workflows UI loads. Running `argo list` returns an empty table.

---

### Milestone 2 — Submit Your First IoT Workflow

**Step 1: Create a sensor data validation workflow**

```yaml
# workflows/01-validate-sensor.yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: validate-sensor-
  namespace: argo
  labels:
    component: iot-pipeline
    stage: validation
spec:
  entrypoint: validate-reading
  arguments:
    parameters:
      - name: device-id
        value: "sensor-001"
      - name: temperature
        value: "23.5"
      - name: humidity
        value: "61.2"

  templates:
    - name: validate-reading
      inputs:
        parameters:
          - name: device-id
          - name: temperature
          - name: humidity
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import sys

          device_id   = "{{inputs.parameters.device-id}}"
          temperature = float("{{inputs.parameters.temperature}}")
          humidity    = float("{{inputs.parameters.humidity}}")

          errors = []
          if not (-40 <= temperature <= 85):
              errors.append(f"Temperature {temperature}C out of range [-40, 85]")
          if not (0 <= humidity <= 100):
              errors.append(f"Humidity {humidity}% out of range [0, 100]")

          if errors:
              print(f"[FAIL] {device_id}: {'; '.join(errors)}")
              sys.exit(1)
          else:
              print(f"[PASS] {device_id}: temp={temperature}C hum={humidity}%")
```

**Step 2: Submit and observe**

```bash
argo submit -n argo workflows/01-validate-sensor.yaml --watch

# View logs
argo logs -n argo @latest
```

> ✅ **Checkpoint:** Workflow completes with status `Succeeded`. Logs show `[PASS] sensor-001`.

---

### Milestone 3 — Build a Multi-Step Telemetry DAG

**Step 1: Create the full telemetry processing DAG**

```yaml
# workflows/02-telemetry-pipeline-dag.yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: telemetry-pipeline-
  namespace: argo
  labels:
    component: iot-pipeline
spec:
  entrypoint: iot-dag
  arguments:
    parameters:
      - name: batch-id
        value: "batch-20240315-001"
      - name: device-id
        value: "gateway-edge-07"

  templates:

    # DAG orchestrator
    - name: iot-dag
      dag:
        tasks:
          - name: ingest
            template: ingest-raw-data
            arguments:
              parameters:
                - name: batch-id
                  value: "{{workflow.parameters.batch-id}}"

          - name: validate
            template: validate-readings
            dependencies: [ingest]
            arguments:
              parameters:
                - name: raw-count
                  value: "{{tasks.ingest.outputs.parameters.raw-count}}"

          - name: enrich
            template: enrich-with-metadata
            dependencies: [validate]
            arguments:
              parameters:
                - name: valid-count
                  value: "{{tasks.validate.outputs.parameters.valid-count}}"
                - name: device-id
                  value: "{{workflow.parameters.device-id}}"

          - name: aggregate
            template: compute-aggregates
            dependencies: [enrich]

          - name: alert-check
            template: check-thresholds
            dependencies: [enrich]

          - name: store
            template: persist-to-db
            dependencies: [aggregate]

    # Step templates
    - name: ingest-raw-data
      inputs:
        parameters:
          - name: batch-id
      outputs:
        parameters:
          - name: raw-count
            valueFrom:
              path: /tmp/raw-count.txt
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import json, random, time

          readings = [
            {
              "ts": int(time.time()) + i,
              "sensor": f"S{i:03d}",
              "temp": round(20 + random.uniform(-5, 15), 2),
              "hum":  round(55 + random.uniform(-10, 20), 2),
              "vib":  round(random.uniform(0, 2.5), 3)
            }
            for i in range(50)
          ]
          with open("/tmp/raw-count.txt", "w") as f:
              f.write(str(len(readings)))
          print(f"Ingested {len(readings)} readings for batch {{inputs.parameters.batch-id}}")

    - name: validate-readings
      inputs:
        parameters:
          - name: raw-count
      outputs:
        parameters:
          - name: valid-count
            valueFrom:
              path: /tmp/valid-count.txt
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          raw  = int("{{inputs.parameters.raw-count}}")
          # Simulate ~5% drop rate
          valid = int(raw * 0.95)
          dropped = raw - valid
          print(f"Validated: {valid} accepted, {dropped} dropped (out-of-range)")
          with open("/tmp/valid-count.txt", "w") as f:
              f.write(str(valid))

    - name: enrich-with-metadata
      inputs:
        parameters:
          - name: valid-count
          - name: device-id
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          count = "{{inputs.parameters.valid-count}}"
          device = "{{inputs.parameters.device-id}}"
          print(f"Enriched {count} readings from {device}")
          print(f"  location=building-a-floor-2 firmware=v2.3.1 protocol=MQTT-5")

    - name: compute-aggregates
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import random
          avg_temp = round(20 + random.uniform(0, 10), 2)
          avg_hum  = round(55 + random.uniform(-5, 15), 2)
          avg_vib  = round(random.uniform(0.1, 1.2), 3)
          print(f"Aggregates: avg_temp={avg_temp}C  avg_hum={avg_hum}%  avg_vib={avg_vib}g")

    - name: check-thresholds
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import random
          alerts = random.randint(0, 4)
          if alerts:
              print(f"[ALERT] {alerts} readings exceed temperature or vibration thresholds")
          else:
              print("[OK] All readings within safe thresholds")

    - name: persist-to-db
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          # In production: write to InfluxDB / TimescaleDB
          print("[STORED] Aggregated metrics written to time-series database")
```

**Step 2: Submit the DAG**

```bash
argo submit -n argo workflows/02-telemetry-pipeline-dag.yaml --watch
```

**Step 3: Inspect the DAG graph in the UI**

Open `https://localhost:2746` → click the workflow → switch to **Graph** view. Observe that `aggregate` and `alert-check` run in parallel after `enrich`.

> ✅ **Checkpoint:** Workflow completes successfully. The DAG shows 6 nodes: ingest → validate → enrich → (aggregate + alert-check in parallel) → store.

---

### Milestone 4 — Schedule with CronWorkflow

**Step 1: Create a recurring telemetry batch job**

```yaml
# workflows/03-telemetry-cron.yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: telemetry-batch-every-5min
  namespace: argo
spec:
  schedule: "*/5 * * * *"
  timezone: "UTC"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 30
  workflowSpec:
    entrypoint: ingest-batch
    templates:
      - name: ingest-batch
        script:
          image: python:3.11-slim
          command: [python]
          source: |
            import datetime
            ts = datetime.datetime.utcnow().isoformat()
            print(f"[{ts}] Running scheduled telemetry batch ingestion")
```

```bash
kubectl apply -f workflows/03-telemetry-cron.yaml
kubectl get cronworkflows -n argo
```

> ✅ **Checkpoint:** CronWorkflow is listed. Within 5 minutes, a new child workflow run appears under `argo list`.

---

### Lab 2 — Review Questions

1. What is the difference between a `steps` workflow and a `dag` workflow?
2. How does Argo Workflows pass data between steps using output parameters?
3. Why would you use `CronWorkflow` instead of a Kubernetes `CronJob` for IoT batch jobs?

---
---

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

kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Step 2: Install the kubectl plugin**

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
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

> ✅ **Checkpoint:** `kubectl get pods -n argo-rollouts` shows the controller running. `kubectl argo rollouts version` returns the installed version.

---

### Milestone 2 — Deploy the Telemetry Ingestion Service as a Rollout

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

---
---

## Lab 4 — Intermediate–Advanced: IoT Developer Portal with Backstage and Crossplane

**Level:** ⭐⭐⭐⭐ Intermediate–Advanced
**Duration:** 2–3 hours
**Tools:** Backstage · Crossplane
**IoT Focus:** Build an internal developer portal where IoT engineers can self-provision cloud infrastructure (IoT Core, S3, RDS) via Backstage Software Templates backed by Crossplane Compositions.

### Learning Objectives

- Scaffold a Backstage app and register IoT services in the catalog
- Create a Software Template for IoT device fleet provisioning
- Define a Crossplane XRD and Composition to back the Backstage template
- Integrate the Argo CD Backstage plugin for deployment visibility
- Register TechDocs for IoT platform services

---

### Milestone 1 — Scaffold the Backstage Developer Portal

**Step 1: Create a new Backstage app**

```bash
npx @backstage/create-app@latest --name iot-developer-portal
cd iot-developer-portal
```

**Step 2: Start the portal in development mode**

```bash
yarn dev
# Opens at http://localhost:3000
```

**Step 3: Add the Argo CD plugin to Backstage**

```bash
yarn --cwd packages/app add @roadiehq/backstage-plugin-argo-cd
```

Edit `packages/app/src/components/catalog/EntityPage.tsx`:

```typescript
import { ArgoCDOverviewCard } from '@roadiehq/backstage-plugin-argo-cd';

// Inside serviceEntityPage const, add:
<EntitySwitch>
  <EntitySwitch.Case if={isArgocdAvailable}>
    <Grid item sm={6}>
      <ArgoCDOverviewCard />
    </Grid>
  </EntitySwitch.Case>
</EntitySwitch>
```

**Step 4: Configure Argo CD integration in app-config.yaml**

```yaml
argocd:
  username: admin
  password: ${ARGOCD_AUTH_TOKEN}
  appLocatorMethods:
    - type: 'config'
      instances:
        - name: argocd
          url: https://localhost:8080
```

> ✅ **Checkpoint:** Backstage portal loads at `localhost:3000`. The home page shows the example catalog entities.

---

### Milestone 2 — Register IoT Services in the Catalog

**Step 1: Create catalog entities**

```yaml
# catalog/iot-platform-catalog.yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: iot-platform
  description: Industrial IoT telemetry and device management platform
  tags: [iot, telemetry, edge-computing]
  links:
    - url: https://grafana.iot.example.com
      title: Grafana Dashboard
      icon: dashboard
spec:
  owner: platform-team
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: telemetry-ingestion
  description: MQTT-to-Kafka bridge for IoT sensor data ingestion
  annotations:
    argocd/app-name: telemetry-api
    backstage.io/techdocs-ref: dir:.
  tags: [mqtt, kafka, ingestion]
spec:
  type: service
  lifecycle: production
  owner: iot-team
  system: iot-platform
  providesApis: [telemetry-api]
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: firmware-update-service
  description: OTA firmware distribution service for edge devices
  annotations:
    argocd/app-name: firmware-update-service
  tags: [ota, firmware, edge]
spec:
  type: service
  lifecycle: production
  owner: firmware-team
  system: iot-platform
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: telemetry-api
  description: REST API for querying device telemetry
spec:
  type: openapi
  lifecycle: production
  owner: iot-team
  system: iot-platform
  definition: |
    openapi: "3.0.0"
    info:
      title: Telemetry API
      version: "1.0"
    paths:
      /readings:
        get:
          summary: Get latest sensor readings
          parameters:
            - name: device_id
              in: query
              schema:
                type: string
          responses:
            "200":
              description: List of sensor readings
```

**Step 2: Register the catalog file**

In `app-config.yaml`:

```yaml
catalog:
  locations:
    - type: file
      target: ../../catalog/iot-platform-catalog.yaml
      rules:
        - allow: [System, Component, API, Template]
```

> ✅ **Checkpoint:** All three IoT catalog entities appear in the portal. Clicking `telemetry-ingestion` shows the Argo CD deployment status widget.

---

### Milestone 3 — Define the Crossplane IoT Fleet XRD and Composition

**Step 1: Create the XRD**

```yaml
# crossplane/xrd-iotfleet.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xiotfleets.platform.iot.example.com
spec:
  group: platform.iot.example.com
  names:
    kind: XIoTFleet
    plural: xiotfleets
  claimNames:
    kind: IoTFleet
    plural: iotfleets
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [parameters]
              properties:
                parameters:
                  type: object
                  required: [fleetName, region, maxDevices, environment]
                  properties:
                    fleetName:
                      type: string
                    region:
                      type: string
                      enum: [us-east-1, eu-west-1, ap-southeast-1]
                    maxDevices:
                      type: integer
                      minimum: 1
                      maximum: 10000
                    environment:
                      type: string
                      enum: [dev, staging, prod]
                    retentionDays:
                      type: integer
                      default: 90
```

**Step 2: Create the Composition**

```yaml
# crossplane/composition-iotfleet.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: iotfleet-aws
  labels:
    provider: aws
    service: iot-fleet
spec:
  compositeTypeRef:
    apiVersion: platform.iot.example.com/v1alpha1
    kind: XIoTFleet
  mode: Pipeline
  pipeline:
    - step: render-fleet-resources
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
            {{- $name   := .observed.composite.resource.metadata.name }}
            {{- $region := .observed.composite.resource.spec.parameters.region }}
            {{- $env    := .observed.composite.resource.spec.parameters.environment }}
            ---
            apiVersion: s3.aws.upbound.io/v1beta1
            kind: Bucket
            metadata:
              annotations:
                gotemplating.fn.crossplane.io/composition-resource-name: firmware-bucket
                crossplane.io/external-name: "iot-firmware-{{ $env }}-{{ $name }}"
            spec:
              forProvider:
                region: {{ $region }}
              providerConfigRef:
                name: default
    - step: auto-ready
      functionRef:
        name: function-auto-ready
```

```bash
kubectl apply -f crossplane/xrd-iotfleet.yaml
kubectl apply -f crossplane/composition-iotfleet.yaml
```

---

### Milestone 4 — Create the Backstage Software Template

```yaml
# templates/iot-fleet-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: iot-fleet-provisioner
  title: Provision IoT Device Fleet
  description: >
    Self-service template to provision a complete IoT fleet:
    S3 firmware bucket, device registry, and Crossplane claim.
  tags: [iot, infrastructure, crossplane]
spec:
  owner: platform-team
  type: infrastructure

  parameters:
    - title: Fleet Configuration
      required: [fleetName, environment, region]
      properties:
        fleetName:
          title: Fleet Name
          type: string
          description: Unique identifier (e.g. factory-line-a)
          pattern: '^[a-z][a-z0-9-]{2,30}$'
        environment:
          title: Environment
          type: string
          enum: [dev, staging, prod]
          default: dev
        region:
          title: AWS Region
          type: string
          enum: [us-east-1, eu-west-1, ap-southeast-1]
          default: eu-west-1
        maxDevices:
          title: Maximum Devices
          type: integer
          minimum: 1
          maximum: 10000
          default: 500

    - title: Ownership
      required: [owner, repoUrl]
      properties:
        owner:
          title: Owner
          type: string
          ui:field: OwnerPicker
          ui:options:
            allowedKinds: [Group]
        repoUrl:
          title: Git Repository
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts: [github.com]

  steps:
    - id: create-crossplane-claim
      name: Create Crossplane IoTFleet Claim
      action: kubernetes:apply
      input:
        manifest:
          apiVersion: platform.iot.example.com/v1alpha1
          kind: IoTFleet
          metadata:
            name: ${{ parameters.fleetName }}
            namespace: iot-fleets
            labels:
              backstage.io/template: iot-fleet-provisioner
              environment: ${{ parameters.environment }}
          spec:
            parameters:
              fleetName: ${{ parameters.fleetName }}
              region: ${{ parameters.region }}
              maxDevices: ${{ parameters.maxDevices }}
              environment: ${{ parameters.environment }}
            writeConnectionSecretsToRef:
              name: ${{ parameters.fleetName }}-connection

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: [github.com]
        description: IoT fleet ${{ parameters.fleetName }} infrastructure
        repoUrl: ${{ parameters.repoUrl }}

    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Fleet Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: View in Catalog
        url: ${{ steps.register.output.catalogInfoUrl }}
```

```yaml
# Add to app-config.yaml
catalog:
  locations:
    - type: file
      target: ../../templates/iot-fleet-template.yaml
      rules:
        - allow: [Template]
```

> ✅ **Checkpoint:** Navigate to **Create** in Backstage. The "Provision IoT Device Fleet" template appears. Submitting the form creates a Crossplane `IoTFleet` Claim and registers the fleet in the catalog.

---

### Lab 4 — Review Questions

1. What is the role of a Backstage Software Template vs a Crossplane Composition?
2. How does the catalog `annotations` field enable integration with Argo CD?
3. What security considerations arise when Backstage has `kubectl apply` access to the cluster?

---
---

## Lab 5 — Advanced: Full IoT GitOps Platform — Argo Workflows + CD + Rollouts + Backstage + Crossplane

**Level:** ⭐⭐⭐⭐⭐ Advanced
**Duration:** 3–5 hours
**All Tools:** Argo Workflows · Argo CD · Argo Rollouts · Backstage · Crossplane
**IoT Focus:** End-to-end automated pipeline: an ML anomaly detection model is trained by Argo Workflows → on quality gate pass it triggers Argo CD sync → Argo Rollouts executes a Prometheus-analysed canary → Backstage surfaces the live status throughout.

### Learning Objectives

- Orchestrate a complete MLOps pipeline for IoT anomaly detection
- Trigger Argo CD sync programmatically from an Argo Workflow
- Chain Argo Rollouts canary promotion to Workflow output
- Use Crossplane to provision cloud resources consumed by the pipeline
- Surface the entire flow in Backstage TechDocs

---

### Milestone 1 — Provision ML Pipeline Infrastructure with Crossplane

**Step 1: Create the XRD for the ML pipeline**

```yaml
# crossplane/xrd-ml-pipeline.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xmlpipelines.platform.iot.example.com
spec:
  group: platform.iot.example.com
  names:
    kind: XMLPipeline
    plural: xmlpipelines
  claimNames:
    kind: MLPipeline
    plural: mlpipelines
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [parameters]
              properties:
                parameters:
                  type: object
                  required: [pipelineName, region]
                  properties:
                    pipelineName:
                      type: string
                    region:
                      type: string
                    modelBucketSizeGb:
                      type: integer
                      default: 50
```

**Step 2: Create the Composition (S3 model bucket + S3 training data bucket)**

```yaml
# crossplane/composition-ml-pipeline.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: ml-pipeline-aws
  labels:
    provider: aws
spec:
  compositeTypeRef:
    apiVersion: platform.iot.example.com/v1alpha1
    kind: XMLPipeline
  mode: Pipeline
  pipeline:
    - step: render-resources
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
            {{- $name   := .observed.composite.resource.metadata.name }}
            {{- $region := .observed.composite.resource.spec.parameters.region }}
            ---
            apiVersion: s3.aws.upbound.io/v1beta1
            kind: Bucket
            metadata:
              annotations:
                gotemplating.fn.crossplane.io/composition-resource-name: model-bucket
                crossplane.io/external-name: "iot-ml-models-{{ $name }}"
            spec:
              forProvider:
                region: {{ $region }}
              providerConfigRef:
                name: default
            ---
            apiVersion: s3.aws.upbound.io/v1beta1
            kind: Bucket
            metadata:
              annotations:
                gotemplating.fn.crossplane.io/composition-resource-name: training-data-bucket
                crossplane.io/external-name: "iot-training-data-{{ $name }}"
            spec:
              forProvider:
                region: {{ $region }}
              providerConfigRef:
                name: default
    - step: auto-ready
      functionRef:
        name: function-auto-ready
```

**Step 3: File a Claim for the anomaly detection pipeline**

```yaml
# crossplane/claims/anomaly-pipeline.yaml
apiVersion: platform.iot.example.com/v1alpha1
kind: MLPipeline
metadata:
  name: anomaly-detection
  namespace: iot-platform
spec:
  parameters:
    pipelineName: anomaly-detection
    region: eu-west-1
    modelBucketSizeGb: 100
  writeConnectionSecretsToRef:
    name: anomaly-pipeline-connection
```

```bash
kubectl apply -f crossplane/xrd-ml-pipeline.yaml
kubectl apply -f crossplane/composition-ml-pipeline.yaml
kubectl apply -f crossplane/claims/anomaly-pipeline.yaml

kubectl get mlpipeline -n iot-platform
kubectl get buckets | grep iot-ml
```

> ✅ **Checkpoint:** Both S3 buckets exist (`iot-ml-models-anomaly-detection` and `iot-training-data-anomaly-detection`). MLPipeline Claim shows `READY: True`.

---

### Milestone 2 — ML Anomaly Detection Training Workflow

**Step 1: Create the ServiceAccount and RBAC**

```yaml
# workflows/sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-workflow-sa
  namespace: argo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-workflow-sa-binding
subjects:
  - kind: ServiceAccount
    name: argo-workflow-sa
    namespace: argo
roleRef:
  kind: ClusterRole
  name: cluster-admin   # Tighten scopes in production
  apiGroup: rbac.authorization.k8s.io
```

**Step 2: Create the Argo CD API token secret**

```bash
ARGOCD_TOKEN=$(argocd account generate-token --account admin)
kubectl create secret generic argocd-api-token \
  -n argo \
  --from-literal=token="${ARGOCD_TOKEN}"
```

**Step 3: Create the WorkflowTemplate**

```yaml
# workflows/anomaly-training-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: iot-anomaly-training
  namespace: argo
spec:
  entrypoint: training-pipeline
  serviceAccountName: argo-workflow-sa
  arguments:
    parameters:
      - name: model-version
        value: "v0.0.0"
      - name: training-bucket
        value: "iot-training-data-anomaly-detection"
      - name: model-bucket
        value: "iot-ml-models-anomaly-detection"
      - name: argocd-app
        value: "telemetry-api"

  templates:
    - name: training-pipeline
      dag:
        tasks:
          - name: fetch-training-data
            template: fetch-data

          - name: feature-engineering
            template: engineer-features
            dependencies: [fetch-training-data]

          - name: train-model
            template: train-isolation-forest
            dependencies: [feature-engineering]

          - name: evaluate-model
            template: evaluate
            dependencies: [train-model]

          - name: promote-model
            template: promote-to-registry
            dependencies: [evaluate-model]
            # Only promote if precision exceeds the quality gate
            when: "{{tasks.evaluate-model.outputs.parameters.precision}} > 0.90"
            arguments:
              parameters:
                - name: precision
                  value: "{{tasks.evaluate-model.outputs.parameters.precision}}"

          - name: trigger-cd
            template: trigger-argocd-sync
            dependencies: [promote-model]
            arguments:
              parameters:
                - name: app-name
                  value: "{{workflow.parameters.argocd-app}}"

    - name: fetch-data
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import time
          print(f"Fetching training data from s3://{{workflow.parameters.training-bucket}}/latest/")
          print("Fetched 10,000 labelled sensor readings (95% normal, 5% anomalous)")

    - name: engineer-features
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          features = [
            "temp_rolling_mean_5m",
            "temp_rolling_std_5m",
            "vibration_fft_band_0_50hz",
            "vibration_fft_band_50_200hz",
            "current_draw_delta",
          ]
          print(f"Engineered {len(features)} features from raw readings")
          print(f"  Features: {', '.join(features)}")

    - name: train-isolation-forest
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import time, random
          print("Training Isolation Forest anomaly detector")
          print("  n_estimators=200  contamination=0.05")
          for epoch in range(1, 6):
              time.sleep(0.4)
              loss = round(0.45 - epoch * 0.07 + random.uniform(-0.01, 0.01), 4)
              print(f"  Epoch {epoch}/5 -- loss={loss}")
          print("Training complete")

    - name: evaluate
      outputs:
        parameters:
          - name: precision
            valueFrom:
              path: /tmp/precision.txt
          - name: recall
            valueFrom:
              path: /tmp/recall.txt
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import random
          precision = round(random.uniform(0.88, 0.97), 4)
          recall    = round(random.uniform(0.82, 0.93), 4)
          f1        = round(2 * precision * recall / (precision + recall), 4)
          print(f"Precision : {precision}")
          print(f"Recall    : {recall}")
          print(f"F1 Score  : {f1}")
          gate = "PASS" if precision > 0.90 else "FAIL"
          print(f"Quality gate: {gate} (threshold: precision > 0.90)")
          with open("/tmp/precision.txt", "w") as f: f.write(str(precision))
          with open("/tmp/recall.txt",    "w") as f: f.write(str(recall))

    - name: promote-to-registry
      inputs:
        parameters:
          - name: precision
      script:
        image: python:3.11-slim
        command: [python]
        source: |
          import time
          print(f"Promoting model {{workflow.parameters.model-version}} to S3 registry")
          print(f"  Precision: {{inputs.parameters.precision}}")
          print(f"  Target: s3://{{workflow.parameters.model-bucket}}/{{workflow.parameters.model-version}}/")
          time.sleep(1)
          print("Model promoted successfully")

    - name: trigger-argocd-sync
      inputs:
        parameters:
          - name: app-name
      script:
        image: curlimages/curl:8.5.0
        command: [sh]
        source: |
          echo "Triggering Argo CD sync for app: {{inputs.parameters.app-name}}"
          curl -sk -X POST \
            -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
            -H "Content-Type: application/json" \
            "https://argocd-server.argocd.svc.cluster.local/api/v1/applications/{{inputs.parameters.app-name}}/sync" \
            -d '{"revision":"main","prune":false,"dryRun":false}' \
            && echo "Sync triggered successfully" \
            || echo "Sync trigger failed -- check Argo CD token"
        env:
          - name: ARGOCD_TOKEN
            valueFrom:
              secretKeyRef:
                name: argocd-api-token
                key: token
```

**Step 4: Apply and submit**

```bash
kubectl apply -f workflows/sa.yaml
kubectl apply -f workflows/anomaly-training-template.yaml

argo submit -n argo \
  --from workflowtemplate/iot-anomaly-training \
  -p model-version=v1.2.0 \
  --watch
```

> ✅ **Checkpoint:** When `precision > 0.90`, `promote-model` and `trigger-cd` run. When precision falls below threshold, those steps are skipped — protecting production from a bad model.

---

### Milestone 3 — App-of-Apps: Argo CD Managing the Full IoT Stack

**Step 1: Create the root App-of-Apps application**

```yaml
# argocd-apps/iot-root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-platform-root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/iot-gitops.git
    targetRevision: main
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Step 2: Populate argocd-apps/ with child Application manifests**

```
argocd-apps/
├── mqtt-broker-app.yaml              # from Lab 1
├── telemetry-api-app.yaml            # from Lab 1
├── firmware-update-app.yaml
├── crossplane-claims-app.yaml        # manages Crossplane claims via GitOps
└── argo-workflows-app.yaml           # deploys WorkflowTemplates via Argo CD
```

```bash
kubectl apply -f argocd-apps/iot-root-app.yaml
argocd app list
```

> ✅ **Checkpoint:** The root application syncs and auto-creates all child applications. The Argo CD UI shows a tree: `iot-platform-root` → 5 children, each green.

---

### Milestone 4 — Canary Rollout Triggered by Argo CD Sync

When the Workflow (Milestone 2) calls the Argo CD sync API, Argo CD applies the new Rollout manifest. Argo Rollouts intercepts the changed image and begins the canary sequence.

**Step 1: Ensure telemetry-api uses a Rollout (not a Deployment)**

Replace `apps/telemetry-api/deployment.yaml` with:

```yaml
# apps/telemetry-api/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: telemetry-api
  namespace: iot-platform
spec:
  replicas: 4
  selector:
    matchLabels:
      app: telemetry-api
  template:
    metadata:
      labels:
        app: telemetry-api
    spec:
      containers:
        - name: telemetry-api
          image: kennethreitz/httpbin:latest
          ports:
            - containerPort: 80
          env:
            - name: MODEL_VERSION
              value: "v1.2.0"
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 3m}
        - analysis:
            templates:
              - templateName: telemetry-error-rate
            args:
              - name: service-name
                value: telemetry-api
        - setWeight: 50
        - pause: {duration: 2m}
        - setWeight: 100
```

**Step 2: Commit, push, and observe**

```bash
git add apps/telemetry-api/rollout.yaml
git commit -m "feat: enable canary rollout for telemetry-api v1.2.0"
git push

# Argo CD detects the change and syncs
argocd app sync telemetry-api
kubectl argo rollouts get rollout telemetry-api -n iot-platform --watch
```

> ✅ **Checkpoint:** The full chain completes: Workflow trains model → triggers Argo CD sync → Argo CD applies Rollout → Rollout executes canary with Prometheus analysis → on success, 100% traffic shifts to the new version.

---

### Milestone 5 — Backstage TechDocs: Document the Full Platform

**Step 1: Add MkDocs configuration to the IoT portal repo**

```yaml
# docs/mkdocs.yml
site_name: IoT Platform Engineering Docs
docs_dir: docs
nav:
  - Home: index.md
  - Architecture: architecture.md
  - Workflow Pipelines: workflows.md
  - Deployment Strategy: deployments.md
  - Infrastructure: infrastructure.md
  - Runbooks: runbooks.md
```

**Step 2: Write the architecture page**

```markdown
<!-- docs/docs/architecture.md -->

## IoT Platform End-to-End Pipeline

### Data Flow

1. Edge sensors publish telemetry over MQTT to the Mosquitto broker
2. The telemetry ingestion service bridges MQTT to Kafka
3. Argo Workflows runs nightly batch jobs for aggregation and ML training
4. When a model passes the quality gate, the workflow calls Argo CD sync
5. Argo CD applies the updated Rollout manifest
6. Argo Rollouts executes a Prometheus-analysed canary deployment
7. On full promotion, Backstage reflects the new version

### Infrastructure Management

All cloud resources (S3 buckets, RDS, IoT Core) are provisioned as
Crossplane Claims, managed as code in Git, and synced by Argo CD.
Developers provision new fleets via Backstage Software Templates —
no direct cloud console access required.
```

**Step 3: Build and publish TechDocs**

```bash
npx @techdocs/cli build

npx @techdocs/cli publish \
  --publisher-type awsS3 \
  --storage-name iot-techdocs-bucket \
  --entity default/Component/telemetry-ingestion
```

**Step 4: Verify in the portal**

Navigate to **Catalog → telemetry-ingestion → Docs**. The full architecture page renders inside the Backstage portal.

> ✅ **Final Checkpoint:** All five tools work together. A single model training run in Argo Workflows drives a quality-gated canary deployment via Argo CD and Argo Rollouts, with infrastructure managed by Crossplane and full platform visibility in Backstage.

---

### Lab 5 — Review Questions

1. How does the Workflow → Argo CD → Argo Rollouts chain create a fully automated, quality-gated deployment pipeline?
2. What is the advantage of managing Crossplane Claims through Argo CD (GitOps) rather than applying them directly with `kubectl`?
3. How would you implement a rollback that also reverts the promoted ML model stored in S3?
4. What observability gaps remain when all five tools are integrated, and how would you close them?
5. How does the Backstage Software Template enforce organisational standards that raw Crossplane Claims do not?

---

## Summary Table

| Lab | Level | Tools | IoT Component | Duration |
|---|---|---|---|---|
| 1 | Beginner | Argo CD | MQTT Broker + Telemetry API | 60–90 min |
| 2 | Beginner–Intermediate | Argo Workflows | Sensor data processing DAG + CronWorkflow | 90–120 min |
| 3 | Intermediate | Argo Rollouts | Canary releases + blue-green firmware rollout | 90–120 min |
| 4 | Intermediate–Advanced | Backstage + Crossplane | Self-service IoT fleet provisioner portal | 2–3 hours |
| 5 | Advanced | All tools | End-to-end MLOps + GitOps deployment pipeline | 3–5 hours |

---

## Recommended Learning Path

1. Complete **Lab 1** first — GitOps fundamentals underpin everything else
2. Run **Lab 2** independently to build Workflow intuition before integrating tools
3. Complete **Lab 3** after Lab 1 — Rollouts extend the same Argo CD-managed manifests
4. Do **Lab 4** in parallel with Lab 3 if working as a team (one person on Backstage, one on Crossplane)
5. **Lab 5** is designed as a team capstone — assign each engineer a tool domain and integrate end-to-end
6. After all labs, explore **Argo Events** to trigger Workflows directly from MQTT messages arriving at the broker — the natural next evolution of this IoT architecture
