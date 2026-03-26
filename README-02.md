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
# https://github.com/argoproj/argo-workflows/releases
export ARGO_WORKFLOWS_VERSION="v4.0.3"
kubectl apply --server-side -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/quick-start-minimal.yaml"
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

* Advanced

```bash
export ARGO_SERVER='127.0.0.1:2746'
export ARGO_HTTP=false
export ARGO_HTTP1=true
export ARGO_SECURE=true
export ARGO_BASE_HREF=
export ARGO_TOKEN=''
export ARGO_NAMESPACE=argo ;# or whatever your namespace is
#export KUBECONFIG=/dev/null ;# recommended
argo list
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
