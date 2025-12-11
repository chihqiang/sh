#!/bin/bash
set -euo pipefail
# ===============================================================================
# 脚本名称: disk_expand.sh
# 功能: 一键交互式云盘扩容脚本
# 适用环境: Linux 云服务器 (Debian/Ubuntu/CentOS/RHEL/Alibaba Linux 等)
# 支持文件系统: ext2, ext3, ext4, XFS
# 功能说明:
#   1. 自动安装扩容所需工具 (growpart, gdisk)
#   2. 列出可扩容的云盘，并允许用户选择
#   3. 自动检测最后一个分区并扩容（如果存在分区）
#   4. 自动检测文件系统类型并扩容文件系统
#   5. 校验并显示最终分区及文件系统大小
# 使用方法:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/disk_expand.sh)"
# 注意事项:
#   - 仅支持扩容最后一个分区
#   - 系统盘扩容请提前备份重要数据
#   - 扩容过程需确保云盘容量已在控制台增加
# ===============================================================================
# =========================
# 工具安装
# =========================

# =========================
# 检查是否为 root
# =========================
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 脚本必须以 root 用户执行"
    exit 1
fi

install_tools() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_NAME=$NAME
    else
        echo "[ERROR] 无法检测操作系统类型，脚本无法继续执行。"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian)
            echo "[INFO] 检测到 Debian/Ubuntu 系列，开始安装工具..."
            apt-get update -y
            apt-get install -y cloud-guest-utils gdisk
            ;;
        centos|rhel|almalinux|rocky|aliyun)
            echo "[INFO] 检测到 CentOS/RHEL/Alibaba Linux 系列，开始安装工具..."
            yum install -y cloud-utils-growpart gdisk
            yum update cloud-utils-growpart
            ;;
        *)
            echo "[ERROR] 未识别操作系统 $OS_NAME ($OS_ID)，脚本无法继续执行。"
            exit 1
            ;;
    esac

    echo "[INFO] 扩容工具安装完成"
}

# =========================
# 列出可扩容云盘并选择
# =========================
choose_disk() {
    echo "=== 当前可用云盘列表 ==="
    mapfile -t disks < <(lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | awk '$3=="disk"{print $1 " " $2 " " $4}')
    if [ ${#disks[@]} -eq 0 ]; then
        echo "[ERROR] 未检测到可用云盘"
        exit 1
    fi

    for i in "${!disks[@]}"; do
        echo "$((i+1)). ${disks[$i]}"
    done

    read -p "请输入要扩容的云盘编号: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#disks[@]}" ]; then
        echo "[ERROR] 输入编号无效"
        exit 1
    fi

    disk_name=$(echo "${disks[$((choice-1))]}" | awk '{print $1}')
    target_disk="/dev/$disk_name"
    echo "[INFO] 已选择云盘: $target_disk"

    # 判断是否有分区
    parts=($(lsblk -n -o NAME /dev/$disk_name | grep -E "^$disk_name[0-9]+|^$disk_name" | tail -n +2))
    if [ ${#parts[@]} -gt 0 ]; then
        part="${parts[-1]}"
        target_dev="/dev/$part"
        echo "[INFO] 存在分区，目标设备为最后一个分区: $target_dev"
    else
        target_dev="$target_disk"
        echo "[INFO] 无分区，目标设备为: $target_dev"
    fi

    # 获取文件系统类型和挂载点
    fs_type=$(lsblk -no FSTYPE "$target_dev")
    mnt=$(lsblk -no MOUNTPOINT "$target_dev")
    echo "[INFO] 文件系统: $fs_type, 挂载点: ${mnt:-未挂载}"
}

# =========================
# 分区扩容
# =========================
resize_partition() {
    if [[ "$target_dev" =~ [0-9]+$ ]]; then
        part_num=$(echo "$target_dev" | grep -o '[0-9]\+$')
        disk_name=$(lsblk -no pkname "$target_dev")
        read -p "执行 growpart /dev/$disk_name $part_num 扩容分区吗？(yes/no): " ans
        if [[ "$ans" == "yes" ]]; then
            LC_ALL=en_US.UTF-8 growpart "/dev/$disk_name" "$part_num"
            echo "[INFO] 分区扩容完成"
        else
            echo "[INFO] 分区扩容已取消"
        fi
    else
        echo "[INFO] 无需扩容分区"
    fi
}

# =========================
# 文件系统扩容
# =========================
resize_filesystem() {
    if [[ "$fs_type" =~ ext[234]? ]]; then
        read -p "执行 resize2fs $target_dev 扩容文件系统吗？(yes/no): " ans
        if [[ "$ans" == "yes" ]]; then
            resize2fs "$target_dev"
            echo "[INFO] ext 文件系统扩容完成"
        else
            echo "[INFO] 文件系统扩容已取消"
        fi
    elif [[ "$fs_type" == "xfs" ]]; then
        if [ -z "$mnt" ]; then
            echo "[WARN] XFS 文件系统未挂载，请挂载后手动执行 xfs_growfs"
        else
            read -p "执行 xfs_growfs $mnt 扩容文件系统吗？(yes/no): " ans
            if [[ "$ans" == "yes" ]]; then
                xfs_growfs "$mnt"
                echo "[INFO] XFS 文件系统扩容完成"
            else
                echo "[INFO] 文件系统扩容已取消"
            fi
        fi
    else
        echo "[WARN] 无法识别文件系统类型，请手动扩容"
    fi
}

# =========================
# 校验结果
# =========================
check_result() {
    echo "=== 分区信息 ==="
    lsblk
    echo "=== 文件系统大小 ==="
    df -Th
}

# =========================
# 主流程
# =========================
echo "=== 云盘扩容脚本 ==="
read -p "是否继续操作？(yes/no): " ans
[[ "$ans" == "yes" ]] || { echo "操作已取消"; exit 1; }
install_tools
choose_disk
resize_partition
resize_filesystem
check_result
echo "🎉 云盘扩容完成"