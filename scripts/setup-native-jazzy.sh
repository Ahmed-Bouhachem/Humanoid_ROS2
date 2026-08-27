#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_ROOT="${REPO_ROOT}/.native"
SOURCE_ROOT="${NATIVE_ROOT}/src"
CACHE_ROOT="${NATIVE_ROOT}/cache"
ROBOTICS_PREFIX="${NATIVE_ROOT}/unitree_robotics"
ONNXRUNTIME_ROOT="${NATIVE_ROOT}/onnxruntime"
BUILD_JOBS="${BUILD_JOBS:-8}"

UNITREE_SDK2_SHA=21d0a3b2c46ee48c8fdf2783becb6be3beb0a59b
UNITREE_MUJOCO_SHA=ae6a8403e272733e9996ef59990880330496177f
LIVOX_SDK2_SHA=08f523c930b2f0ba1e98a6afaa8d7476bf479908
MUJOCO_VERSION=3.3.6
ONNXRUNTIME_VERSION=1.20.1

for command_name in cmake curl git g++ make tar; do
    command -v "${command_name}" >/dev/null || {
        echo "Missing command: ${command_name}" >&2
        echo "Run ./scripts/install-native-dependencies.sh first." >&2
        exit 1
    }
done

mkdir -p "${SOURCE_ROOT}" "${CACHE_ROOT}" "${ROBOTICS_PREFIX}"

checkout_pinned() {
    local url="$1" sha="$2" destination="$3"
    if [[ ! -d "${destination}/.git" ]]; then
        mkdir -p "${destination}"
        git -C "${destination}" init -q
        git -C "${destination}" remote add origin "${url}"
    fi
    git -C "${destination}" fetch --depth 1 origin "${sha}"
    git -C "${destination}" checkout -q --detach FETCH_HEAD
}

download() {
    local url="$1" destination="$2"
    if [[ ! -s "${destination}" ]]; then
        curl --fail --location --continue-at - --output "${destination}" "${url}"
    fi
}

echo "[1/5] Building Unitree SDK2"
SDK_SOURCE="${SOURCE_ROOT}/unitree_sdk2"
checkout_pinned https://github.com/unitreerobotics/unitree_sdk2.git \
    "${UNITREE_SDK2_SHA}" "${SDK_SOURCE}"
cmake -S "${SDK_SOURCE}" -B "${SDK_SOURCE}/build-native" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${ROBOTICS_PREFIX}" \
    -DBUILD_EXAMPLES=OFF
cmake --build "${SDK_SOURCE}/build-native" --parallel "${BUILD_JOBS}"
cmake --install "${SDK_SOURCE}/build-native"

echo "[2/5] Building Livox SDK2"
LIVOX_SOURCE="${SOURCE_ROOT}/Livox-SDK2"
checkout_pinned https://github.com/Livox-SDK/Livox-SDK2.git \
    "${LIVOX_SDK2_SHA}" "${LIVOX_SOURCE}"
cmake -S "${LIVOX_SOURCE}" -B "${LIVOX_SOURCE}/build-native" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${ROBOTICS_PREFIX}"
cmake --build "${LIVOX_SOURCE}/build-native" --parallel "${BUILD_JOBS}"
cmake --install "${LIVOX_SOURCE}/build-native"

echo "[3/5] Installing ONNX Runtime ${ONNXRUNTIME_VERSION} locally"
ONNX_ARCHIVE="${CACHE_ROOT}/onnxruntime-${ONNXRUNTIME_VERSION}.tgz"
download \
    "https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz" \
    "${ONNX_ARCHIVE}"
if [[ ! -f "${ONNXRUNTIME_ROOT}/lib/libonnxruntime.so" ]]; then
    mkdir -p "${ONNXRUNTIME_ROOT}"
    tar -xzf "${ONNX_ARCHIVE}" --strip-components=1 -C "${ONNXRUNTIME_ROOT}"
fi

echo "[4/5] Installing MuJoCo ${MUJOCO_VERSION} locally"
MUJOCO_ARCHIVE="${CACHE_ROOT}/mujoco-${MUJOCO_VERSION}.tar.gz"
MUJOCO_ROOT="${NATIVE_ROOT}/mujoco-${MUJOCO_VERSION}"
download \
    "https://github.com/google-deepmind/mujoco/releases/download/${MUJOCO_VERSION}/mujoco-${MUJOCO_VERSION}-linux-x86_64.tar.gz" \
    "${MUJOCO_ARCHIVE}"
if [[ ! -f "${MUJOCO_ROOT}/include/mujoco/mujoco.h" ]]; then
    mkdir -p "${MUJOCO_ROOT}"
    tar -xzf "${MUJOCO_ARCHIVE}" --strip-components=1 -C "${MUJOCO_ROOT}"
fi

echo "[5/5] Building the patched Unitree MuJoCo simulator"
SIM_SOURCE="${SOURCE_ROOT}/unitree_mujoco"
checkout_pinned https://github.com/unitreerobotics/unitree_mujoco.git \
    "${UNITREE_MUJOCO_SHA}" "${SIM_SOURCE}"

for patch_file in "${REPO_ROOT}"/workspace/patches/unitree_mujoco/*.patch; do
    if git -C "${SIM_SOURCE}" apply --check "${patch_file}" 2>/dev/null; then
        git -C "${SIM_SOURCE}" apply "${patch_file}"
    elif git -C "${SIM_SOURCE}" apply --reverse --check "${patch_file}" 2>/dev/null; then
        : # Already applied.
    else
        echo "Patch does not apply cleanly: ${patch_file}" >&2
        exit 1
    fi
done

cp -f "${REPO_ROOT}"/workspace/vendor/unitree_mujoco/*.h \
    "${REPO_ROOT}"/workspace/vendor/unitree_mujoco/*.cc \
    "${SIM_SOURCE}/simulate/src/"

if [[ -e "${SIM_SOURCE}/simulate/mujoco" && ! -L "${SIM_SOURCE}/simulate/mujoco" ]]; then
    rm -rf "${SIM_SOURCE}/simulate/mujoco"
fi
ln -sfn "${MUJOCO_ROOT}" "${SIM_SOURCE}/simulate/mujoco"

cmake -S "${SIM_SOURCE}/simulate" -B "${SIM_SOURCE}/simulate/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${ROBOTICS_PREFIX}/lib/cmake"
cmake --build "${SIM_SOURCE}/simulate/build" \
    --target unitree_mujoco --parallel "${BUILD_JOBS}"

echo
echo "Native dependencies are ready. Continue with:"
echo "  source scripts/native-env.sh"
echo "  ./scripts/build-native-jazzy.sh"

