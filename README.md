# IoT Platform — Practice Labs

## Table of Contents

- [IoT Platform — Practice Labs](#iot-platform--practice-labs)
  - [Table of Contents](#table-of-contents)
  - [Architecture Overview](#architecture-overview)
  - [Prerequisites (All Labs)](#prerequisites-all-labs)
  - [Summary Table](#summary-table)
  - [Recommended Learning Path](#recommended-learning-path)
  - [Lab 1 — Beginner: GitOps Deployment of the IoT Telemetry Stack with Argo CD](README-01.md#lab-1--beginner-gitops-deployment-of-the-iot-telemetry-stack-with-argo-cd)
  - [Lab 2 — Beginner–Intermediate: IoT Telemetry Data Pipeline with Argo Workflows](README-02.md#lab-2--beginnerintermediate-iot-telemetry-data-pipeline-with-argo-workflows)
  - [Lab 3 — Intermediate: Safe IoT Service Rollouts with Argo Rollouts](README-03.md#lab-3--intermediate-safe-iot-service-rollouts-with-argo-rollouts)
  - [Lab 4 — Intermediate–Advanced: IoT Developer Portal with Backstage and Crossplane](README-04.md#lab-4--intermediateadvanced-iot-developer-portal-with-backstage-and-crossplane)
  - [Lab 5 — Advanced: Full IoT GitOps Platform — Argo Workflows + CD + Rollouts + Backstage + Crossplane](README-05.md#lab-5--advanced-full-iot-gitops-platform--argo-workflows--cd--rollouts--backstage--crossplane)

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
