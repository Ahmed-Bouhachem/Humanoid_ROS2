#!/usr/bin/env bash
# Run the recording demo in a network namespace that contains only loopback. This is stronger
# than selecting lo in CycloneDDS: the process tree has no physical network interface to select.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "${script_dir}")"

if [[ "${G1_DEMO_NETNS:-0}" != "1" ]]; then
  exec unshare --user --map-root-user --net \
    env G1_DEMO_NETNS=1 "${BASH_SOURCE[0]}" "$@"
fi

ip link set lo up
source "${repo_root}/scripts/native-env.sh"

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
