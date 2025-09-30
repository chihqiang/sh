#!/bin/bash
set -eu

# ===============================================================
# 🚀 OpenResty 一键安装脚本（支持 Ubuntu / Debian / CentOS / RHEL）
#
# 👉 使用方式（直接运行）：
#       curl -o- https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main//install/openresty.sh | bash
#
# 📌 作者：zhiqiang
# 📅 更新时间：2025-05-15
# ===============================================================

echo "[*] 正在检测系统..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VER_ID=${VERSION_ID%%.*}
else
    echo "无法识别系统类型"
    exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

echo "[*] 检测结果：$OS_ID $OS_VER_ID ($ARCH)"

import_openresty_gpg() {
    echo "[*] 导入 GPG 公钥..."
    if { [ "$OS_ID" = "ubuntu" ] && [ "$OS_VER_ID" -ge 22 ]; } || \
       { [ "$OS_ID" = "debian" ] && [ "$OS_VER_ID" -ge 12 ]; }; then
        if [ ! -f /etc/apt/trusted.gpg.d/openresty.gpg ]; then
            wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/openresty.gpg
        else
            echo "[i] GPG 公钥已存在，跳过导入"
        fi
    else
        if ! apt-key list 2>/dev/null | grep -q "openresty"; then
            wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
        else
            echo "[i] apt-key 已包含 openresty 公钥"
        fi
    fi
}

install_openresty_ubuntu() {
    echo "[*] 安装依赖..."
    sudo apt-get -y install wget gnupg ca-certificates lsb-release

    import_openresty_gpg

    echo "[*] 添加 APT 源..."
    codename=$(lsb_release -sc)
    list_file="/etc/apt/sources.list.d/openresty.list"

    if [ ! -f "$list_file" ]; then
        if [ "$ARCH" = "arm64" ]; then
            echo "deb http://openresty.org/package/arm64/ubuntu $codename main" | sudo tee "$list_file"
        else
            echo "deb http://openresty.org/package/ubuntu $codename main" | sudo tee "$list_file"
        fi
    else
        echo "[i] openresty.list 已存在，跳过添加"
    fi

    echo "[*] 更新并安装 openresty..."
    sudo apt-get update
    sudo apt-get -y install openresty
}

install_openresty_debian() {
    echo "[*] 安装依赖..."
    sudo apt-get -y install wget gnupg ca-certificates lsb-release

    import_openresty_gpg

    echo "[*] 添加 APT 源..."
    codename=$(grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release)
    list_file="/etc/apt/sources.list.d/openresty.list"

    if [ ! -f "$list_file" ]; then
        if [ "$ARCH" = "arm64" ]; then
            echo "deb http://openresty.org/package/arm64/debian $codename openresty" | sudo tee "$list_file"
        else
            echo "deb http://openresty.org/package/debian $codename openresty" | sudo tee "$list_file"
        fi
    else
        echo "[i] openresty.list 已存在，跳过添加"
    fi

    echo "[*] 更新并安装 openresty..."
    sudo apt-get update
    sudo apt-get -y install openresty
}

install_openresty_centos() {
    echo "[*] 安装 wget 和依赖..."
    sudo yum install -y wget ca-certificates

    repo_file="/etc/yum.repos.d/openresty.repo"

    echo "[*] 添加 OpenResty CentOS 仓库..."
    if [ ! -f "$repo_file" ]; then
        if [ "$OS_VER_ID" -ge 9 ]; then
            echo "[i] 使用 openresty2.repo（CentOS 9+）"
            wget -q https://openresty.org/package/centos/openresty2.repo
        else
            echo "[i] 使用 openresty.repo（CentOS 8 或更早）"
            wget -q https://openresty.org/package/centos/openresty.repo
        fi
        sudo mv openresty*.repo "$repo_file"
    else
        echo "[i] openresty.repo 已存在，跳过添加"
    fi

    echo "[*] 检查更新并安装 OpenResty..."
    sudo yum check-update || true
    sudo yum install -y openresty
}

install_openresty_rhel() {
    echo "[*] 安装 wget 和依赖..."
    sudo yum install -y wget ca-certificates

    repo_file="/etc/yum.repos.d/openresty.repo"

    echo "[*] 添加 OpenResty RHEL 仓库..."
    if [ ! -f "$repo_file" ]; then
        if [ "$OS_VER_ID" -ge 9 ]; then
            echo "[i] 使用 openresty2.repo（RHEL 9+）"
            wget -q https://openresty.org/package/rhel/openresty2.repo
        else
            echo "[i] 使用 openresty.repo（RHEL 8 或更早）"
            wget -q https://openresty.org/package/rhel/openresty.repo
        fi
        sudo mv openresty*.repo "$repo_file"
    else
        echo "[i] openresty.repo 已存在，跳过添加"
    fi

    echo "[*] 检查更新并安装 OpenResty..."
    sudo yum check-update || true
    sudo yum install -y openresty
}

# 执行安装流程
case "$OS_ID" in
    ubuntu)
        install_openresty_ubuntu
        ;;
    debian)
        install_openresty_debian
        ;;
    centos)
        install_openresty_centos
        ;;
    rhel)
        install_openresty_rhel
        ;;
    *)
        echo "[!] 暂不支持您的系统: $OS_ID"
        exit 1
        ;;
esac

echo "[✓] OpenResty 安装完成！"
