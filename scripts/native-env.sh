#!/usr/bin/env bash

# Source this file before building or running the native ROS 2 Jazzy stack.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Source this script instead of executing it:" >&2
    echo "  source scripts/native-env.sh" >&2
    exit 2
fi

G1_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export G1_NATIVE_ROOT="${G1_REPO_ROOT}/.native"
export ROS_LOG_DIR="${G1_NATIVE_ROOT}/ros-logs"
export UNITREE_ROBOTICS_PREFIX="${G1_NATIVE_ROOT}/unitree_robotics"
export UNITREE_SDK2_PREFIX="${UNITREE_ROBOTICS_PREFIX}"
export ONNXRUNTIME_ROOT="${G1_NATIVE_ROOT}/onnxruntime"
export UNITREE_MUJOCO_BIN="${G1_NATIVE_ROOT}/src/unitree_mujoco/simulate/build/unitree_mujoco"
export G1_VENDOR_MESHES="${G1_NATIVE_ROOT}/src/unitree_mujoco/unitree_robots/g1/meshes"

# ROS uses Fast DDS. Unitree SDK2 carries a separate CycloneDDS build for its
# rt/* channels; pin that transport to loopback so simulation traffic cannot
# reach a physical robot interface.
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DOMAIN_ID="${GROVE_G1_ROS_DOMAIN_ID:-1}"
export CYCLONEDDS_URI="file://${G1_REPO_ROOT}/config/cyclonedds.xml"

mkdir -p "${ROS_LOG_DIR}"

G1_RESTORE_NOUNSET=false
if [[ $- == *u* ]]; then
    G1_RESTORE_NOUNSET=true
    set +u
fi

source /opt/ros/jazzy/setup.bash

export PATH="${UNITREE_ROBOTICS_PREFIX}/bin:${PATH}"
export CMAKE_PREFIX_PATH="${UNITREE_ROBOTICS_PREFIX}:${CMAKE_PREFIX_PATH:-}"
export LD_LIBRARY_PATH="${UNITREE_ROBOTICS_PREFIX}/lib:${ONNXRUNTIME_ROOT}/lib:${LD_LIBRARY_PATH:-}"

if [[ "${G1_SKIP_WORKSPACE_SETUP:-0}" != "1" && \
      -f "${G1_REPO_ROOT}/workspace/install/setup.bash" ]]; then
    source "${G1_REPO_ROOT}/workspace/install/setup.bash"
fi

if [[ "${G1_RESTORE_NOUNSET}" == "true" ]]; then
    set -u
fi

unset G1_REPO_ROOT G1_RESTORE_NOUNSET
