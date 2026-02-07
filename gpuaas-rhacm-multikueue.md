<!-- 
=============================================================================
  CONFLUENCE IMPORT INSTRUCTIONS
=============================================================================
  This document is formatted for easy import into Atlassian Confluence:

  Option 1 — Direct Paste:
    1. Open Confluence → Create a new page
    2. Click the "+" menu → "Markdown" (or use the /markdown slash command)
    3. Paste this entire document
    4. Upload all images from the images/ folder as attachments
    5. Update image paths from "images/filename.png" to the Confluence attachment format

  Option 2 — Markdown Import Macro:
    1. Install the "Markdown" macro from Atlassian Marketplace if not available
    2. Create a new page → Insert → Other Macros → Markdown
    3. Paste this document content

  Option 3 — Manual Copy:
    1. Copy each section individually into Confluence's rich text editor
    2. Tables, headings, bold, code blocks, and blockquotes will preserve formatting
    3. Upload images as attachments and insert them inline

  Image files are located in the images/ directory:
    images/01-what-why-how.png
    images/02-placement-flow-3step.png
    images/03-architecture-5step.png
    images/03b-architecture-use-case.png
    images/04-pain-points-single-cluster.png
    images/05-multi-queue.png
    images/06-multi-placement-setup.png
    images/07-starting-state.png
    images/08-addon-controllers.png
    images/09-placements-added.png
    images/10-queues-created.png
    images/11-full-architecture.png
    images/12-entry-point.png
=============================================================================
-->

# \<Customer Name\>

# GPU-as-a-Service with RHACM and MultiKueue

## Proof of Concept — Label-Based Multi-Cluster GPU Scheduling

**Prepared for:**
\<Customer Legal Name\>

**Date Delivered:** \<Date\>

**Version:** 1.0

---

## Table of Contents

- [1. PoC Objective](#1-poc-objective)
- [2. Business Context — The Challenge](#2-business-context--the-challenge)
- [3. Solution Overview](#3-solution-overview)
- [4. Scope of PoC](#4-scope-of-poc)
- [5. Success Criteria](#5-success-criteria)
- [6. Demo Environment](#6-demo-environment)
- [7. Architecture Deep Dive](#7-architecture-deep-dive)
- [8. Step-by-Step Execution Guide](#8-step-by-step-execution-guide)
- [9. Roles and Responsibilities](#9-roles-and-responsibilities)
- [10. Timeline](#10-timeline)
- [11. Assumptions and Prerequisites](#11-assumptions-and-prerequisites)
- [12. Future Extensions (Beyond This PoC)](#12-future-extensions-beyond-this-poc)
- [13. Reference Links](#13-reference-links)
- [14. Next Steps](#14-next-steps)
- [15. Confidentiality / Copyright / Account Team](#15-confidentiality--copyright--account-team)

---

## 1. PoC Objective

This Proof of Concept (PoC) demonstrates the capability of **Red Hat Advanced Cluster Management (RHACM)** combined with the **Red Hat Build of Kueue (RHBoK)** and its **MultiKueue** extension to deliver **GPU-as-a-Service** across a fleet of OpenShift clusters. The PoC validates that AI/ML workloads submitted to a single hub cluster are **automatically routed to the correct GPU-equipped clusters** using RHACM's Placement API and label-based cluster selection — without data scientists needing to know which clusters exist or how to configure them.

The core scenario demonstrated is **Label-Based Multi-Cluster GPU Scheduling**: managed clusters are labeled with their GPU hardware type (e.g., `accelerator=nvidia-tesla-t4`), and the system dynamically routes GPU jobs only to clusters that match the required hardware.

> **Note:** The Kueue Addon for RHACM premiered as **Developer Preview in RHACM 2.15**. Please review the [Scope of Support for Developer Preview](https://access.redhat.com/support/offerings/devpreview) and check with Red Hat for the most recent support offering before using in production.

---

## 2. Business Context — The Challenge

### The Growth of AI/ML Workloads

With the explosive growth of Large Language Models (LLMs) and generative AI, workload scale and complexity have exceeded the boundaries of a single cluster. Organizations are increasingly adopting multi-cluster, multi-cloud, and hybrid cloud architectures to access computing power, optimize costs, and meet compliance requirements.

### The Problem: Multi-Cluster GPU Management

Managing AI/ML workloads across multiple clusters presents significant challenges:

| Challenge | Description |
|-----------|-------------|
| **Hardware Heterogeneity** | Your fleet is not uniform. You have expensive clusters (NVIDIA H100s) for training and commodity clusters (CPUs/NVIDIA T4s) for inference. Sending a training job to a CPU cluster is a disaster. |
| **Resource Fragmentation** | 100 GPUs available across your fleet, but scattered as "2 free here, 3 free there." You can't run a distributed job that requires 8 contiguous GPUs. |
| **Low Utilization** | "Some clusters are very busy while others are idle," resulting in low overall GPU utilization across the fleet. |
| **Operational Complexity** | Manually configuring and managing batch job scheduling across an entire fleet is a constant headache. |

### Two Personas Feel the Pain

**Data Scientists** say:

> *"I have access to multiple OpenShift clusters, but each one only has a few GPUs available! I can't run my large training jobs!"*

> *"Which cluster is best for my training job? I don't want to hunt for GPUs."*

**Platform Administrators** say:

> *"Why is no one using these GPUs? Our cluster utilization is terrible."*

> *"How do I configure all these Kueues? I'm not a Kueue expert!"*

### Why Single-Cluster Kueue Is Insufficient

Kueue excels at scheduling batch workloads within a single cluster. However, in multi-cluster environments, it cannot:

- Route jobs across clusters based on hardware type
- Dynamically select the best cluster based on resource availability
- Provide a unified submission point for data scientists

**Result:** Fragmented workloads, under-utilized GPUs, and frustrated teams.

### Current State vs. Desired State

**The Limits of Single-Cluster Kueue:**

![The limits of single cluster Kueue](images/04-pain-points-single-cluster.png)

*Figure: Without MultiKueue, data scientists are left hunting for GPUs across fragmented clusters, while platform admins struggle with under-utilized resources.*

**The desired state — GPU-as-a-Service — is what this PoC delivers.**

---

## 3. Solution Overview

### The Three Core Components

The GPU-as-a-Service solution is built on three integrated components:

| Component | What It Is | What It Does |
|-----------|-----------|--------------|
| **Red Hat Build of Kueue (RHBoK)** | Kubernetes-native job scheduler for batch/AI/ML workloads | Provides job queueing, resource quotas, fair sharing, priority scheduling, and preemption |
| **MultiKueue** | A subproject of Kueue for multi-cluster job dispatch | Extends Kueue to dispatch jobs across multiple clusters from a single hub |
| **RHACM Kueue Addon** | An addon for Red Hat Advanced Cluster Management | Automates deployment of Kueue across clusters; provides the Placement-to-MultiKueue bridge |

### How They Work Together

1. **RHACM** manages the fleet — it knows all clusters, their labels, and capabilities
2. **Placement** defines which clusters should receive GPU workloads (by label, score, or CEL expression)
3. **The Kueue Addon** converts Placement decisions into MultiKueue configuration automatically
4. **MultiKueue** dispatches jobs to the selected clusters
5. **Kueue on each spoke** runs the jobs locally and syncs results back to the hub

**The Kueue Addon — 4 Steps to GPU-as-a-Service:**

![Kueue Addon 4 Steps](images/03-architecture-5step.png)

*Figure: (1) RHBoK is available via Operator Hub, (2) RHACM distributes and installs the RHBoK operator to managed clusters via an add-on, (3) The add-on automates deployment and configuration of MultiKueue, (4) The add-on installs two Admission Check Controllers.*

### What, Why, How

![What Why How](images/01-what-why-how.png)

*Figure: Kueue is a Kubernetes-native job scheduler (WHAT), it optimizes for batch/AI workloads with quotas, bursting, and multi-cluster support (WHY), and RHACM installs, configures, and integrates MultiKueue with Placement across clusters (HOW).*

### The Two AdmissionCheck Pattern

Every MultiKueue setup with RHACM requires **exactly two AdmissionChecks** on the hub ClusterQueue:

| AdmissionCheck | Controller | Purpose |
|----------------|------------|---------|
| `multikueue-config-demo2` | `open-cluster-management.io/placement` | **Bridge:** Watches the Placement and dynamically generates a `MultiKueueConfig` from the PlacementDecision results |
| `multikueue-demo2` | `kueue.x-k8s.io/multikueue` | **Dispatcher:** Reads the MultiKueueConfig and dispatches jobs to the listed clusters |

The OCM controller is the **bridge** between RHACM Placement and Kueue MultiKueue — it converts cluster selection decisions into job routing configuration, automatically and dynamically.

### Architecture Overview

**Placement Flow — 3 Steps:**

![Placement Flow](images/02-placement-flow-3step.png)

*Figure: (1) Admin creates Placement, (2) RHACM generates MultiKueueConfig from Placement decisions, (3) Jobs are dispatched to managed clusters via MultiKueue.*

**Detailed Architecture — Full Component View:**

![Full Architecture](images/11-full-architecture.png)

*Figure: Complete GPU-as-a-Service architecture showing RHACM Hub with Placements (GPU, CPU, GoldClass), Admission Check Controllers, LocalQueues/ClusterQueues, and managed clusters with different hardware types.*

**Multi-Placement Setup — Different Queues for Different Needs:**

![Multi-Placement Setup](images/06-multi-placement-setup.png)

*Figure: Multiple Placements route workloads to the right clusters — BluePlacement for standard GPU jobs, RedPlacement for priority jobs. The RHACM Admission Check Controller creates Kueue workload dispatching from each Placement.*

### Separation of Concerns

The power of this architecture is the **clear separation between administration and usage**:

| Persona | Needs to Know | Does NOT Need to Know |
|---------|---------------|----------------------|
| **Platform Admin** | How to create Placements, label clusters | How to write Kueue jobs |
| **Data Scientist** | Which LocalQueue to submit to (`user-queue`) | How Placement works, which clusters exist, MultiKueue configuration |

> **Key Insight:** Data scientists just submit to a queue. Everything else is handled automatically.

---

## 4. Scope of PoC

### In Scope

| Area | Details |
|------|---------|
| **Platform Setup** | RHACM hub cluster operational, Kueue Operator installed, Kueue Addon deployed |
| **Cluster Configuration** | Managed clusters labeled with accelerator type |
| **Placement & MultiKueue** | Label-based Placement created, MultiKueueConfig auto-generated |
| **Job Routing** | GPU job submitted to hub, dispatched to GPU clusters only |
| **Verification** | Full validation of resource status, job routing, dynamic behavior |
| **Cleanup** | All PoC resources can be removed cleanly |

### Out of Scope

| Area | Notes |
|------|-------|
| **AI platform integration** | Integration with data science platforms is not configured in this PoC |
| **Production workloads** | This PoC uses test images, not real AI training jobs |
| **Real GPU training** | Fake GPU resources may be used for demonstration |
| **Dynamic score-based scheduling** | Covered as a future extension (see [Section 12](#12-future-extensions-beyond-this-poc)) |
| **CEL-based bin-packing** | Covered as a future extension (see [Section 12](#12-future-extensions-beyond-this-poc)) |
| **Multi-team queue setup** | Multiple queues for different teams/tiers (see [Section 12](#12-future-extensions-beyond-this-poc)) |
| **Network/security hardening** | Production networking and security policies |

---

## 5. Success Criteria

The PoC will be deemed successful if all the following criteria are met:

### I. Platform Setup

- [ ] RHACM hub cluster is operational with managed clusters registered
- [ ] Kueue Operator is installed via OperatorHub on the hub cluster
- [ ] Kueue Addon (`multicluster-kueue-manager`) is deployed and enabled
- [ ] `MultiKueueCluster` resources show `CONNECTED=True` for managed clusters

### II. Cluster Configuration

- [ ] GPU-capable managed clusters are labeled with `accelerator=nvidia-tesla-t4`
- [ ] (Optional) Fake GPU resources are provisioned on managed cluster nodes for testing
- [ ] CPU-only clusters do **not** have the accelerator label

### III. Placement and MultiKueue

- [ ] `Placement` resource is created in `openshift-kueue-operator` namespace
- [ ] `PlacementDecision` lists **only** GPU-labeled clusters (e.g., cluster2, cluster3)
- [ ] `MultiKueueConfig` is **auto-generated** by the OCM controller with the correct cluster list
- [ ] Both `AdmissionChecks` show `status=True`, `reason=Active`
- [ ] `ClusterQueue` shows `status=True`, `reason=Ready`, `message="Can admit new workloads"`

### IV. Job Routing

- [ ] A GPU job is submitted to the hub cluster via `user-queue` LocalQueue
- [ ] The job is dispatched to **only** one of the GPU-labeled clusters
- [ ] The CPU-only cluster (cluster1) receives **no** workload
- [ ] Workload on the spoke cluster shows `Admitted=True`

### V. Dynamic Behavior

- [ ] Removing the `accelerator` label from a cluster **automatically** removes it from the `MultiKueueConfig`
- [ ] Adding the `accelerator` label to a new cluster **automatically** adds it to the `MultiKueueConfig`
- [ ] No manual `MultiKueueConfig` editing is required at any point

---

## 6. Demo Environment

### Cluster Topology

| Cluster | Role | Hardware | Labels | Kueue |
|---------|------|----------|--------|-------|
| **hub-cluster** | RHACM Hub + Kueue Manager | CPU | N/A | Kueue Operator + Addon installed |
| **cluster1** | Managed Spoke | CPU only | *(none)* | Kueue synced by Addon |
| **cluster2** | Managed Spoke | NVIDIA Tesla T4 × 3 | `accelerator=nvidia-tesla-t4` | Kueue synced by Addon |
| **cluster3** | Managed Spoke | NVIDIA Tesla T4 × 3 | `accelerator=nvidia-tesla-t4` | Kueue synced by Addon |

> **Note:** If you don't have physical GPUs, you can use the fake GPU setup described in [Step 2 of the Execution Guide](#step-2-optional-set-up-fake-gpu-resources).

### Component Versions

| Component | Version | Notes |
|-----------|---------|-------|
| **Red Hat Advanced Cluster Management** | 2.15+ | Developer Preview for Kueue Addon |
| **OpenShift Container Platform** | 4.18 – 4.21 | Hub and spoke clusters |
| **Red Hat Build of Kueue** | 1.2.x+ | Installed via OperatorHub |
| **Kueue Addon** | Developer Preview | Managed by RHACM |

### Network Requirements

- Managed clusters must be able to reach the RHACM hub (standard RHACM requirement)
- MultiKueue uses **cluster-proxy** — no direct hub-to-spoke network access required
- All communication goes through the RHACM managed cluster registration agent

---

## 7. Architecture Deep Dive

### Hub vs. Spoke Resources

The hub cluster and spoke clusters have **different** Kueue configurations. Understanding this distinction is critical.

#### Hub Cluster Resources (You Create These)

| Resource | Name | Purpose |
|----------|------|---------|
| `Placement` | `multikueue-config-demo2` | Selects clusters by label (`accelerator=nvidia-tesla-t4`) |
| `ResourceFlavor` | `default-flavor` | Defines the resource type for the ClusterQueue |
| `ClusterQueue` | `cluster-queue` | Hub queue with quotas + **two AdmissionChecks** |
| `LocalQueue` | `user-queue` | Namespace-scoped entry point where users submit jobs |
| `AdmissionCheck` | `multikueue-demo2` | MultiKueue controller — dispatches jobs |
| `AdmissionCheck` | `multikueue-config-demo2` | OCM Placement controller — generates MultiKueueConfig |

#### Hub Cluster Resources (Auto-Generated)

| Resource | Name | Generated By |
|----------|------|-------------|
| `PlacementDecision` | `multikueue-config-demo2-decision-1` | RHACM Placement controller |
| `MultiKueueConfig` | `multikueue-config-demo2` | OCM AdmissionCheck controller |
| `MultiKueueCluster` | `cluster1`, `cluster2`, `cluster3` | Kueue Addon |

#### Spoke Cluster Resources (Synced by Addon)

| Resource | Name | Key Difference |
|----------|------|---------------|
| `ClusterQueue` | `cluster-queue` | **NO admission checks** — spoke queues run jobs locally |
| `LocalQueue` | `user-queue` | Same name as hub for job routing to work |

> **Critical:** Hub ClusterQueue has `admissionChecks`. Spoke ClusterQueues must **NOT** have admission checks. The Kueue Addon handles this automatically.

### Data Flow: 5-Step Workflow

**Architecture Build-Up — How the Components Connect:**

The following diagrams show the progressive build-up of the GPU-as-a-Service architecture, from the starting state to the fully operational system.

**Step 1: Starting State — Hub cluster manages spoke clusters:**

![Starting State](images/07-starting-state.png)

**Step 2: Install the Kueue Addon — Addon deploys controllers to hub:**

![Addon Controllers](images/08-addon-controllers.png)

**Step 3: Create Placements — Define cluster selection criteria:**

![Placements Added](images/09-placements-added.png)

**Step 4: Queues Created — Admission Check Controller generates MultiKueue resources:**

![Queues Created](images/10-queues-created.png)

**Step 5: Data Scientists Submit Jobs — Workloads dispatched to the right clusters:**

![Full Architecture](images/11-full-architecture.png)

**Detailed 5-Step Workflow Summary:**

| Step | Action | Actor |
|------|--------|-------|
| 1 | Cluster Admin creates Placement defining which clusters receive GPU workloads (by label) | Platform Admin |
| 2 | OCM AdmissionCheck Controller evaluates PlacementDecision, generates MultiKueueConfig | Automated |
| 3 | Data Scientist submits job to `user-queue` on hub (with `suspend: true` and queue-name label) | Data Scientist |
| 4 | Kueue MultiKueue Controller reads MultiKueueConfig, dispatches job to a spoke cluster | Automated |
| 5 | Results sync back to hub — workload status updated, job completion visible from hub | Automated |

### What the Kueue Addon Automates

Without the addon, setting up MultiKueue requires manual configuration of:

| Manual Step | What the Addon Does Instead |
|-------------|---------------------------|
| Install Kueue on every spoke cluster | Addon deploys Kueue Operator to all managed clusters automatically |
| Create `kubeconfig` secrets for each spoke | Addon generates `MultiKueueCluster` resources with proper credentials |
| Create `ClusterQueue`/`LocalQueue` on each spoke | Addon syncs queue configuration to all managed clusters |
| Manage service accounts and RBAC | Addon handles all RBAC setup via cluster-proxy |
| Update config when clusters join/leave | Addon dynamically adapts to fleet changes |

---

## 8. Step-by-Step Execution Guide

This section walks through the PoC execution in order. Each step references a numbered manifest file in the [`poc/manifests/`](manifests/) directory.

### Prerequisites Check

Before starting, verify that your environment is ready:

```bash
# 1. Verify RHACM hub and managed clusters
oc get managedclusters

# 2. Verify Kueue Addon is installed
oc get clustermanagementaddon multicluster-kueue-manager

# 3. Verify MultiKueue cluster connectivity
oc get multikueuecluster -o wide
```

Expected output for `multikueuecluster`:

```
NAME             CONNECTED   AGE
cluster1         True        10m
cluster2         True        10m
cluster3         True        10m
local-cluster    False       10m
```

> **Note:** `local-cluster` showing `CONNECTED=False` is **expected**. MultiKueue does not support submitting jobs to the management cluster itself.

---

### Step 0: Clean Up Previous Resources

If you have run any previous Kueue scenarios, clean up those resources first. The ClusterQueue name `cluster-queue` is shared, so existing admission checks will conflict.

```bash
# Delete any running jobs
oc delete jobs -l kueue.x-k8s.io/queue-name=user-queue -n default

# Delete existing Kueue resources (if any)
oc delete clusterqueue cluster-queue 2>/dev/null
oc delete localqueue user-queue -n default 2>/dev/null
oc delete admissioncheck --all 2>/dev/null
oc delete resourceflavor default-flavor 2>/dev/null
oc delete placement -n openshift-kueue-operator --all 2>/dev/null

# Verify cleanup
oc get clusterqueue
oc get localqueue -A
oc get admissioncheck
```

All three commands should return `No resources found`.

---

### Step 1: Label Your Clusters

Label GPU-capable managed clusters with their accelerator type. This is how the Placement knows which clusters have GPUs.

**Manifest:** [`manifests/01-cluster-labels.sh`](manifests/01-cluster-labels.sh)

```bash
# Option A: Run the script
chmod +x manifests/01-cluster-labels.sh
./manifests/01-cluster-labels.sh

# Option B: Run manually
oc label managedcluster cluster2 accelerator=nvidia-tesla-t4 --overwrite
oc label managedcluster cluster3 accelerator=nvidia-tesla-t4 --overwrite
```

**Verify:**

```bash
oc get managedclusters -l accelerator=nvidia-tesla-t4
```

Expected output:

```
NAME       HUB ACCEPTED   MANAGED CLUSTER URLS                  JOINED   AVAILABLE   AGE
cluster2   true           https://cluster2-control-plane:6443   True     True        37m
cluster3   true           https://cluster3-control-plane:6443   True     True        37m
```

`cluster1` should **NOT** appear — it has no GPU label.

> **Tip:** If your managed clusters have real GPUs (e.g., NVIDIA L4, A100, H100), label them with the appropriate accelerator type and update the Placement to match. The pattern is identical.

---

### Step 2: (Optional) Set Up Fake GPU Resources

If your managed clusters do **not** have real GPUs, you can patch the node status to simulate GPU resources. This allows you to run the full PoC flow without physical GPUs.

```bash
# On cluster2: patch a node to advertise 3 fake GPUs
# Replace <node-name> with an actual node name from the cluster
oc patch node <node-name> --subresource=status --type='merge' --patch='{
  "status": {
    "capacity": {
      "nvidia.com/gpu": "3"
    },
    "allocatable": {
      "nvidia.com/gpu": "3"
    }
  }
}'
```

Repeat for cluster3.

**Verify** on each cluster:

```bash
kubectl get node -ojson --context <cluster2-context> | \
  jq '.items[] | .status.capacity, .status.allocatable' | grep gpu
```

Expected output:

```
"nvidia.com/gpu": "3",
"nvidia.com/gpu": "3",
```

> **Warning:** Fake GPU resources will reset when the node restarts. This is only for demonstration purposes.

---

### Step 3: Create the Placement

The Placement defines which clusters should receive GPU workloads. It is created in the Kueue Operator namespace (`openshift-kueue-operator`) on the hub cluster.

**Manifest:** [`manifests/02-gpu-placement.yaml`](manifests/02-gpu-placement.yaml)

```bash
oc apply -f manifests/02-gpu-placement.yaml
```

**Manifest contents — `02-gpu-placement.yaml`:**

```yaml
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: multikueue-config-demo2
  namespace: openshift-kueue-operator
spec:
  clusterSets:
  - global
  tolerations:
  - key: cluster.open-cluster-management.io/unreachable
    operator: Exists
  - key: cluster.open-cluster-management.io/unavailable
    operator: Exists
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchLabels:
            accelerator: nvidia-tesla-t4
```

**Key fields explained:**

| Field | Purpose |
|-------|---------|
| `namespace: openshift-kueue-operator` | Must be the Kueue operator namespace where the addon runs |
| `clusterSets: [global]` | Search across the `global` ManagedClusterSet (includes all clusters) |
| `tolerations` | Allow selecting clusters even if temporarily unreachable |
| `matchLabels: accelerator: nvidia-tesla-t4` | **Only** select clusters with this label |

**Verify the PlacementDecision:**

```bash
oc get placementdecision -n openshift-kueue-operator -ojson | \
  jq '.items[].status.decisions[].clusterName'
```

Expected output:

```
"cluster2"
"cluster3"
```

`cluster1` (CPU-only) is **excluded** because it lacks the `accelerator=nvidia-tesla-t4` label.

---

### Step 4: Apply the MultiKueue Setup

This creates the ResourceFlavor, ClusterQueue, LocalQueue, and both AdmissionChecks on the hub.

**Manifest:** [`manifests/03-kueue-resources.yaml`](manifests/03-kueue-resources.yaml)

```bash
oc apply -f manifests/03-kueue-resources.yaml
```

**Manifest contents — `03-kueue-resources.yaml`:**

```yaml
# ResourceFlavor
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "default-flavor"
---
# ClusterQueue — hub-level queue with quotas and two admission checks
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "cluster-queue"
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
    flavors:
    - name: "default-flavor"
      resources:
      - name: "cpu"
        nominalQuota: 9
      - name: "memory"
        nominalQuota: 36Gi
      - name: "nvidia.com/gpu"
        nominalQuota: 3
  admissionChecks:
  - multikueue-demo2
  - multikueue-config-demo2
---
# LocalQueue — namespace-level entry point for users
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: "default"
  name: "user-queue"
spec:
  clusterQueue: "cluster-queue"
---
# AdmissionCheck #1: Kueue MultiKueue Controller
apiVersion: kueue.x-k8s.io/v1beta1
kind: AdmissionCheck
metadata:
  name: multikueue-demo2
spec:
  controllerName: kueue.x-k8s.io/multikueue
  parameters:
    apiGroup: kueue.x-k8s.io
    kind: MultiKueueConfig
    name: multikueue-config-demo2
---
# AdmissionCheck #2: OCM Placement Controller
apiVersion: kueue.x-k8s.io/v1beta1
kind: AdmissionCheck
metadata:
  name: multikueue-config-demo2
spec:
  controllerName: open-cluster-management.io/placement
  parameters:
    apiGroup: cluster.open-cluster-management.io
    kind: Placement
    name: multikueue-config-demo2
```

> **Important:** The `ClusterQueue` and `LocalQueue` names (`cluster-queue`, `user-queue`) **must match** what the Kueue Addon syncs to spoke clusters. Using different names will cause jobs to fail on spokes with: `LocalQueue user-queue doesn't exist`.

---

### Step 5: Verify All Resources Are Active

This is the most important step. All resources must show healthy status before submitting jobs.

**Script:** [`manifests/05-verify.sh`](manifests/05-verify.sh)

```bash
chmod +x manifests/05-verify.sh
./manifests/05-verify.sh
```

Or verify manually:

#### 5a. Verify the MultiKueueConfig

The OCM controller should have dynamically generated a `MultiKueueConfig` listing only the GPU clusters:

```bash
oc get multikueueconfig multikueue-config-demo2 -ojson | \
  jq '.metadata.name, .spec.clusters'
```

Expected output:

```json
"multikueue-config-demo2"
[
  "cluster2",
  "cluster3"
]
```

Only clusters with `accelerator=nvidia-tesla-t4` appear. `cluster1` is absent.

#### 5b. Verify the AdmissionChecks

Both admission checks must show `Active`:

```bash
oc get admissionchecks multikueue-config-demo2 multikueue-demo2 -ojson | \
  jq '.items[] | .metadata.name, .status.conditions'
```

Expected output:

```json
"multikueue-config-demo2"
[
  {
    "lastTransitionTime": "...",
    "message": "MultiKueueConfig multikueue-config-demo2 is generated successfully",
    "reason": "Active",
    "status": "True",
    "type": "Active"
  }
]
"multikueue-demo2"
[
  {
    "lastTransitionTime": "...",
    "message": "The admission check is active",
    "observedGeneration": 1,
    "reason": "Active",
    "status": "True",
    "type": "Active"
  }
]
```

#### 5c. Verify the ClusterQueue

The ClusterQueue must be `Ready` and able to admit workloads:

```bash
oc get clusterqueues -ojson | jq '.items[] | .metadata.name, .status.conditions'
```

Expected output:

```json
"cluster-queue"
[
  {
    "lastTransitionTime": "...",
    "message": "Can admit new workloads",
    "observedGeneration": 1,
    "reason": "Ready",
    "status": "True",
    "type": "Active"
  }
]
```

**If ClusterQueue shows `Active=False`**, check:

1. Both AdmissionChecks are `Active`
2. MultiKueueConfig has at least one cluster listed
3. MultiKueueClusters show `CONNECTED=True`:
   ```bash
   oc get multikueuecluster -o wide
   ```
4. Kueue controller logs for errors:
   ```bash
   oc logs deployment/kueue-controller-manager -n openshift-kueue-operator --tail=50
   ```

---

### Step 6: Submit a GPU Job

Deploy a job that requests GPU resources. It will be routed through MultiKueue to one of the GPU clusters.

**Manifest:** [`manifests/04-sample-gpu-job.yaml`](manifests/04-sample-gpu-job.yaml)

```bash
oc create -f manifests/04-sample-gpu-job.yaml
```

> **Note:** Use `oc create` (not `oc apply`) because the manifest uses `generateName` to create a unique job name each time.

**Manifest contents — `04-sample-gpu-job.yaml`:**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: demo2-job
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: "user-queue"
spec:
  parallelism: 1
  completions: 1
  suspend: true
  template:
    spec:
      containers:
      - name: gpu-worker
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["600s"]
        resources:
          requests:
            cpu: "1"
            memory: "200Mi"
            nvidia.com/gpu: "1"
          limits:
            cpu: "1"
            memory: "200Mi"
            nvidia.com/gpu: "1"
      restartPolicy: Never
```

**Key points:**

| Field | Purpose |
|-------|---------|
| `suspend: true` | **Required.** Kueue manages the lifecycle; it unsuspends when resources are available |
| `kueue.x-k8s.io/queue-name: user-queue` | Routes the job to the `user-queue` LocalQueue |
| `nvidia.com/gpu: "1"` | Requests one GPU — ensures the job can only run on GPU-equipped clusters |
| `generateName: demo2-job` | Creates a unique name each time (use `oc create`) |
| `args: ["600s"]` | Sleeps for 10 minutes so you have time to observe the workload |

---

### Step 7: Verify Job Routing

#### 7a. Check the Workload on the Hub

```bash
oc get workload -n default
```

Expected output:

```
NAME                       QUEUE        RESERVED IN     ADMITTED   FINISHED   AGE
demo2-job<id>-<hash>       user-queue   cluster-queue   True                  10s
```

The workload should show `ADMITTED=True`.

#### 7b. Verify Which Cluster Received the Job

The hub's MultiKueue dispatches the job to one of the GPU clusters:

```bash
# Check cluster2
kubectl get workload --context <cluster2-context>

# Check cluster3
kubectl get workload --context <cluster3-context>
```

**Only one** of the GPU clusters should have the workload:

```
NAME                       QUEUE        RESERVED IN     ADMITTED   FINISHED   AGE
demo2-job<id>-<hash>       user-queue   cluster-queue   True                  5m
```

The other GPU cluster should show `No resources found in default namespace.`

#### 7c. Confirm cluster1 (CPU) Did NOT Receive the Job

```bash
kubectl get workload --context <cluster1-context>
```

Expected output:

```
No resources found in default namespace.
```

**This confirms the label-based Placement is working:** only clusters with `accelerator=nvidia-tesla-t4` receive GPU jobs.

---

### Step 8: (Optional) Demonstrate Dynamic Behavior

The power of this setup is that the `MultiKueueConfig` is **dynamically generated** from the Placement. Changes to cluster labels automatically update the routing configuration.

```bash
# Remove GPU label from cluster3
oc label managedcluster cluster3 accelerator-

# Wait a moment, then check — only cluster2 should remain
oc get multikueueconfig multikueue-config-demo2 -ojson | jq '.spec.clusters'
```

Expected output:

```json
["cluster2"]
```

```bash
# Add the label back
oc label managedcluster cluster3 accelerator=nvidia-tesla-t4 --overwrite

# Check again — cluster3 is automatically re-added
oc get multikueueconfig multikueue-config-demo2 -ojson | jq '.spec.clusters'
```

Expected output:

```json
["cluster2", "cluster3"]
```

**No manual MultiKueueConfig editing required.** This is the key advantage over hardcoded configurations.

---

### Step 9: Cleanup

Remove all PoC resources when you are done.

**Script:** [`manifests/06-cleanup.sh`](manifests/06-cleanup.sh)

```bash
chmod +x manifests/06-cleanup.sh
./manifests/06-cleanup.sh
```

Or clean up manually:

```bash
# Delete running jobs
oc delete jobs -l kueue.x-k8s.io/queue-name=user-queue -n default

# Delete Kueue resources
oc delete -f manifests/03-kueue-resources.yaml

# Delete Placement
oc delete -f manifests/02-gpu-placement.yaml

# (Optional) Remove GPU labels
oc label managedcluster cluster2 accelerator-
oc label managedcluster cluster3 accelerator-

# Verify cleanup
oc get clusterqueue,localqueue,admissioncheck,multikueueconfig,placement -A
```

---

## 9. Roles and Responsibilities

| Role | Organization | Responsibilities |
|------|-------------|-----------------|
| **Project Sponsor** | \<Customer\> | Executive oversight, approval of PoC scope and results |
| **Platform Team** | \<Customer\> | Provide cluster access, networking, infrastructure support |
| **Subject Matter Experts** | \<Customer\> | Participate in review, provide feedback, validate results |
| **Red Hat Team** | Red Hat | Solution design, guidance, architecture review, execution, configuration, troubleshooting, documentation |
| **Support Team** | Red Hat | Assistance with product issues during PoC |

---

## 10. Timeline

The estimated timeline for this PoC is **1–2 weeks**, with key milestones:

| Phase | Duration | Activities |
|-------|----------|------------|
| **Week 1: Setup** | 3–5 days | Environment validation, RHACM verification, Kueue Operator install, Kueue Addon deployment, cluster labeling |
| **Week 2: Execution** | 3–5 days | Placement configuration, MultiKueue setup, job submission, verification, dynamic behavior demo, documentation of results |

| Milestone | Target | Owner |
|-----------|--------|-------|
| Kick-off meeting | Day 1 | Joint |
| Environment ready | Day 3 | \<Customer\> |
| Platform setup complete | Day 5 | Red Hat |
| Scenario execution complete | Day 8 | Red Hat |
| Results review & sign-off | Day 10 | Joint |

---

## 11. Assumptions and Prerequisites

| # | Assumption |
|---|-----------|
| 1 | RHACM **2.15+** hub cluster is operational with at least **2 managed clusters** |
| 2 | Managed clusters are part of a `ManagedClusterSet` (the `global` set is sufficient) |
| 3 | At least 1 managed cluster has GPUs (or fake GPUs can be provisioned for demo) |
| 4 | At least 1 managed cluster is CPU-only (to demonstrate exclusion from GPU routing) |
| 5 | Kueue Operator is available in OperatorHub on the hub cluster |
| 6 | `oc` CLI access with `cluster-admin` privileges on the hub cluster |
| 7 | `kubectl` context configured for each managed cluster (for verification) |
| 8 | Network connectivity between hub and managed clusters (standard RHACM requirement) |
| 9 | Collaboration and timely feedback from the client team |

---

## 12. Future Extensions (Beyond This PoC)

This PoC demonstrates **label-based** cluster selection — the foundational capability. The platform supports progressively more sophisticated scheduling:

### Extension 1: Dynamic Score-Based Scheduling

**Problem:** Multiple GPU clusters exist, but some are heavily utilized while others are idle. You want to route jobs to the cluster with the **most available GPUs**.

**Solution:** Deploy the [resource-usage-collect-addon](https://github.com/open-cluster-management-io/addon-contrib/tree/main/resource-usage-collect-addon) to report GPU availability scores via `AddonPlacementScore`. Update the Placement with `prioritizerPolicy` to select clusters by score:

```yaml
spec:
  numberOfClusters: 1
  prioritizerPolicy:
    mode: Exact
    configurations:
      - scoreCoordinate:
          type: AddOn
          addOn:
            resourceName: resource-usage-score
            scoreName: gpuClusterAvailable
        weight: 1
```

This ensures workloads always go to the cluster with the most available GPUs.

Reference: [OCM Scenario 3: Dynamic Score-Based MultiKueue Setup](https://github.com/open-cluster-management-io/ocm/tree/main/solutions/kueue-admission-check#scenario-3-dynamic-score-based-multikueue-setup)

### Extension 2: CEL-Based Bin-Packing

**Problem:** 100 GPUs available across the fleet, but fragmented. A job needing 8 GPUs can't run because no single cluster has 8 free.

**Solution:** Use Common Expression Language (CEL) in the Placement to filter clusters that can **fully accommodate** the workload's requirements, with reverse sorting to pack into the most-utilized cluster first:

```yaml
spec:
  predicates:
    - requiredClusterSelector:
        celSelector:
          celExpressions:
            - managedCluster.scores("resource-usage-score").filter(s, s.name == 'gpuClusterAvailable').all(e, e.value > 0)
  numberOfClusters: 1
  prioritizerPolicy:
    mode: Exact
    configurations:
      - scoreCoordinate:
          type: AddOn
          addOn:
            resourceName: resource-usage-score
            scoreName: gpuClusterAvailable
        weight: -1  # Negative weight = reverse sort (bin-packing)
```

### Extension 3: Multi-Team Queue Setup

**Problem:** Different teams need different GPU tiers (standard vs. premium) with separate quotas and chargeback.

**Solution:** Create multiple `LocalQueue` / `ClusterQueue` / `Placement` combinations:

| LocalQueue | Placement | Target Clusters | Users |
|------------|-----------|-----------------|-------|
| `gpu-queue` | GPUPlacement | Clusters with `accelerator=nvidia-*` | ML training |
| `cpu-queue` | CPUPlacement | Clusters with `cluster-type=cpu-only` | ETL, preprocessing |
| `gold-gpu-queue` | GoldGPUPlacement | Premium A100/H100 clusters | Critical/priority jobs |

### Extension 4: AI Platform Integration

**Problem:** Data scientists want to use their familiar tools (Jupyter, pipelines) rather than raw `oc create` commands.

**Solution:** AI platforms that include Kueue for single-cluster scheduling can be extended with RHACM + MultiKueue, so that jobs submitted from notebooks or pipelines are transparently routed to the best cluster across the fleet.

![Entry Point](images/12-entry-point.png)

*Figure: With an AI platform as the consumer, additional capabilities become available: self-service automation, self-service Kueue creation, observability integration, persona/RBAC integration, and GitOps.*

---

## 13. Reference Links

| Resource | URL |
|----------|-----|
| **Red Hat Build of Kueue (OCP 4.21)** | [https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/ai_workloads/red-hat-build-of-kueue](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/ai_workloads/red-hat-build-of-kueue) |
| **RHACM Documentation** | [https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes) |
| **OCM Kueue Integration Solution** | [https://github.com/open-cluster-management-io/ocm/tree/main/solutions/kueue-admission-check](https://github.com/open-cluster-management-io/ocm/tree/main/solutions/kueue-admission-check) |
| **Kueue Addon Repository** | [https://github.com/open-cluster-management-io/addon-contrib/tree/main/kueue-addon](https://github.com/open-cluster-management-io/addon-contrib/tree/main/kueue-addon) |
| **MultiKueue Upstream Documentation** | [https://kueue.sigs.k8s.io/docs/concepts/multikueue/](https://kueue.sigs.k8s.io/docs/concepts/multikueue/) |
| **OCM Placement Documentation** | [https://open-cluster-management.io/docs/concepts/placement/](https://open-cluster-management.io/docs/concepts/placement/) |
| **Extending Managed Clusters with Custom Attributes** | [https://open-cluster-management.io/docs/scenarios/extending-managed-clusters/](https://open-cluster-management.io/docs/scenarios/extending-managed-clusters/) |
| **Extend Multicluster Scheduling Capabilities** | [https://open-cluster-management.io/docs/scenarios/extend-multicluster-scheduling-capabilities/](https://open-cluster-management.io/docs/scenarios/extend-multicluster-scheduling-capabilities/) |
| **Resource Usage Collect Addon** | [https://github.com/open-cluster-management-io/addon-contrib/tree/main/resource-usage-collect-addon](https://github.com/open-cluster-management-io/addon-contrib/tree/main/resource-usage-collect-addon) |
| **Developer Preview Scope of Support** | [https://access.redhat.com/support/offerings/devpreview](https://access.redhat.com/support/offerings/devpreview) |
| **Open Cluster Management** | [https://open-cluster-management.io/](https://open-cluster-management.io/) |

---

## 14. Next Steps

1. **Kick-off meeting** to finalize PoC scope, confirm cluster access, and define specific test configurations
2. **Environment setup** — verify RHACM hub, managed clusters, and Kueue Operator availability
3. **Execute PoC** following the [Step-by-Step Execution Guide](#8-step-by-step-execution-guide)
4. **Document results** — capture screenshots, command output, and any issues encountered
5. **Review session** — present findings, discuss success criteria validation, and plan next phase
6. **Plan extensions** — evaluate [Dynamic Score-Based Scheduling](#extension-1-dynamic-score-based-scheduling) and [Multi-Team Queue Setup](#extension-3-multi-team-queue-setup) as follow-on phases

---

## 15. Confidentiality / Copyright / Account Team

### Confidentiality Clause

The information presented in this document is exclusively confidential to Red Hat, Inc. It has been made available to \<Customer Legal Name\> for consideration and review of Red Hat's subscription and service offerings. In no event shall all or any part of this document be disclosed or disseminated without the express written permission of Red Hat, Inc. The holder of this document may not utilize Red Hat's name in any correspondence to any party concerning this document or anything about this document without the express consent of Red Hat, Inc.

### Copyright and Disclaimer

Copyright 2025 by Red Hat, Inc. of Raleigh, NC. All rights reserved. No part of the work covered by the copyright herein may be reproduced or used in any form or by any means — graphic, electronic, or mechanical, including photocopying, recording, taping, or information storage and retrieval systems — without permission in writing from Red Hat, Inc.

This document is not a quote and does not include any binding commitments by Red Hat.

### Red Hat Account Team

| Role | Name | Title | Email | Phone |
|------|------|-------|-------|-------|
| **Account Leader** | \<Account Leader Name\> | Account Executive | first.last@redhat.com | +1 (555) 555-5555 |
| **Account Key Contributor** | \<Account Key Contributor Name\> | Solution Architect | first.last@redhat.com | +1 (555) 555-5555 |
| **Red Hat Lead** | \<Name\> | \<Title\> | first.last@redhat.com | +1 (555) 555-5555 |
| **Red Hat Contributor** | \<Name\> | \<Title\> | first.last@redhat.com | +1 (555) 555-5555 |
