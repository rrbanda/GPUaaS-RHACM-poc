# GPU-as-a-Service with RHACM and MultiKueue — Proof of Concept

This repository contains a **Proof of Concept (PoC)** for delivering GPU-as-a-Service across multiple OpenShift clusters using **Red Hat Advanced Cluster Management (RHACM)** and the **Red Hat Build of Kueue (RHBoK)** with **MultiKueue**.

## What This PoC Demonstrates

- **Label-Based Multi-Cluster GPU Scheduling** — managed clusters are labeled with their GPU hardware type (e.g., `accelerator=nvidia-tesla-t4`), and the system dynamically routes GPU jobs only to clusters that match
- **Declarative, Dynamic Cluster Selection** — no hardcoded target clusters; the system automatically adapts when labels change
- **Separation of Concerns** — data scientists submit to a queue; platform admins manage Placements

## Repository Structure

```
├── gpuaas-rhacm-multikueue.md      # Main document (Red Hat delivery template)
├── manifests/
│   ├── 01-cluster-labels.sh      # Step 1: Label managed clusters
│   ├── 02-gpu-placement.yaml     # Step 2: RHACM Placement resource
│   ├── 03-kueue-resources.yaml   # Step 3: Kueue resources (ClusterQueue, LocalQueue, AdmissionChecks)
│   ├── 04-sample-gpu-job.yaml    # Step 4: Sample GPU job
│   ├── 05-verify.sh              # Step 5: Verification script
│   └── 06-cleanup.sh             # Step 6: Cleanup script
├── images/                       # Architecture diagrams (screenshots from presentation decks)
│   ├── 01-what-why-how.png
│   ├── 02-placement-flow-3step.png
│   ├── 03-architecture-5step.png
│   ├── ...                       # 13 total architecture diagrams
│   └── 12-entry-point.png
├── LICENSE
└── README.md
```


## Quick Start

1. Read the full PoC document: [`gpuaas-rhacm-multikueue.md`](gpuaas-rhacm-multikueue.md)
2. Follow the **Step-by-Step Execution Guide** (Section 8)
3. Execute the numbered manifests in order from the `manifests/` directory

## Prerequisites

- RHACM 2.15+ hub cluster with Kueue Addon installed
- At least 2 managed clusters (1 GPU-capable, 1 CPU-only)
- `oc` CLI with cluster-admin access

## Key Technologies

| Component | Purpose |
|-----------|---------|
| [Red Hat Advanced Cluster Management](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes) | Multi-cluster management and Placement API |
| [Red Hat Build of Kueue](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/ai_workloads/red-hat-build-of-kueue) | Kubernetes-native job scheduler for AI/ML workloads |
| [MultiKueue](https://kueue.sigs.k8s.io/docs/concepts/multikueue/) | Multi-cluster job dispatch |
| [Kueue Addon](https://github.com/open-cluster-management-io/addon-contrib/tree/main/kueue-addon) | Automates MultiKueue setup via RHACM |

## References

- [OCM Kueue Integration Solution](https://github.com/open-cluster-management-io/ocm/tree/main/solutions/kueue-admission-check)
- [Open Cluster Management](https://open-cluster-management.io/)
- [Developer Preview Scope of Support](https://access.redhat.com/support/offerings/devpreview)

## License

Apache-2.0
