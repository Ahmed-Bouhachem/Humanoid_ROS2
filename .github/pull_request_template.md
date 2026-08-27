## What this changes

<!-- One or two sentences. -->

## Native Jazzy checks

Build and run relevant tests directly on Ubuntu 24.04 with ROS 2 Jazzy:

```bash
source scripts/native-env.sh
./scripts/build-native-jazzy.sh
cd workspace
colcon test --packages-select <pkg>
```

- [ ] Ran the relevant native build/tests, or this change cannot affect them.
- [ ] No new publisher on a low-level channel that already has one.
