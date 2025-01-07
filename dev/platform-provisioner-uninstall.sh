#!/bin/bash

#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

#######################################
# platform-provisioner-uninstall.sh: this will uninstall all supporting components for Platform Provisioner
# Globals:
#   PIPELINE_NAMESPACE: the namespace to deploy the pipeline and provisioner GUI
# Arguments:
#   None
# Returns:
#   0 if thing was deleted, non-zero on error
#######################################

export PIPELINE_NAMESPACE=${PIPELINE_NAMESPACE:-"tekton-tasks"}

function k8s-waitfor-deletion() {
  _resource_type=$1
  _resource_name=$2
  _namespace=$3
  _timeout=$4
  echo "waiting for ${_resource_type}/${_resource_name} in namespace: ${_namespace} to be deleted..."
  kubectl wait --for=delete -n "${_namespace}" "${_resource_type}/${_resource_name}" --timeout="${_timeout}"
  if [ $? -ne 0 ]; then
    echo "Timeout: ${_resource_type} '${_resource_name}' was not deleted within ${_timeout}."
    return 1
  else
    echo "${_resource_type} '${_resource_name}' is now deleted."
  fi
}

function helm_uninstall_if_exists() {
  release_name=$1
  namespace=$2
  if helm status -n "${namespace}" "${release_name}" > /dev/null 2>&1; then
    helm uninstall -n "${namespace}" "${release_name}"
    if [[ $? -ne 0 ]]; then
      echo "failed to uninstall ${release_name}"
      exit 1
    fi
  else
    echo "${release_name} is not installed, skipping..."
  fi
}

# Uninstall provisioner web ui
helm_uninstall_if_exists platform-provisioner-ui "${PIPELINE_NAMESPACE}"

# Uninstall provisioner config
helm_uninstall_if_exists provisioner-config-local "${PIPELINE_NAMESPACE}"

# Uninstall helm-install pipeline
helm_uninstall_if_exists helm-install "${PIPELINE_NAMESPACE}"

# Uninstall generic-runner pipeline
helm_uninstall_if_exists generic-runner "${PIPELINE_NAMESPACE}"

# Uninstall common-dependency pipeline
helm_uninstall_if_exists common-dependency "${PIPELINE_NAMESPACE}"

# Delete service account and cluster role binding
kubectl delete clusterrolebinding pipeline-cluster-admin 2>/dev/null || echo "clusterrolebinding pipeline-cluster-admin not found, skipping..."
kubectl delete serviceaccount -n "${PIPELINE_NAMESPACE}" pipeline-cluster-admin 2>/dev/null || echo "serviceaccount pipeline-cluster-admin not found, skipping..."

# Set default Tekton Dashboard release version if not already set
TEKTON_DASHBOARD_RELEASE=${TEKTON_DASHBOARD_RELEASE:-"v0.52.0"}

# Uninstall tekton dashboard
if [[ ${PIPELINE_SKIP_TEKTON_DASHBOARD} != "true" ]]; then
  if [[ -z "${TEKTON_DASHBOARD_RELEASE}" ]]; then
    echo "TEKTON_DASHBOARD_RELEASE is not set. Please set it before running the script."
    exit 1
  fi
  kubectl delete --filename "https://storage.googleapis.com/tekton-releases/dashboard/previous/${TEKTON_DASHBOARD_RELEASE}/release.yaml"
  if [[ $? -ne 0 ]]; then
    echo "failed to uninstall tekton dashboard"
    exit 1
  fi
fi

# Set default Tekton Pipeline release version if not already set
TEKTON_PIPELINE_RELEASE=${TEKTON_PIPELINE_RELEASE:-"v0.65.0"}

# Uninstall tekton pipeline
if [[ ${PIPELINE_SKIP_TEKTON_PIPELINE} != "true" ]]; then
  kubectl delete --filename "https://storage.googleapis.com/tekton-releases/pipeline/previous/${TEKTON_PIPELINE_RELEASE}/release.yaml"
  if [[ $? -ne 0 ]]; then
    echo "failed to uninstall tekton pipeline"
    exit 1
  fi
fi

# Delete namespace
kubectl delete namespace "${PIPELINE_NAMESPACE}"
if [[ $? -ne 0 ]]; then
  echo "failed to delete namespace ${PIPELINE_NAMESPACE}"
  exit 1
fi

echo "Platform provisioner uninstalled successfully."
