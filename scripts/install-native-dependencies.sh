#!/usr/bin/env bash

set -euo pipefail

if [[ "$(. /etc/os-release && printf '%s' "${VERSION_ID}")" != "24.04" ]]; then
    echo "Warning: this dependency list targets Ubuntu 24.04 and ROS 2 Jazzy." >&2
fi

sudo apt-get update
sudo apt-get install -y \
    build-essential cmake curl git python3-colcon-common-extensions python3-rosdep python3-vcstool \
    libapr1-dev libaprutil1-dev libboost-all-dev libeigen3-dev libfmt-dev libglfw3-dev \
    libpcl-dev libspdlog-dev libyaml-cpp-dev liburdfdom-tools nlohmann-json3-dev xvfb \
    ros-jazzy-ament-cmake-gmock ros-jazzy-ament-cmake-pytest \
    ros-jazzy-behaviortree-cpp ros-jazzy-launch-testing ros-jazzy-launch-testing-ament-cmake \
    ros-jazzy-moveit ros-jazzy-moveit-configs-utils ros-jazzy-moveit-ros-perception \
    ros-jazzy-navigation2 ros-jazzy-nav2-bringup ros-jazzy-pick-ik \
    ros-jazzy-pointcloud-to-laserscan ros-jazzy-realsense2-description \
    ros-jazzy-realtime-tools ros-jazzy-ros2-control ros-jazzy-ros2-controllers \
    ros-jazzy-slam-toolbox ros-jazzy-teleop-twist-keyboard ros-jazzy-vision-msgs \
    ros-jazzy-xacro

