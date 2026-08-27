#!/usr/bin/env python3
"""Generate the vector plots used by docs/DEEP_LEARNING_MATHEMATICS.md."""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "media" / "math"

BLUE = "#2563eb"
ORANGE = "#ea580c"
GREEN = "#16a34a"
PURPLE = "#9333ea"
GRAY = "#6b7280"
RED = "#dc2626"


def configure() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    matplotlib.rcParams.update(
        {
            "figure.figsize": (8.4, 4.8),
            "figure.dpi": 120,
            "font.size": 11,
            "axes.titlesize": 13,
            "axes.labelsize": 11,
            "axes.grid": True,
            "grid.alpha": 0.25,
            "legend.frameon": False,
            "lines.linewidth": 2.2,
            "svg.hashsalt": "humanoid-ros2-deep-rl-math",
            "svg.fonttype": "none",
        }
    )


def save(fig: plt.Figure, name: str) -> None:
    fig.tight_layout()
    path = OUTPUT / name
    fig.savefig(path, format="svg", bbox_inches="tight", metadata={"Date": None})
    plt.close(fig)
    # Matplotlib writes trailing spaces inside multiline SVG path data. They are not meaningful,
    # so remove them to keep `git diff --check` useful for the generated assets too.
    clean_svg = "\n".join(line.rstrip() for line in path.read_text().splitlines()) + "\n"
    path.write_text(clean_svg)


def activation_functions() -> None:
    x = np.linspace(-4.0, 4.0, 800)
    elu = np.where(x > 0.0, x, np.exp(x) - 1.0)
    relu = np.maximum(0.0, x)
    tanh = np.tanh(x)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
    axes[0].plot(x, elu, color=BLUE, label="ELU (deployed)")
    axes[0].plot(x, relu, color=ORANGE, linestyle="--", label="ReLU")
    axes[0].plot(x, tanh, color=GREEN, linestyle=":", label="tanh")
    axes[0].axhline(0.0, color="black", linewidth=0.8)
    axes[0].axvline(0.0, color="black", linewidth=0.8)
    axes[0].set(title="Activation functions", xlabel="pre-activation z", ylabel="activation f(z)")
    axes[0].legend()

    elu_grad = np.where(x > 0.0, 1.0, np.exp(x))
    relu_grad = np.where(x > 0.0, 1.0, 0.0)
    tanh_grad = 1.0 - tanh**2
    axes[1].plot(x, elu_grad, color=BLUE, label="ELU derivative")
    axes[1].plot(x, relu_grad, color=ORANGE, linestyle="--", label="ReLU derivative")
    axes[1].plot(x, tanh_grad, color=GREEN, linestyle=":", label="tanh derivative")
    axes[1].set(title="Gradients used by backpropagation", xlabel="z", ylabel="df(z) / dz")
    axes[1].legend()
    save(fig, "activation_functions.svg")


def gaussian_policy() -> None:
    x = np.linspace(-3.0, 3.0, 900)
    fig, ax = plt.subplots()
    for sigma, color in ((0.35, BLUE), (0.70, ORANGE), (1.20, GREEN)):
        density = np.exp(-0.5 * (x / sigma) ** 2) / (sigma * np.sqrt(2.0 * np.pi))
        ax.plot(x, density, color=color, label=rf"$\mu=0,\ \sigma={sigma:.2f}$")
    ax.axvline(0.0, color="black", linewidth=0.8)
    ax.set(
        title="Gaussian action policy: standard deviation controls exploration",
        xlabel="one action dimension a",
        ylabel="probability density",
    )
    ax.legend()
    save(fig, "gaussian_policy.svg")


def discount_and_gae() -> None:
    steps = np.arange(0, 101)
    gamma_values = (0.90, 0.95, 0.99)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
    for gamma, color in zip(gamma_values, (ORANGE, GREEN, BLUE)):
        axes[0].plot(steps, gamma**steps, color=color, label=rf"$\gamma={gamma}$")
    axes[0].set(
        title="Discount weight on a future reward",
        xlabel="future steps k",
        ylabel=r"weight $\gamma^k$",
        ylim=(-0.02, 1.03),
    )
    axes[0].legend()

    lag = np.arange(0, 41)
    gamma = 0.99
    for lam, color in zip((0.80, 0.90, 0.95, 1.00), (PURPLE, ORANGE, GREEN, BLUE)):
        axes[1].plot(lag, (gamma * lam) ** lag, color=color, label=rf"$\lambda={lam:.2f}$")
    axes[1].set(
        title=r"GAE weighting with $\gamma=0.99$",
        xlabel="TD-residual lag l",
        ylabel=r"weight $(\gamma\lambda)^l$",
        ylim=(-0.02, 1.03),
    )
    axes[1].legend()
    save(fig, "discount_and_gae.svg")


def ppo_clipping() -> None:
    ratio = np.linspace(0.4, 1.6, 900)
    epsilon = 0.2
    clipped_ratio = np.clip(ratio, 1.0 - epsilon, 1.0 + epsilon)
    positive = np.minimum(ratio, clipped_ratio)
    negative = np.minimum(-ratio, -clipped_ratio)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2), sharex=True)
    axes[0].plot(ratio, ratio, color=GRAY, linestyle="--", label=r"unclipped $\rho A$")
    axes[0].plot(ratio, positive, color=BLUE, label=r"PPO objective, $A=+1$")
    axes[0].axvspan(1.2, 1.6, color=BLUE, alpha=0.09)
    axes[0].set(title="Positive advantage", xlabel=r"probability ratio $\rho$", ylabel="surrogate value")
    axes[0].legend()

    axes[1].plot(ratio, -ratio, color=GRAY, linestyle="--", label=r"unclipped $\rho A$")
    axes[1].plot(ratio, negative, color=RED, label=r"PPO objective, $A=-1$")
    axes[1].axvspan(0.4, 0.8, color=RED, alpha=0.09)
    axes[1].set(title="Negative advantage", xlabel=r"probability ratio $\rho$", ylabel="surrogate value")
    axes[1].legend()
    for ax in axes:
        ax.axvline(0.8, color="black", linewidth=0.8, linestyle=":")
        ax.axvline(1.2, color="black", linewidth=0.8, linestyle=":")
    save(fig, "ppo_clipping.svg")


def tracking_reward() -> None:
    error = np.linspace(-1.5, 1.5, 900)
    fig, ax = plt.subplots()
    for sigma, color in ((0.25, RED), (0.50, ORANGE), (1.00, BLUE)):
        reward = np.exp(-(error**2) / sigma**2)
        ax.plot(error, reward, color=color, label=rf"$\sigma={sigma:.2f}$")
    ax.set(
        title=r"Exponential tracking reward $\exp(-e^2/\sigma^2)$",
        xlabel="tracking error e",
        ylabel="reward",
        ylim=(-0.02, 1.03),
    )
    ax.legend(title="reward width")
    save(fig, "tracking_reward.svg")


def pd_response() -> None:
    position_error = np.linspace(-0.5, 0.5, 500)
    joint_velocity = np.linspace(-2.0, 2.0, 500)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
    for kp, color in ((20.0, GREEN), (40.0, ORANGE), (80.0, BLUE)):
        axes[0].plot(position_error, kp * position_error, color=color, label=rf"$K_p={kp:.0f}$")
    axes[0].set(title="Proportional correction", xlabel=r"position error $q^*-q$ [rad]", ylabel="torque term [Nm]")
    axes[0].legend()

    for kd, color in ((0.5, GREEN), (2.0, ORANGE), (5.0, BLUE)):
        axes[1].plot(joint_velocity, -kd * joint_velocity, color=color, label=rf"$K_d={kd:.1f}$")
    axes[1].set(title="Derivative damping", xlabel=r"joint velocity $\dot q$ [rad/s]", ylabel="torque term [Nm]")
    axes[1].legend()
    save(fig, "pd_response.svg")


def gradient_descent() -> None:
    theta = np.linspace(-1.0, 5.0, 700)
    loss = (theta - 2.0) ** 2 + 0.5
    learning_rate = 0.18
    path = [-0.5]
    for _ in range(8):
        gradient = 2.0 * (path[-1] - 2.0)
        path.append(path[-1] - learning_rate * gradient)
    path_array = np.asarray(path)
    path_loss = (path_array - 2.0) ** 2 + 0.5

    fig, ax = plt.subplots()
    ax.plot(theta, loss, color=BLUE, label=r"$L(\theta)=(\theta-2)^2+0.5$")
    ax.plot(path_array, path_loss, "o-", color=RED, markersize=5, label="gradient-descent updates")
    for index, (x_value, y_value) in enumerate(zip(path_array, path_loss)):
        ax.annotate(str(index), (x_value, y_value), xytext=(4, 5), textcoords="offset points", fontsize=8)
    ax.set(title="Gradient descent moves parameters toward lower loss", xlabel=r"parameter $\theta$", ylabel=r"loss $L(\theta)$")
    ax.legend()
    save(fig, "gradient_descent.svg")


def main() -> None:
    configure()
    activation_functions()
    gaussian_policy()
    discount_and_gae()
    ppo_clipping()
    tracking_reward()
    pd_response()
    gradient_descent()
    print(f"Generated 7 SVG figures in {OUTPUT}")


if __name__ == "__main__":
    main()
