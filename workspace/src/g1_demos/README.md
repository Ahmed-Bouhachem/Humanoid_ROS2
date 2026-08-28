# g1_demos

Repeatable demonstrations built for this ROS 2 Jazzy learning repository. These are not robot
drivers: they coordinate existing locomotion, MoveIt, controller, and sensor interfaces.

## First-video demo

`first_video_demo.launch.py` creates one recording view containing:

- the MuJoCo G1 walking under the learned locomotion policy;
- MoveIt arm planning and trajectory trails;
- Dex3 hand open/close motion;
- live LiDAR and RGB-D point clouds;
- IMU uprightness, odometry, walking path, and chapter labels.

The launch forces simulation sensors, exact MuJoCo odometry, an unpinned pelvis, MoveIt, and the
loopback-only Unitree DDS profile. The sequence will not command motion until all of those sources
and the locomotion, arm, and hand controllers are healthy.

```bash
./scripts/first-video-demo.sh
```

When RViz says `READY TO RECORD`, start the recorder and press Enter in the launch terminal. The
wrapper triggers the one-shot sequence from inside its isolated network namespace.

See [`docs/FIRST_VIDEO_DEMO.md`](../../../docs/FIRST_VIDEO_DEMO.md) for the complete recording and
narration guide.

## Safety boundary

This demo is intentionally simulation-only. The repository wrapper creates an operating-system
network namespace with only `lo`. The node also requires `/g1_sensor_relay/base_state`, which comes
from MuJoCo, and independently refuses to run unless `CYCLONEDDS_URI` selects the explicit loopback
interface. Do not reuse the launch file directly on a physical G1.
