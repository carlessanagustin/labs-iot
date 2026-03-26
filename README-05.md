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
