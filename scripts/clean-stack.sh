#!/usr/bin/env bash

# Stop leftovers from native G1 simulation runs. This intentionally targets
# only this stack's launchers, binaries, ROS nodes, and virtual display.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/native-env.sh"

G1_CONTROLLERS='joint_state_broadcaster|imu_sensor_broadcaster|waist_freeze_controller|arm_freeze_controller|locomotion_safety_controller|locomotion_freeze_controller|arm_trajectory_controller|left_hand_controller|right_hand_controller|agile_controller'
G1_UNIQUE_CONTROLLERS='waist_freeze_controller|arm_freeze_controller|locomotion_safety_controller|locomotion_freeze_controller|arm_trajectory_controller|left_hand_controller|right_hand_controller|agile_controller'
PATTERN="unitree_mujoco|g1_bringup|g1_navigation|g1_manipulation|g1_orchestration|g1_sensor_relay|g1_state_estimation|ros2_control_node|robot_state_publisher|rviz2|Xvfb :133|${G1_CONTROLLERS}"

mapfile -t PIDS < <(pgrep -f "${PATTERN}" || true)
TARGETS=()
for pid in "${PIDS[@]}"; do
    [[ "${pid}" == "$$" || "${pid}" == "${PPID}" ]] && continue
    # Every process started after native-env.sh inherits this marker. Do not
    # terminate an unrelated RViz or ROS session owned by the same user.
    if tr '\0' '\n' < "/proc/${pid}/environ" 2>/dev/null \
        | grep -Fqx "G1_NATIVE_ROOT=${G1_NATIVE_ROOT}"; then
        TARGETS+=("${pid}")
        continue
    fi

    # A controller spawner can outlive its launch process while waiting on the
    # global ros2_control spawner lock. Catch only G1-specific controller names
    # here, even if the inherited environment is no longer readable.
    cmdline="$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true)"
    if [[ "${cmdline}" =~ /controller_manager/spawner[[:space:]]+(${G1_UNIQUE_CONTROLLERS})([[:space:]]|$) ]]; then
        TARGETS+=("${pid}")
    fi
done

if ((${#TARGETS[@]})); then
    kill -TERM "${TARGETS[@]}" 2>/dev/null || true
    REMAINING=("${TARGETS[@]}")
    for _ in 1 2 3 4 5; do
        REMAINING=()
        for pid in "${TARGETS[@]}"; do
            kill -0 "${pid}" 2>/dev/null && REMAINING+=("${pid}")
        done
        ((${#REMAINING[@]} == 0)) && break
        sleep 1
    done
    ((${#REMAINING[@]})) && kill -KILL "${REMAINING[@]}" 2>/dev/null || true
fi

rm -f /tmp/.X133-lock /tmp/.X11-unix/X133 /tmp/g1_sensors.sock
ros2 daemon stop >/dev/null 2>&1 || true

printf 'Stopped %d native G1/ROS process(es).\n' "${#TARGETS[@]}"
