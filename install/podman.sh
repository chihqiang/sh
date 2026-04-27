#!/bin/bash
set -eu

# ===============================================================
# 🚀 Podman 安装/卸载工具
#
# 👉 支持系统：
#       - macOS (通过 Homebrew 安装并使用 podman machine)
#       - Ubuntu / Debian
#       - CentOS / RHEL
#       - Fedora
#
# 👉 功能说明：
#       - 交互式选择安装或卸载
#       - 自动检测操作系统
#       - 支持重试机制
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

# ==================== 安装相关 ====================

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

do_install() {
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

    echo "✅ Podman 安装及启动完成！"
}

# ==================== 卸载相关 ====================

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

do_uninstall() {
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

    echo "✅ Podman 卸载完成！"
}

# ==================== 主流程 ====================

echo "============================================"
echo "       Podman 安装/卸载工具"
echo "============================================"
echo ""
echo "请选择操作："
echo "  1) 安装 Podman"
echo "  2) 卸载 Podman"
echo "  3) 退出"
echo ""

read -p "请输入选项 [1-3]: " choice

case "$choice" in
    1)
        echo ""
        echo "开始安装 Podman..."
        echo ""
        do_install
        ;;
    2)
        echo ""
        echo "开始卸载 Podman..."
        echo ""
        do_uninstall
        ;;
    3)
        echo "已退出"
        exit 0
        ;;
    *)
        echo "无效选项，请输入 1-3"
        exit 1
        ;;
esac
