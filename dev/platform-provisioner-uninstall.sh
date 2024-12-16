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

# Uninstall provisioner web ui
helm uninstall -n "${PIPELINE_NAMESPACE}" platform-provisioner-ui
if [[ $? -ne 0 ]]; then
  echo "failed to uninstall platform-provisioner-ui"
  exit 1
fi

# Uninstall provisioner config
helm uninstall -n "${PIPELINE_NAMESPACE}" provisioner-config-local
if [[ $? -ne 0 ]]; then
  echo "failed to uninstall provisioner-config-local"
  exit 1
fi

# Uninstall helm-install pipeline
helm uninstall -n "${PIPELINE_NAMESPACE}" helm-install
if [[ $? -ne 0 ]]; then
  echo "failed to uninstall helm-install pipeline"
  exit 1
fi

# Uninstall generic-runner pipeline
helm uninstall -n "${PIPELINE_NAMESPACE}" generic-runner
if [[ $? -ne 0 ]]; then
  echo "failed to uninstall generic-runner pipeline"
  exit 1
fi

# Uninstall common-dependency pipeline
helm uninstall -n "${PIPELINE_NAMESPACE}" common-dependency
if [[ $? -ne 0 ]]; then
  echo "failed to uninstall common-dependency"
  exit 1
fi

# Delete service account and cluster role binding
kubectl delete clusterrolebinding pipeline-cluster-admin
kubectl delete serviceaccount -n "${PIPELINE_NAMESPACE}" pipeline-cluster-admin

# Uninstall tekton dashboard
if [[ ${PIPELINE_SKIP_TEKTON_DASHBOARD} != "true" ]]; then
  kubectl delete --filename "https://storage.googleapis.com/tekton-releases/dashboard/previous/${TEKTON_DASHBOARD_RELEASE}/release.yaml"
  if [[ $? -ne 0 ]]; then
    echo "failed to uninstall tekton dashboard"
    exit 1
  fi
fi

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
