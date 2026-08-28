"""Launch the simulation-only, operator-triggered first-video sequence."""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def _launch(package, name, condition=None, **arguments):
    path = os.path.join(get_package_share_directory(package), "launch", name)
    return IncludeLaunchDescription(
        PythonLaunchDescriptionSource(path),
        condition=condition,
        launch_arguments=arguments.items(),
    )


def generate_launch_description():
    demo_share = get_package_share_directory("g1_demos")
    rviz_config = os.path.join(demo_share, "config", "first_video_demo.rviz")

    return LaunchDescription([
        DeclareLaunchArgument(
            "headless",
            default_value="false",
            description="False opens MuJoCo and RViz for recording; true needs Xvfb.",
        ),
        DeclareLaunchArgument(
            "auto_start",
            default_value="false",
            description="Start after readiness without waiting for /g1_video_demo/start.",
        ),
        DeclareLaunchArgument(
            "rviz",
            default_value="true",
            description="Open the custom recording view; false is useful for headless tests.",
        ),
        DeclareLaunchArgument(
            "speed_scale",
            default_value="1.0",
            description="Scale walking velocity, clamped by the demo to 0.5 through 1.25.",
        ),
        _launch(
            "g1_bringup",
            "bringup.launch.py",
            mode="none",
            nav="false",
            rviz="false",
            moveit="true",
            manipulation="false",
            activate_arm="true",
            activate_arm_delay_s="30.0",
            sensors="true",
            odometry="ground_truth",
            world="navigation",
            headless=LaunchConfiguration("headless"),
            pin_pelvis="false",
        ),
        _launch(
            "g1_moveit_config",
            "moveit_rviz.launch.py",
            condition=IfCondition(LaunchConfiguration("rviz")),
            rviz_config=rviz_config,
        ),
        Node(
            package="g1_demos",
            executable="g1_first_video_demo",
            name="g1_video_demo",
            output="screen",
            parameters=[{
                "auto_start": LaunchConfiguration("auto_start"),
                "speed_scale": LaunchConfiguration("speed_scale"),
            }],
        ),
    ])
