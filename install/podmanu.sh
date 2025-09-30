#!/bin/bash
set -eu

# ===============================================================
# 🚀 Podman 卸载脚本
#
# 👉 支持系统：
#       - macOS (通过 Homebrew 卸载并删除 podman machine)
#       - Ubuntu / Debian
#       - CentOS / RHEL
#       - Fedora
#
# 👉 功能说明：
#       - 卸载 Podman 及相关组件
#       - 停止并禁用 Podman 服务（Linux）
#       - 删除 podman machine（macOS）
#
# 👉 使用方式（直接运行）：
#       curl -o- https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/podmanu.sh | bash
#
# 🧑‍💻 作者：zhiqiang
# ===============================================================

retry() {
    local n=1
    local max=3
    local delay=5
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

stop_disable_podman_service() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "以非 root 用户身份运行，尝试停止并禁用 podman.socket（systemd --user）..."
        systemctl --user stop podman.socket || echo "停止 podman.socket 失败，可能未启动"
        systemctl --user disable podman.socket || echo "禁用 podman.socket 失败"
    else
        echo "检测到 root 用户，跳过 systemd --user 操作。"
    fi
}

uninstall_podman_macos() {
    echo "卸载 Podman (macOS)..."
    if command -v brew >/dev/null 2>&1; then
        echo "使用 Homebrew 卸载 Podman..."
        retry brew uninstall podman
        echo "删除 podman machine（如果存在）..."
        podman machine stop || true
        podman machine rm || true
    else
        echo "未检测到 Homebrew，跳过卸载。"
    fi
}

uninstall_podman_ubuntu_debian() {
    echo "卸载 Podman (Ubuntu/Debian)..."
    retry sudo apt-get remove -y podman
    retry sudo apt-get autoremove -y
}

uninstall_podman_centos_rhel() {
    echo "卸载 Podman (CentOS/RHEL)..."
    retry sudo yum remove -y podman
}

uninstall_podman_fedora() {
    echo "卸载 Podman (Fedora)..."
    retry sudo dnf remove -y podman
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
        uninstall_podman_macos
        ;;
    ubuntu|debian)
        uninstall_podman_ubuntu_debian
        stop_disable_podman_service
        ;;
    centos|rhel)
        uninstall_podman_centos_rhel
        stop_disable_podman_service
        ;;
    fedora)
        uninstall_podman_fedora
        stop_disable_podman_service
        ;;
    *)
        echo "不支持的操作系统：$SYSTEM"
        exit 1
        ;;
esac

echo "Podman 卸载完成！"
