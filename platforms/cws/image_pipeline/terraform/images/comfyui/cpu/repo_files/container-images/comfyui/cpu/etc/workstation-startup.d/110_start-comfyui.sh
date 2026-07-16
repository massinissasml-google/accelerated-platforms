#!/usr/bin/env bash

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o xtrace

log_file="/var/log/workstation-start-comfyui.log"

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> ${log_file} 2>&1

# Create user's ComfyUI directory if it doesn't exist
###############################################################################
if [[ ! -d "${USER_COMFYUI_DIR}" ]]; then
  mkdir -p "${USER_COMFYUI_DIR}"
fi



# Configure 'input' directory
###############################################################################
if [[ ! -d "${USER_COMFYUI_DIR}/${COMFYUI_INPUT_DIR}" ]]; then
  mkdir -p "${USER_COMFYUI_DIR}/${COMFYUI_INPUT_DIR}"
fi

if [[ -d "${COMFYUI_DIR}/${COMFYUI_INPUT_DIR}" ]]; then
  rm -rf "${COMFYUI_DIR}/${COMFYUI_INPUT_DIR}"
fi

ln --symbolic "${USER_COMFYUI_DIR}/${COMFYUI_INPUT_DIR}" "${COMFYUI_DIR}/${COMFYUI_INPUT_DIR}"



# Configure 'models' directory
###############################################################################
if [[ ! -d "${COMFYUI_DIR}/${COMFYUI_MODELS_DIR}" ]]; then
  mkdir -p "${COMFYUI_DIR}/${COMFYUI_MODELS_DIR}"
fi

if [[ -v COMFYUI_MODELS_BUCKET ]]; then
  gcsfuse "${COMFYUI_MODELS_BUCKET}" "${COMFYUI_DIR}/${COMFYUI_MODELS_DIR}"
elif [[ -v COMFYUI_USER_MANAGED_MODELS ]]; then
  ln --symbolic "${USER_COMFYUI_DIR}/${COMFYUI_MODELS_DIR}" "${COMFYUI_DIR}/${COMFYUI_MODELS_DIR}"
fi



# Configure 'output' directory
###############################################################################
if [[ ! -d "${USER_COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}" ]]; then
  mkdir -p "${USER_COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}"
fi

if [[ -d "${COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}" ]]; then
  rm -rf "${COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}"
fi

ln --symbolic "${USER_COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}" "${COMFYUI_DIR}/${COMFYUI_OUTPUT_DIR}"



# Configure 'user' directory (settings, workflows, history, etc.)
# This replaces the narrow 'workflows' directory configuration block.
###############################################################################
COMFYUI_USER_DIR="user"
if [[ ! -d "${USER_COMFYUI_DIR}/${COMFYUI_USER_DIR}" ]]; then
  mkdir -p "${USER_COMFYUI_DIR}/${COMFYUI_USER_DIR}"
  if [[ -d "${COMFYUI_DIR}/${COMFYUI_USER_DIR}" ]]; then
    # Copy default workflows and settings from container to persistent disk
    cp -rP "${COMFYUI_DIR}/${COMFYUI_USER_DIR}"/. "${USER_COMFYUI_DIR}/${COMFYUI_USER_DIR}"/
  fi
fi

if [[ -d "${COMFYUI_DIR}/${COMFYUI_USER_DIR}" ]]; then
  rm -rf "${COMFYUI_DIR}/${COMFYUI_USER_DIR}"
fi

ln --symbolic "${USER_COMFYUI_DIR}/${COMFYUI_USER_DIR}" "${COMFYUI_DIR}/${COMFYUI_USER_DIR}"



# Configure 'custom_nodes' directory to persist runtime-installed custom nodes
###############################################################################
COMFYUI_CUSTOM_NODE_DIR="custom_nodes"
if [[ ! -d "${USER_COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}" ]]; then
  mkdir -p "${USER_COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}"
  if [[ -d "${COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}" ]]; then
    # Copy pre-installed custom nodes from container build to persistent disk
    cp -rP "${COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}"/. "${USER_COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}"/
  fi
fi

if [[ -d "${COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}" ]]; then
  rm -rf "${COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}"
fi

ln --symbolic "${USER_COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}" "${COMFYUI_DIR}/${COMFYUI_CUSTOM_NODE_DIR}"



# Configure 'extra_model_paths.yaml' if user-defined paths are provided
###############################################################################
EXTRA_MODEL_PATHS_FILE="extra_model_paths.yaml"
if [[ -f "${USER_COMFYUI_DIR}/${EXTRA_MODEL_PATHS_FILE}" ]]; then
  if [[ -f "${COMFYUI_DIR}/${EXTRA_MODEL_PATHS_FILE}" ]]; then
    rm -f "${COMFYUI_DIR}/${EXTRA_MODEL_PATHS_FILE}"
  fi
  ln --symbolic "${USER_COMFYUI_DIR}/${EXTRA_MODEL_PATHS_FILE}" "${COMFYUI_DIR}/${EXTRA_MODEL_PATHS_FILE}"
fi



# Ensure correct permissions on the persistent ComfyUI workspace
###############################################################################
chown -R 1000:1000 "${USER_COMFYUI_DIR}"



# Start ComfyUI
###############################################################################
source /comfy/.venv/bin/activate

comfy launch -- --enable-cors-header --listen=0.0.0.0 --port=80
