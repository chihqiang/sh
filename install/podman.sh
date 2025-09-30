#!/bin/bash
set -eu
# ===============================================================
# 🚀 Podman 安装及启动脚本
#
# 👉 支持系统：
#       - macOS (通过 Homebrew 安装并使用 podman machine)
#       - Ubuntu / Debian
#       - CentOS / RHEL
#       - Fedora
#
# 👉 功能说明：
#       - 自动检测操作系统
#       - 根据系统选择合适的安装方式
#       - 支持重试机制，命令失败自动重试3次
#       - macOS 启动 podman machine
#       - Linux 启动 podman.socket（非 root 用户 systemd --user）
#
# 👉 使用方式（直接运行）：
#       curl -o- https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/podman.sh | bash
#
# 🧑‍💻 作者：zhiqiang
# ===============================================================

MAX_RETRIES=3
SLEEP_BETWEEN_RETRIES=5

retry() {
    local n=1
    local max=$MAX_RETRIES
    local delay=$SLEEP_BETWEEN_RETRIES
    local cmd=$*

    until $cmd; do
        if [[ $n -ge $max ]]; then
            echo "❌ 命令执行失败，尝试 $n 次后放弃: $cmd"
            return 1
        else
            echo "⚠️ 命令失败，$delay 秒后重试... ($n/$max): $cmd"
            sleep $delay
            ((n++))
        fi
    done
    echo "✅ 命令成功: $cmd"
}

start_podman() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS 跳过 podman.socket 启动"
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo "启用并启动 podman.socket（rootless systemd）..."
        retry systemctl --user enable podman.socket || echo "启用失败，可能不支持 systemd user"
        retry systemctl --user start podman.socket || echo "启动失败，可能不支持 systemd user"
    else
        echo "检测到 root 用户，跳过 systemd --user 操作，请切换普通用户启动 podman。"
    fi
}

start_podman_macos() {
    echo "初始化并启动 podman machine..."
    if podman machine list | grep -q 'Running'; then
        echo "Podman machine 已经启动"
    else
        retry podman machine init || echo "podman machine 已初始化，跳过"
        retry podman machine start
    fi
    echo "Podman 虚拟机状态："
    podman machine list
}

install_podman_macos() {
    echo "开始安装 Podman (macOS)..."
    if ! command -v brew >/dev/null 2>&1; then
        echo "❌ 未检测到 Homebrew，请先手动安装：https://brew.sh"
        exit 1
    fi
    echo "使用 Homebrew 安装 Podman..."
    retry brew install podman
}

install_podman_ubuntu_debian() {
    echo "开始安装 Podman (Ubuntu/Debian)..."
    retry sudo apt-get update
    retry sudo apt-get install -y podman
}

install_podman_centos_rhel() {
    echo "开始安装 Podman (CentOS/RHEL)..."
    retry sudo yum -y install epel-release
    retry sudo yum -y update
    retry sudo yum -y install podman
}

install_podman_fedora() {
    echo "开始安装 Podman (Fedora)..."
    retry sudo dnf -y update
    retry sudo dnf -y install podman
}

detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

SYSTEM=$(detect_system)
echo "检测到系统: $SYSTEM"

case "$SYSTEM" in
    macos)
        install_podman_macos
        start_podman_macos
        ;;
    ubuntu|debian)
        install_podman_ubuntu_debian
        start_podman
        ;;
    centos|rhel)
        install_podman_centos_rhel
        start_podman
        ;;
    fedora)
        install_podman_fedora
        start_podman
        ;;
    *)
        echo "不支持的操作系统：$SYSTEM"
        exit 1
        ;;
esac

echo "Podman 安装及启动完成！"
