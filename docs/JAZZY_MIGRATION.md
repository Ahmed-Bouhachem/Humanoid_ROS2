# Native ROS 2 Jazzy migration

This document records the engineering changes made in the `Humanoid_ROS2` version of the G1
stack. It separates the work performed here from functionality inherited from the upstream
project.

## Objective

Run the humanoid stack directly on Ubuntu 24.04 and ROS 2 Jazzy, keep third-party dependencies
reproducible and local to the repository, preserve simulation safety boundaries, and provide a
clean base for learning and future Gazebo work.

## Changes made

### Native dependency layout

The original environment automation was removed. `scripts/setup-native-jazzy.sh` now fetches
pinned versions of:

| Dependency | Version or commit |
|---|---|
| Unitree SDK2 | `21d0a3b2c46ee48c8fdf2783becb6be3beb0a59b` |
| Unitree MuJoCo | `ae6a8403e272733e9996ef59990880330496177f` |
| Livox SDK2 | `08f523c930b2f0ba1e98a6afaa8d7476bf479908` |
| MuJoCo | `3.3.6` |
| ONNX Runtime | `1.20.1` |

All generated content is placed under `.native/`. This avoids modifying the ROS installation or
requiring fixed project files under `/opt`.

### Build-system portability

The controller and hardware-interface CMake files now accept native dependency prefixes through
environment variables. The robot description receives its visual meshes from the local Unitree
MuJoCo checkout. `scripts/build-native-jazzy.sh` starts from the Jazzy underlay and avoids using a
stale build of the same workspace as an underlay.

### ROS 2 Jazzy source imports

`scripts/import-externals.sh` imports external repositories shallowly, prepares
`livox_ros_driver2` for ROS 2 Jazzy, and applies the project-specific FAST-LIO queue and
initialization changes reproducibly.

### Simulation safety

`config/cyclonedds.xml` pins Unitree CycloneDDS communication to loopback. The native environment
selects ROS domain 1 and Fast DDS for the ROS graph while Unitree SDK2 uses its own CycloneDDS
libraries. The simulation launch checks these assumptions before starting low-level control.

### Native operator workflow

The following scripts were introduced or rewritten:

| Script | Role |
|---|---|
| `install-native-dependencies.sh` | Ubuntu and ROS 2 Jazzy packages |
| `setup-native-jazzy.sh` | Pinned SDK, runtime, and simulator setup |
| `native-env.sh` | Runtime and build environment |
| `build-native-jazzy.sh` | Reproducible colcon build |
| `manage.sh` | Short native operator commands |
| `clean-stack.sh` | Scoped cleanup of this project's ROS processes |
| `create-independent-copy.sh` | Clean repository export without generated data |

### Verification performed

- Fourteen default ROS packages built successfully with `colcon` on Jazzy.
- MuJoCo 3.3.6 loaded the G1 model and Dex3 hands.
- The Unitree body interface initialized all 29 motor joints.
- The ONNX locomotion policy loaded and activated with its safety controller.
- Controller state matched the expected bare-simulation ownership model.
- `/joint_states` converged close to the configured 200 Hz update rate.
- Live pelvis IMU data was received through ROS 2.
- RViz started with OpenGL and connected to the running graph.

## Gazebo is a new backend, not a launch-file rename

ROS 2 Jazzy supports Gazebo Harmonic through `ros_gz` and `gz_ros2_control`, but the existing
simulation has MuJoCo-specific motor, sensor, scene, and ground-truth paths. Backend parity needs a
Gazebo-specific robot control xacro, SDF worlds, sensor bridges, odometry/TF integration, launch
files, and validation of the learned policy under different contact dynamics.

That work is the next engineering milestone rather than a capability claimed by the current
branch.
