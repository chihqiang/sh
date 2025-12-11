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
# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 脚本必须以 root 用户执行"
    exit 1
fi

# 1. 列出可用云盘
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

# 2. 安装 parted 工具
if command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y parted
else
    yum install -y parted
fi

# 3. 创建分区 (单分区占满整个盘)
read -p "创建 GPT 分区？(yes/no, 将清除所有数据): " ans
if [[ "$ans" == "yes" ]]; then
    parted "$target_disk" --script mklabel gpt mkpart primary 1MiB 100%
    echo "[INFO] 分区已创建"
fi

# 4. 刷新分区表
partprobe "$target_disk"
# 5. 获取新分区名称
new_part=$(lsblk -n -o NAME "$target_disk" | tail -n 1)
target_dev="/dev/$new_part"
echo "[INFO] 新分区: $target_dev"

# 6. 创建文件系统
read -p "创建文件系统 (ext4/xfs)? 默认 ext4: " fs_type
fs_type=${fs_type:-ext4}
mkfs_cmd="mkfs -t $fs_type $target_dev"
read -p "确认执行 $mkfs_cmd ?(yes/no): " ans
if [[ "$ans" == "yes" ]]; then
    $mkfs_cmd
    echo "[INFO] 文件系统已创建: $fs_type"
fi

# 7. 挂载文件系统
read -p "请输入挂载目录 (如 /data): " mnt
mkdir -p "$mnt"
mount "$target_dev" "$mnt"
echo "[INFO] 挂载完成: $target_dev -> $mnt"

# 8. 配置开机自动挂载
read -p "是否配置开机自动挂载？(yes/no): " ans
if [[ "$ans" == "yes" ]]; then
    cp /etc/fstab /etc/fstab.bak
    uuid=$(blkid -s UUID -o value "$target_dev")
    echo "UUID=$uuid $mnt $fs_type defaults 0 0" >> /etc/fstab
    echo "[INFO] 已写入 /etc/fstab，重启后自动挂载"
fi

# 9. 校验
lsblk
df -Th
echo "🎉 云盘初始化完成"
