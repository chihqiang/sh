#!/bin/bash
set -eu
# ===============================================================
# 🚀 OpenResty 卸载脚本
#
# 👉 支持系统：
#       - Ubuntu / Debian
#       - CentOS / RHEL

# 👉 使用方式（直接运行）：
#       curl -o- https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/openrestyu.sh | bash
#
# ✨ 功能说明：
#       - 卸载 OpenResty 及相关组件
#       - 删除 APT / YUM 源配置
#       - 清理 GPG 公钥
#       - 停止并禁用 OpenResty 服务
#
# 🧑‍💻 作者：zhiqiang
# ===============================================================

echo "[*] 正在检测系统..."

# 加载 /etc/os-release 获取系统信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID                          # 如 ubuntu、debian、centos、rhel
    OS_VER_ID=${VERSION_ID%%.*}       # 获取主版本号（如 "22.04" -> "22"）
else
    echo "无法识别系统类型"
    exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

echo "[*] 检测结果：$OS_ID $OS_VER_ID ($ARCH)"

# Debian/Ubuntu 卸载逻辑
uninstall_openresty_debian_ubuntu() {
    echo "[*] 停止并禁用 OpenResty 服务..."
    sudo systemctl stop openresty.service || true
    sudo systemctl disable openresty.service || true

    echo "[*] 卸载 OpenResty 及其组件..."
    sudo apt-get remove --purge -y openresty openresty-resty || true
    sudo apt-get autoremove -y

    echo "[*] 移除 OpenResty APT 源..."
    sudo rm -f /etc/apt/sources.list.d/openresty.list

    echo "[*] 移除 GPG 公钥..."
    # 删除 apt-key 中的 openresty 公钥（兼容旧系统）
    if command -v apt-key >/dev/null 2>&1; then
        KEY_ID=$(apt-key list 2>/dev/null | grep -B1 'openresty' | head -n1 | awk '{print $2}')
        if [ -n "$KEY_ID" ]; then
            sudo apt-key del "$KEY_ID" || true
        fi
    fi

    # 删除 trusted.gpg.d 中的 gpg 文件
    sudo rm -f /etc/apt/trusted.gpg.d/openresty.gpg || true
    sudo find /etc/apt/trusted.gpg.d/ -name "*openresty*" -exec rm -f {} \;

    echo "[*] 更新 APT 索引..."
    sudo apt-get update
}

# CentOS/RHEL 卸载逻辑
uninstall_openresty_centos_rhel() {
    echo "[*] 停止并禁用 OpenResty 服务..."
    sudo systemctl stop openresty.service || true
    sudo systemctl disable openresty.service || true

    echo "[*] 卸载 OpenResty..."
    sudo yum remove -y openresty openresty-resty || true

    echo "[*] 移除 OpenResty YUM 源..."
    sudo rm -f /etc/yum.repos.d/openresty.repo
    sudo rm -f /etc/yum.repos.d/openresty2.repo

    echo "[*] 清理缓存..."
    sudo yum clean all
}

# 根据系统类型执行对应逻辑
case "$OS_ID" in
    ubuntu|debian)
        uninstall_openresty_debian_ubuntu
        ;;
    centos|rhel)
        uninstall_openresty_centos_rhel
        ;;
    *)
        echo "[!] 暂不支持您的系统: $OS_ID"
        exit 1
        ;;
esac

echo "[✓] OpenResty 卸载完成！"
