# Development notes

An operational reference for running this stack inside the development container: the commands
that work, and the behaviours that make a correct-looking command appear to do nothing. Scope is
the container and the workflow, not the robot stack itself, which is documented per package.

## Running anything: go through `manage.sh`

`docker-compose.yml` resolves the base image from `ROS_DISTRO`, and Docker Compose gives the
**shell environment precedence over `.env`**. A host with ROS installed usually exports
`ROS_DISTRO` from its own `setup.bash`, so a direct Compose call silently builds against the
wrong distro:

```
E: Unable to locate package ros-humble-launch-testing
E: Unable to locate package ros-humble-ros2-control
```

Every `ros-humble-*` package missing at once means the base resolved to a non-Humble image, not
that the package list is wrong. `scripts/manage.sh` sources `.env` with `set -a` before calling
Compose precisely so the file wins, which is why it is the supported entry point.

```bash
./scripts/manage.sh start        # build the image and start the container
./scripts/manage.sh exec         # shell in as root
./scripts/manage.sh exec-as-me   # shell in as your host UID/GID
./scripts/manage.sh recreate     # down, rebuild, up
```

To use Compose directly anyway, load `.env` first:

```bash
set -a; . ./.env; set +a
docker compose config | grep BASE_IMAGE   # expect adyansh04/ros-dev:humble-latest
```

## First run

On the host, from the repository root:

```bash
cp .env.example .env
./scripts/import-externals.sh
./scripts/manage.sh start
./scripts/manage.sh exec
```

`import-externals.sh` is not optional and is idempotent. It imports `workspace.repos`, rewrites
`livox_ros_driver2` into a buildable ROS 2 layout, ignores `open3d_loc`, and patches two
FAST-LIO constants. Re-run it whenever `workspace.repos` changes.

Then, inside the container:

```bash
source /opt/ros/humble/setup.bash
cd /root/workspace
colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

A clean build produces 19 packages. Remaining stderr is warnings only, chiefly CMake notices
about `liboctomap` and `liburdfdom` runtime search paths.

**Optional.** `unitree_ros2_example` builds fine but is unused and costs about 75 s of build
time. To skip it:

```bash
touch workspace/src/unitree_ros2/example/COLCON_IGNORE
```

## Driving the base by hand

`g1_locomotion/README.md` is the reference for the authority state machine and the gait shaper.
What follows is the shortest working path for a manual velocity test, plus the three behaviours
that make an otherwise correct command do nothing.

**Authority must be held first.** The bridge discards velocity unless it holds locomotion
authority. Two goals acquire it:

```bash
ros2 action send_goal /g1_loco_bridge/set_mode g1_msgs/action/SetLocoMode "{fsm_id: 4}"    # StandUp
ros2 action send_goal /g1_loco_bridge/set_mode g1_msgs/action/SetLocoMode "{fsm_id: 500}"  # Start
```

Success shows on `/g1_loco_bridge/status` as `fsm_id: 500` and `authority: 2` (HELD). Before
that, published velocity produces only a throttled `Discarding cmd_vel: locomotion authority is
0, not HELD`, and the dropped samples are counted in the status message's `ignored_cmd_vel`.

**Publish repeatedly, not once.** `cmd_vel_timeout_ms` is 500, so the velocity gate treats an
older sample as stale, sends a single `SetVelocity(0,0,0)` and idles. A `--once` publish yields
about half a second of walking:

```bash
ros2 topic pub -r 10 /g1_loco_bridge/cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.6}}"
```

Measured: five seconds at a commanded 0.6 m/s moved the base 3.25 m, about 0.65 m/s.

**Commands must clear the policy dead zone.** The simulated walking policy has a hard gait
initiation threshold, measured at roughly 0.40 m/s forward, 0.50 m/s lateral and 1.50 rad/s yaw.
Anything under it stands still rather than stepping. The bridge clamps every sample to
`max_velocity: [0.8, 0.5, 1.57]`, which is a property of this policy, not a hardware safe
default.

| Motion | Command |
|---|---|
| Forward | `"{linear: {x: 0.6}}"` |
| Turn in place | `"{angular: {z: 1.5}}"` |
| Strafe | `"{linear: {y: 0.5}}"` |
| Reverse | `"{linear: {x: -0.6}}"`, which yields only about -0.25 m/s |

Command one axis at a time. The measured response to a mixed command is poor, which is why
`g1_gait_shaper` collapses any input onto a single primitive.

### Keyboard teleop

`teleop_twist_keyboard` is installed in the image and works with a remap:

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard \
  --ros-args -r cmd_vel:=/g1_loco_bridge/cmd_vel -p speed:=0.6 -p turn:=1.6
```

Set both parameters. The node's defaults are `speed` 0.5 and `turn` 1.0, and that default turn
rate sits below the 1.50 rad/s threshold, so turning silently does nothing. The node also
publishes once per key event with no repeat timer, so a single tap buys roughly half a second of
motion before the stale timeout zeroes it. Hold the key and let terminal auto-repeat provide the
rate.

**Caveat.** Under `nav:=true` the gait shaper owns `/g1_loco_bridge/cmd_vel` and
`g1_loco_authority` performs both transitions itself, so none of the above is needed and
publishing by hand competes with Nav2. The manual path applies to a bare `sim.launch.py` or
`bringup.launch.py` session, where no other publisher is present.

## Seeing the MuJoCo window

`bringup.launch.py` declares `headless` with a default of `true`. In that mode `sim.launch.py`
starts its own Xvfb on display `:133` and points the simulator at it, so the viewer renders into
a virtual framebuffer nothing is attached to. There is no separate client process to start:
unlike Gazebo, `unitree_mujoco` is a single binary with the viewer compiled in.

```bash
ros2 launch g1_bringup bringup.launch.py headless:=false
```

The X11 plumbing is already in place: `manage.sh start` runs `xhost +local:docker`,
`docker-compose.yml` bind-mounts `/tmp/.X11-unix` and passes `DISPLAY` through. A headless run is
identifiable from inside the container by both `X1` and `X133` existing under `/tmp/.X11-unix/`.

**Caution.** The viewer's Reload button is fatal when sensors are enabled.

## When `ros2 topic list` shows only `/parameter_events` and `/rosout`

A second shell opened with `manage.sh exec` while the stack runs can report an almost empty
graph. It did not attach to a different container: `docker compose exec` shares the running
container's PID and network namespaces.

The stale view comes from the ROS 2 CLI daemon, a per-domain background process that caches the
discovery graph and answers CLI queries from that cache. CycloneDDS is pinned to loopback here,
which is not multicast-capable, so discovery is unicast and a daemon that started before the
stack came up can hold a view it never refreshes.

```bash
ros2 topic list --no-daemon   # if this shows the graph, nothing is wrong with the stack
ros2 daemon stop              # then let the next CLI call restart it
```

## Standing notes

- Builds run as root inside the container, so `workspace/build`, `workspace/install` and
  `workspace/log` end up root-owned on the host. All three are gitignored. Clearing them needs
  either `sudo` on the host or a `rm -rf` from inside the container. Use `manage.sh exec-as-me`
  for tools that rewrite sources in place, such as `clang-tidy --fix` and `clang-format -i`.
- `workspace/src/unitree_ros2/`, `livox_ros_driver2/` and `fast_lio_humanoid/` are gitignored by
  design. They are reproduced from `workspace.repos` rather than tracked, so a clean
  `git status` after the import is the expected state.
- `manage.sh exec` attaches to the running container, not a new one. When a second shell appears
  to see a different ROS graph, suspect the CLI daemon before the container.
- A Dockerfile edit above the final block invalidates the cached `unitree_mujoco` build layer.
  That layer sits last on purpose to keep routine patch and sensor edits cheap, so expect one
  rebuild of it after any change higher in the file.
