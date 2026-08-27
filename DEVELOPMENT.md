# Native Jazzy development notes

This project targets Ubuntu 24.04 and ROS 2 Jazzy directly on the host.

## Directory model

- `.native/`: pinned third-party SDKs, MuJoCo, ONNX Runtime, caches, and ROS logs.
- `workspace/src/`: project packages plus ignored repositories imported from `workspace.repos`.
- `workspace/build/`, `workspace/install/`, `workspace/log/`: colcon output.
- `config/cyclonedds.xml`: loopback-only Unitree DDS configuration for simulation.

All generated directories are ignored by Git and excluded by the independent-copy script.

## Pinned native dependencies

`scripts/setup-native-jazzy.sh` is the source of truth:

| Dependency | Pin |
|---|---|
| Unitree SDK2 | `21d0a3b2c46ee48c8fdf2783becb6be3beb0a59b` |
| Unitree MuJoCo | `ae6a8403e272733e9996ef59990880330496177f` |
| Livox SDK2 | `08f523c930b2f0ba1e98a6afaa8d7476bf479908` |
| MuJoCo | `3.3.6` |
| ONNX Runtime | `1.20.1` |

The setup is idempotent. Rerun it after changing a pin, vendor source, or patch.

## Build profiles

```bash
./scripts/build-native-jazzy.sh         # all packages except g1_orchestration
./scripts/build-native-jazzy.sh --full  # includes BehaviorTree.CPP orchestration
```

The default build disables tests to provide a dependable first simulation build. For a test
build, source the environment and invoke colcon directly:

```bash
source scripts/native-env.sh
cd workspace
colcon build --symlink-install --cmake-args -DBUILD_TESTING=ON
colcon test --packages-select-regex '^g1_'
colcon test-result --verbose
```

## Runtime checks

Start the simulator in one terminal:

```bash
source scripts/native-env.sh
ros2 launch g1_bringup bringup.launch.py headless:=false
```

In another terminal:

```bash
source scripts/native-env.sh
ros2 node list
ros2 control list_controllers
ros2 topic hz /joint_states
```

Expected bare-simulation state: `agile_controller`, `locomotion_safety_controller`,
`waist_freeze_controller`, `arm_freeze_controller`, `joint_state_broadcaster`, and
`imu_sensor_broadcaster` are active. `/joint_states` should be close to 200 Hz.

If discovery looks stale, restart the ROS CLI cache:

```bash
ros2 daemon stop
ros2 node list --no-daemon
```

Use `./scripts/clean-stack.sh` after a crashed or interrupted launch.

## Graphics

`headless:=false` uses the current `DISPLAY` and opens the MuJoCo viewer. `headless:=true` starts
an isolated Xvfb display at `:133`. RViz is controlled independently with `rviz:=true`, so a run
may use a headless physics process while RViz remains visible.

## Updating the patched simulator

Change `UNITREE_MUJOCO_SHA` in `scripts/setup-native-jazzy.sh`, then regenerate the patches under
`workspace/patches/unitree_mujoco/` against that exact commit. The setup script runs `git apply
--check` and stops if a patch no longer applies.
