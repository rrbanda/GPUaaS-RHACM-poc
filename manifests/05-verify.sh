#!/bin/bash
# ==============================================================================
# Step 5: Verify All Resources Are Active
# ==============================================================================
# Checks the status of every resource in the MultiKueue pipeline.
# All resources must show healthy status before submitting jobs.
#
# Usage:
#   chmod +x 05-verify.sh
#   ./05-verify.sh
#
# The script will prompt for resource names used during setup.
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo " GPU-as-a-Service — Verification"
echo "============================================================"
echo ""

# Prompt for configurable values
read -rp "Accelerator label value [nvidia-tesla-t4]: " ACCELERATOR
ACCELERATOR="${ACCELERATOR:-nvidia-tesla-t4}"

read -rp "MultiKueueConfig name [multikueue-config-demo2]: " MK_CONFIG
MK_CONFIG="${MK_CONFIG:-multikueue-config-demo2}"

read -rp "MultiKueue AdmissionCheck name [multikueue-demo2]: " MK_AC
MK_AC="${MK_AC:-multikueue-demo2}"

read -rp "Kueue namespace [openshift-kueue-operator]: " KUEUE_NS
KUEUE_NS="${KUEUE_NS:-openshift-kueue-operator}"

read -rp "Job namespace [default]: " JOB_NS
JOB_NS="${JOB_NS:-default}"

echo ""
echo "============================================================"
echo " Running checks..."
echo "============================================================"

echo ""
echo "=== 1. Managed Clusters ==="
oc get managedclusters

echo ""
echo "=== 2. Clusters with GPU Label (accelerator=${ACCELERATOR}) ==="
oc get managedclusters -l "accelerator=${ACCELERATOR}" 2>/dev/null || \
  echo "  No clusters found with label accelerator=${ACCELERATOR}"

echo ""
echo "=== 3. PlacementDecision ==="
echo "Selected clusters (should list only GPU clusters):"
oc get placementdecision -n "${KUEUE_NS}" -ojson 2>/dev/null | \
  jq '.items[].status.decisions[].clusterName' 2>/dev/null || \
  echo "  No PlacementDecision found. Ensure Placement was applied."

echo ""
echo "=== 4. MultiKueueConfig (${MK_CONFIG}) ==="
echo "Clusters in MultiKueueConfig (auto-generated from Placement):"
oc get multikueueconfig "${MK_CONFIG}" -ojson 2>/dev/null | \
  jq '.metadata.name, .spec.clusters' 2>/dev/null || \
  echo "  MultiKueueConfig '${MK_CONFIG}' not found. Wait for the OCM controller to generate it."

echo ""
echo "=== 5. MultiKueueClusters ==="
oc get multikueuecluster -o wide 2>/dev/null || \
  echo "  No MultiKueueClusters found."

echo ""
echo "=== 6. AdmissionChecks (${MK_CONFIG}, ${MK_AC}) ==="
oc get admissionchecks "${MK_CONFIG}" "${MK_AC}" -ojson 2>/dev/null | \
  jq '.items[] | .metadata.name, .status.conditions' 2>/dev/null || \
  echo "  AdmissionChecks not found. Ensure kueue-resources.yaml was applied."

echo ""
echo "=== 7. ClusterQueue ==="
oc get clusterqueues -ojson 2>/dev/null | \
  jq '.items[] | .metadata.name, .status.conditions' 2>/dev/null || \
  echo "  No ClusterQueues found."

echo ""
echo "=== 8. LocalQueue ==="
oc get localqueue -A 2>/dev/null || \
  echo "  No LocalQueues found."

echo ""
echo "=== 9. Workloads (if any jobs submitted) ==="
oc get workload -n "${JOB_NS}" 2>/dev/null || \
  echo "  No workloads found in namespace ${JOB_NS}."

echo ""
echo "============================================================"
echo " Verification Complete"
echo "============================================================"
echo ""
echo "Expected results:"
echo "  - PlacementDecision lists only clusters with accelerator=${ACCELERATOR}"
echo "  - MultiKueueConfig '${MK_CONFIG}' contains only GPU-labeled clusters"
echo "  - Both AdmissionChecks show status=True, reason=Active"
echo "  - ClusterQueue shows status=True, reason=Ready"
echo ""
