#!/usr/bin/env bash

# Convenience entry point for the native Ubuntu 24.04 / ROS 2 Jazzy workflow.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-help}"
shift || true

usage() {
    cat <<'EOF'
Usage: ./scripts/manage.sh ACTION [launch arguments]

  deps        Install Ubuntu and ROS 2 Jazzy packages (uses sudo apt).
  setup       Import ROS externals and build pinned native vendor libraries.
  build       Build the Jazzy workspace (skips optional orchestration).
  build-full  Build every package, including BehaviorTree orchestration.
  sim         Launch native MuJoCo and ROS 2; extra arguments are forwarded.
  clean       Stop leftover G1/ROS processes and clear stale DDS state.
  env         Print the command used to enter the project environment.

Examples:
  ./scripts/manage.sh sim headless:=false
  ./scripts/manage.sh sim sensors:=true rviz:=true headless:=false
EOF
}

case "${ACTION}" in
    deps)
        exec "${REPO_ROOT}/scripts/install-native-dependencies.sh"
        ;;
    setup)
        "${REPO_ROOT}/scripts/import-externals.sh"
        exec "${REPO_ROOT}/scripts/setup-native-jazzy.sh"
        ;;
    build)
        exec "${REPO_ROOT}/scripts/build-native-jazzy.sh"
        ;;
    build-full)
        exec "${REPO_ROOT}/scripts/build-native-jazzy.sh" --full
        ;;
    sim)
        source "${REPO_ROOT}/scripts/native-env.sh"
        exec ros2 launch g1_bringup bringup.launch.py "$@"
        ;;
    clean)
        exec "${REPO_ROOT}/scripts/clean-stack.sh"
        ;;
    env)
        printf 'source %q\n' "${REPO_ROOT}/scripts/native-env.sh"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown action: ${ACTION}" >&2
        usage >&2
        exit 2
        ;;
esac
