#!/bin/bash
set -euo pipefail
# ===============================================================================
# 脚本名称: ecs_disk_initialize.sh
# 功能: 一键初始化 ECS 数据盘，包括分区创建、文件系统创建及挂载
# 适用环境: Linux 云服务器 (Debian/Ubuntu/CentOS/RHEL/Alibaba Linux 等)
# 支持文件系统: ext4, XFS
# 功能说明:
#   1. 列出未初始化的云盘，用户选择目标云盘
#   2. 创建 GPT 分区（可选择单分区或多分区）
#   3. 刷新分区表，使操作系统识别新分区
#   4. 创建文件系统（ext4 或 XFS）
#   5. 挂载文件系统到指定目录
#   6. 配置开机自动挂载（写入 /etc/fstab）
#   7. 校验分区、文件系统和挂载状态
# 注意事项:
#   - 创建分区或文件系统会清除云盘上所有数据，请确保数据盘为空或已备份
#   - 挂载目录必须为以 / 开头的空路径，否则原有数据将被隐藏
#   - 脚本必须以 root 用户运行
# 使用方法:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/disk_mount.sh)"
# ===============================================================================


# ---------------------- 确认函数 ----------------------
confirm() {
    local prompt="$1"
    read -p "$prompt (y/yes or n/no): " ans
    ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')  # 转小写
    [[ "$ans" == "y" || "$ans" == "yes" ]]
}

# ---------------------- 检查 root ----------------------
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 脚本必须以 root 用户执行"
    exit 1
fi

# ---------------------- 列出未初始化云盘 ----------------------
echo "=== 当前未初始化的云盘 ==="
mapfile -t disks < <(lsblk -d -o NAME,SIZE,TYPE,FSTYPE | awk '$3=="disk" && $4==""{print $1 " " $2}')

if [ ${#disks[@]} -eq 0 ]; then
    echo "[INFO] 没有未初始化的云盘"
    exit 0
fi

for i in "${!disks[@]}"; do
    echo "$((i+1)). ${disks[$i]}"
done

read -p "请输入要初始化的云盘编号: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#disks[@]}" ]; then
    echo "[ERROR] 输入编号无效"
    exit 1
fi

disk_name=$(echo "${disks[$((choice-1))]}" | awk '{print $1}')
target_disk="/dev/$disk_name"
echo "[INFO] 已选择云盘: $target_disk"

# ---------------------- 安装 parted ----------------------
if ! command -v parted &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        apt-get update -y
        apt-get install -y parted
    else
        yum install -y parted
    fi
fi

# ---------------------- 创建 GPT 分区 ----------------------
if confirm "创建 GPT 分区？(将清除所有数据)"; then
    parted "$target_disk" --script mklabel gpt mkpart primary 1MiB 100%
    echo "[INFO] 分区已创建"
fi

# ---------------------- 刷新分区表 ----------------------
partprobe "$target_disk"
sleep 2  # 等待系统识别新分区

# ---------------------- 获取新分区 ----------------------
new_part=$(lsblk -nr -o NAME,TYPE "$target_disk" | awk '$2=="part"{print $1}' | tail -n 1)

if [[ -z "$new_part" ]]; then
    echo "[ERROR] 未检测到分区，请检查磁盘状态"
    exit 1
fi

target_dev="/dev/$new_part"
echo "[INFO] 新分区: $target_dev"

# ---------------------- 创建文件系统 ----------------------
read -p "创建文件系统 (ext4/xfs)? 默认 ext4: " fs_type
fs_type=${fs_type:-ext4}

read -p "卷标 (可选): " label

if [[ "$fs_type" == "ext4" ]]; then
    mkfs_cmd="mkfs.ext4 -F ${label:+-L $label} $target_dev"
elif [[ "$fs_type" == "xfs" ]]; then
    mkfs_cmd="mkfs.xfs ${label:+-L $label} $target_dev"
else
    echo "[ERROR] 不支持的文件系统: $fs_type"
    exit 1
fi

if confirm "确认执行 $mkfs_cmd ?"; then
    eval "$mkfs_cmd"
    echo "[INFO] 文件系统已创建: $fs_type"
fi

# ---------------------- 挂载目录 ----------------------
read -p "请输入挂载目录 (如 /data): " mnt

if [[ -z "$mnt" || "$mnt" != /* ]]; then
    echo "[ERROR] 挂载目录必须是以 / 开头的绝对路径"
    exit 1
fi

mkdir -p "$mnt"

if [ -n "$(ls -A "$mnt")" ]; then
    echo "[ERROR] 挂载目录非空: $mnt"
    exit 1
fi

mount "$target_dev" "$mnt"
echo "[INFO] 挂载完成: $target_dev -> $mnt"

# ---------------------- 配置开机自动挂载 ----------------------
if confirm "是否配置开机自动挂载？"; then
    cp /etc/fstab /etc/fstab.bak
    uuid=$(blkid -s UUID -o value "$target_dev")

    if ! grep -q "$uuid" /etc/fstab; then
        echo "UUID=$uuid $mnt $fs_type defaults 0 0" >> /etc/fstab
        echo "[INFO] 已写入 /etc/fstab"
    else
        echo "[INFO] fstab 已存在该 UUID，跳过写入"
    fi
fi

# ---------------------- 校验 ----------------------
echo "=== 磁盘状态 ==="
lsblk

echo "=== 挂载情况 ==="
df -Th

echo "🎉 云盘初始化完成"