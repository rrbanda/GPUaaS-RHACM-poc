#!/bin/bash
# ==============================================================================
# Step 6: Cleanup All Resources
# ==============================================================================
# Removes all resources created during setup.
# Run this when you are done testing or before re-running.
#
# Usage:
#   chmod +x 06-cleanup.sh
#   ./06-cleanup.sh
#
# The script will prompt for cluster names and resource names to clean up.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " GPU-as-a-Service — Cleanup"
echo "============================================================"
echo ""

# Show current state
echo "Current managed clusters:"
oc get managedclusters -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels --no-headers 2>/dev/null || true
echo ""

# Prompt for values
read -rp "Enter cluster names to remove accelerator label from (comma-separated, e.g. cluster2,cluster3): " CLUSTER_INPUT
read -rp "Job namespace [default]: " JOB_NS
JOB_NS="${JOB_NS:-default}"

read -rp "Queue name label for jobs [user-queue]: " QUEUE_NAME
QUEUE_NAME="${QUEUE_NAME:-user-queue}"

echo ""
echo "This will delete:"
echo "  - All jobs with queue-name=${QUEUE_NAME} in namespace ${JOB_NS}"
echo "  - Kueue resources from 03-kueue-resources.yaml"
echo "  - Placement from 02-gpu-placement.yaml"
if [[ -n "$CLUSTER_INPUT" ]]; then
  echo "  - Accelerator labels from: ${CLUSTER_INPUT}"
fi
echo ""

read -rp "Proceed with cleanup? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Deleting running jobs ==="
oc delete jobs -l "kueue.x-k8s.io/queue-name=${QUEUE_NAME}" -n "${JOB_NS}" 2>/dev/null || \
  echo "  No jobs found to delete."

echo ""
echo "=== Deleting Kueue resources ==="
oc delete -f "${SCRIPT_DIR}/03-kueue-resources.yaml" 2>/dev/null || \
  echo "  Kueue resources already deleted or not found."

echo ""
echo "=== Deleting Placement ==="
oc delete -f "${SCRIPT_DIR}/02-gpu-placement.yaml" 2>/dev/null || \
  echo "  Placement already deleted or not found."

if [[ -n "$CLUSTER_INPUT" ]]; then
  echo ""
  echo "=== Removing accelerator labels ==="
  IFS=',' read -ra CLUSTERS <<< "$CLUSTER_INPUT"
  for cluster in "${CLUSTERS[@]}"; do
    cluster=$(echo "$cluster" | xargs)
    oc label managedcluster "$cluster" accelerator- 2>/dev/null || \
      echo "  Label already removed from ${cluster}."
  done
fi

echo ""
echo "=== Verifying cleanup ==="
echo "Remaining Kueue resources (should be empty):"
oc get clusterqueue,localqueue,admissioncheck,multikueueconfig,placement -A 2>/dev/null || true

echo ""
echo "============================================================"
echo " Cleanup Complete"
echo "============================================================"
