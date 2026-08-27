# LinkedIn demo video plan

This plan presents the project as engineering work and a learning journey. It clearly credits the
upstream base while showing the native Jazzy migration and validation performed in this version.

## Recommended format

- Duration: 60 to 90 seconds.
- Record at 1920 x 1080 for a terminal-plus-simulator layout, or crop the final edit to 4:5 for a
  larger mobile-feed presentation.
- Export as MP4/H.264 at 30 or 60 FPS.
- Use large terminal text and keep important text away from the screen edges.
- Add captions; many viewers will watch without sound.
- Never show access tokens, private keys, passwords, or browser credential dialogs.

LinkedIn currently accepts videos from 256 x 144 through 4096 x 2304, aspect ratios from 1:2.4 to
2.4:1, and frame rates from 10 to 60 FPS. See the
[official LinkedIn video requirements](https://www.linkedin.com/help/linkedin/answer/a7494039).

## Before recording

Build and test everything before starting the screen recorder. Do not record dependency downloads
or a long compilation.

```bash
cd ~/humainoid_ws/g1-ros2-jazzy
source scripts/native-env.sh
```

Prepare two terminals:

- Terminal A: launch output.
- Terminal B: short ROS inspection commands.

Arrange the MuJoCo viewer and RViz so the robot remains visible when switching windows.

## 75-second shot list

| Time | Visual | Message |
|---|---|---|
| 0–5 s | Title: `Humanoid_ROS2 — Unitree G1 on ROS 2 Jazzy` | Clear hook and project identity |
| 5–15 s | README section “What I changed” | Native Jazzy migration, no Docker, reproducible local dependencies |
| 15–25 s | Run the launch command | One native command starts the ROS control stack and simulator |
| 25–40 s | MuJoCo viewer with the standing G1 | Physics model and learned balance controller are running |
| 40–52 s | RViz robot model, TF, or sensor display | ROS visualization is separate from the physics backend |
| 52–63 s | `ros2 control list_controllers` and `/joint_states` rate | Show measurable proof, not only a GUI |
| 63–70 s | Gazebo plan in the README | Explain the next milestone honestly |
| 70–75 s | GitHub repository URL and closing title | Invite technical feedback and collaboration |

## Commands to record

Launch MuJoCo, sensors, and RViz:

```bash
ros2 launch g1_bringup bringup.launch.py \
  sensors:=true rviz:=true headless:=false odometry:=ground_truth
```

In the second terminal:

```bash
ros2 control list_controllers
ros2 topic hz /joint_states
ros2 topic echo /imu_sensor_broadcaster/imu --once
```

Stop the stack cleanly after recording:

```bash
./scripts/clean-stack.sh
```

## Narration script

> I have been adapting a Unitree G1 humanoid stack into a native ROS 2 Jazzy learning project.
> The upstream project provided the core G1 autonomy work. In my version, I removed the container
> workflow, created reproducible workspace-local dependency builds, updated the native build and
> launch environment, and added loopback isolation for simulated low-level motor traffic. Here the
> G1 is running in MuJoCo with ros2_control and a learned locomotion policy. RViz connects to the
> same ROS graph for robot, TF, and sensor visualization. I validated the controller states, live
> IMU data, and joint-state updates near 200 hertz. My next milestone is a proper Gazebo Harmonic
> backend using gz_ros2_control, with equivalent sensors and control behavior. The project and
> migration notes are available on GitHub, and I would be glad to hear feedback from the robotics
> community.

## Suggested LinkedIn post

I have been working on **Humanoid_ROS2**, a native ROS 2 Jazzy development and simulation project
for the Unitree G1 humanoid.

The project is derived from the open-source `maxwellrobotics/g1-ros2` stack. My work in this
version focused on:

- replacing the container workflow with native Ubuntu 24.04 / ROS 2 Jazzy tooling;
- building pinned Unitree, Livox, MuJoCo, and ONNX dependencies locally and reproducibly;
- isolating simulated low-level DDS traffic to loopback;
- validating MuJoCo, ros2_control, the learned locomotion policy, Dex3 interfaces, RViz, IMU data,
  and joint-state updates;
- preparing an engineering roadmap for Gazebo Harmonic and `gz_ros2_control`.

The most useful lesson has been that changing a physics backend is not just changing a launch
command: control interfaces, contact dynamics, sensors, ground truth, TF, and timing all need to be
designed and validated together.

Repository: https://github.com/Ahmed-Bouhachem/Humanoid_ROS2

#ROS2 #Robotics #HumanoidRobotics #UnitreeG1 #MuJoCo #Gazebo #RobotControl #OpenSource

## Editing checklist

- Start with the robot in the first two seconds after the title.
- Remove terminal waiting time and repeated logs.
- Use short callouts such as `ROS 2 Jazzy`, `ros2_control`, `200 Hz`, and `Gazebo next`.
- Keep the simulator audio muted unless it adds useful information.
- Add a final frame with the repository URL long enough to read.
- Watch the complete export once with sound off to confirm the captions tell the story.
