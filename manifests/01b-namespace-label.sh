#!/bin/bash
# ==============================================================================
# Step 3: Label the Job Namespace for Kueue Management
# ==============================================================================
# Labels the namespace where jobs will be submitted so that Red Hat Build of
# Kueue manages workloads in that namespace.
#
# This is required per the Red Hat Build of Kueue documentation:
# https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/ai_workloads/red-hat-build-of-kueue
#
# Without this label, jobs in the namespace will not be subject to Kueue's
# admission control and quota management.
#
# Usage:
#   chmod +x 01b-namespace-label.sh
#   ./01b-namespace-label.sh
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo " Step 3: Label Job Namespace for Kueue Management"
echo "============================================================"
echo ""

# Prompt for namespace
read -rp "Enter the namespace where jobs will be submitted [default]: " NAMESPACE
NAMESPACE="${NAMESPACE:-default}"

echo ""
echo "Will label namespace '${NAMESPACE}' with kueue.openshift.io/managed=true"
echo ""

read -rp "Proceed? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Applying namespace label ==="
oc label namespace "${NAMESPACE}" kueue.openshift.io/managed=true --overwrite

echo ""
echo "=== Verification ==="
echo "Namespace labels:"
oc get namespace "${NAMESPACE}" --show-labels

echo ""
echo "=== Step 3 Complete ==="
echo "Namespace '${NAMESPACE}' is now managed by Red Hat Build of Kueue."
echo "Jobs submitted in this namespace will be subject to Kueue admission control."
