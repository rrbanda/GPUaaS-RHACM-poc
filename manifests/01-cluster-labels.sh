#!/bin/bash
# ==============================================================================
# Step 1: Label Managed Clusters
# ==============================================================================
# Labels GPU-capable clusters with the accelerator type so the RHACM Placement
# can select them for GPU workloads.
#
# Usage:
#   chmod +x 01-cluster-labels.sh
#   ./01-cluster-labels.sh
#
# The script will prompt you for cluster names and the accelerator label.
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo " Step 1: Label Managed Clusters with GPU Accelerator Type"
echo "============================================================"
echo ""

# Show available clusters
echo "Available managed clusters:"
echo "----------------------------"
oc get managedclusters -o custom-columns=NAME:.metadata.name,AVAILABLE:.status.conditions[-1:].status --no-headers 2>/dev/null || \
  { echo "ERROR: Cannot list managed clusters. Are you logged in to the hub?"; exit 1; }
echo ""

# Prompt for accelerator label value
read -rp "Enter accelerator label value [nvidia-tesla-t4]: " ACCELERATOR
ACCELERATOR="${ACCELERATOR:-nvidia-tesla-t4}"

# Prompt for cluster names
read -rp "Enter GPU cluster names to label (comma-separated, e.g. cluster2,cluster3): " CLUSTER_INPUT

if [[ -z "$CLUSTER_INPUT" ]]; then
  echo "ERROR: No cluster names provided. Exiting."
  exit 1
fi

# Split comma-separated input into array
IFS=',' read -ra CLUSTERS <<< "$CLUSTER_INPUT"

echo ""
echo "Will label the following clusters with accelerator=${ACCELERATOR}:"
for cluster in "${CLUSTERS[@]}"; do
  cluster=$(echo "$cluster" | xargs)  # trim whitespace
  echo "  - $cluster"
done
echo ""

read -rp "Proceed? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Applying labels ==="
for cluster in "${CLUSTERS[@]}"; do
  cluster=$(echo "$cluster" | xargs)
  echo "Labeling ${cluster} with accelerator=${ACCELERATOR}..."
  oc label managedcluster "$cluster" "accelerator=${ACCELERATOR}" --overwrite
done

echo ""
echo "=== Verification ==="
echo "Clusters with accelerator=${ACCELERATOR}:"
oc get managedclusters -l "accelerator=${ACCELERATOR}"

echo ""
echo "All managed clusters and their labels:"
oc get managedclusters --show-labels

echo ""
echo "=== Step 1 Complete ==="
echo "Only clusters with 'accelerator=${ACCELERATOR}' will be selected by the Placement."
