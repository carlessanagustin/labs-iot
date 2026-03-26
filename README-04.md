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
