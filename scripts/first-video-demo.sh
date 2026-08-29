#!/usr/bin/env bash
# Run the recording demo in a network namespace that contains only loopback. This is stronger
# than selecting lo in CycloneDDS: the process tree has no physical network interface to select.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "${script_dir}")"

# Prefer the discrete NVIDIA GPU for RViz. On this hybrid laptop MuJoCo's older GLFW/GLX
# presentation path can expose stale compositor buffers with the NVIDIA driver, so MuJoCo is
# sent to the AMD Mesa renderer separately below. Both paths remain hardware accelerated.
# Set G1_DEMO_GPU=desktop to opt out of the explicit NVIDIA selection.
gpu_mode="${G1_DEMO_GPU:-auto}"
gpu_inventory=""
if command -v switcherooctl >/dev/null 2>&1; then
  gpu_inventory="$(switcherooctl list 2>/dev/null || true)"
fi
if [[ "${gpu_mode}" == "auto" ]]; then
  if [[ "${gpu_inventory}" == *"NVIDIA Corporation"* ]]; then
    gpu_mode="nvidia"
  else
    gpu_mode="desktop"
  fi
fi

if [[ "${gpu_mode}" == "nvidia" ]]; then
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export __NV_PRIME_RENDER_OFFLOAD=1
  export __VK_LAYER_NV_optimus=NVIDIA_only
fi
export G1_DEMO_GPU="${gpu_mode}"

# These variables are consumed only by the MuJoCo ExecuteProcess environment in sim.launch.py;
# RViz keeps the NVIDIA variables above. DRI_PRIME=1 avoids hard-coding a PCI address.
mujoco_gpu="${G1_MUJOCO_GPU:-auto}"
if [[ "${mujoco_gpu}" == "auto" ]]; then
  if [[ "${gpu_inventory}" == *"Advanced Micro Devices"* ]]; then
    mujoco_gpu="amd"
  else
    mujoco_gpu="inherit"
  fi
fi
if [[ "${mujoco_gpu}" == "amd" ]]; then
  export G1_MUJOCO_GLX_VENDOR_LIBRARY_NAME=mesa
  export G1_MUJOCO_DRI_PRIME=1
fi
export G1_MUJOCO_GPU="${mujoco_gpu}"

# The MuJoCo viewer follows the panel refresh rate by default. On a 240 Hz laptop it can
# consume the entire GPU while RViz receives only a few frames. The patched viewer converts
# this target into a render-thread timer; physics, controller, and sensor rates are untouched.
export GROVE_G1_VIEWER_FPS="${GROVE_G1_VIEWER_FPS:-30}"

if [[ "${G1_DEMO_NETNS:-0}" != "1" ]]; then
  if pgrep -f '[/]unitree_mujoco -r g1' >/dev/null 2>&1; then
    printf 'A G1 MuJoCo simulation is already running. Stop it before starting another.\n' >&2
    printf 'Use: %s/scripts/clean-stack.sh\n' "${repo_root}" >&2
    exit 1
  fi
  exec unshare --user --map-root-user --net \
    env G1_DEMO_NETNS=1 "${BASH_SOURCE[0]}" "$@"
fi

ip link set lo up
source "${repo_root}/scripts/native-env.sh"

if [[ "${G1_DEMO_GPU}" == "nvidia" ]]; then
  printf 'RViz graphics: NVIDIA PRIME offload enabled.\n'
else
  printf 'RViz graphics: desktop default (set G1_DEMO_GPU=nvidia to force NVIDIA).\n'
fi
if [[ "${G1_MUJOCO_GPU}" == "amd" ]]; then
  printf 'MuJoCo graphics: AMD Mesa hardware acceleration (stable GLFW/GLX path).\n'
else
  printf 'MuJoCo graphics: inherited from the desktop/RViz environment.\n'
fi
printf 'MuJoCo viewer cap: %s FPS (physics remains real-time).\n' "${GROVE_G1_VIEWER_FPS}"

for argument in "$@"; do
  if [[ "${argument}" == "auto_start:=true" ]]; then
    exec ros2 launch g1_demos first_video_demo.launch.py "$@"
  fi
done

ros2 launch g1_demos first_video_demo.launch.py "$@" &
launch_pid=$!

shutdown_demo() {
  kill -INT "${launch_pid}" 2>/dev/null || true
  wait "${launch_pid}" 2>/dev/null || true
}
trap shutdown_demo INT TERM EXIT

printf '\nWait until RViz displays READY TO RECORD.\n'
read -r -p 'Start your recorder, then press Enter to begin the one-shot demo... ' _
ros2 service call /g1_video_demo/start std_srvs/srv/Trigger '{}'
wait "${launch_pid}"
