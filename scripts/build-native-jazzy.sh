#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export G1_SKIP_WORKSPACE_SETUP=1
source "${REPO_ROOT}/scripts/native-env.sh"
unset G1_SKIP_WORKSPACE_SETUP

if [[ ! -x "${UNITREE_MUJOCO_BIN}" ]]; then
    echo "Native simulator dependencies are missing." >&2
    echo "Run ./scripts/setup-native-jazzy.sh first." >&2
    exit 1
fi

cd "${REPO_ROOT}/workspace"

PACKAGE_ARGS=(--packages-skip g1_orchestration)
if [[ "${1:-}" == "--full" ]]; then
    PACKAGE_ARGS=()
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--full]" >&2
    exit 2
fi

colcon build --symlink-install \
    --parallel-workers "${BUILD_JOBS:-8}" \
    "${PACKAGE_ARGS[@]}" \
    --cmake-args \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DBUILD_TESTING=OFF \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DUNITREE_SDK2_PREFIX="${UNITREE_SDK2_PREFIX}" \
      -DONNXRUNTIME_ROOT="${ONNXRUNTIME_ROOT}"
