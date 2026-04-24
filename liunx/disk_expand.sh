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


echo "=== 云盘扩容工具（交互版） ==="

# root 检查
if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] 请使用 root 运行"
  exit 1
fi

# 安装工具
install_tools() {
  source /etc/os-release
  case "$ID" in
    ubuntu|debian)
      apt-get update -y
      apt-get install -y cloud-guest-utils gdisk xfsprogs lvm2
      ;;
    centos|rhel|almalinux|rocky|aliyun)
      yum install -y cloud-utils-growpart gdisk xfsprogs lvm2
      ;;
    *)
      echo "[ERROR] 不支持的系统: $ID"
      exit 1
      ;;
  esac
}

# 获取系统盘
get_root_disk() {
  df / | tail -1 | awk '{print $1}' | xargs lsblk -no PKNAME
}

# 选择磁盘
select_disk() {
  root_disk=$(get_root_disk)
  mapfile -t disks < <(lsblk -dn -o NAME,SIZE)

  echo "=== 磁盘列表 ==="
  for i in "${!disks[@]}"; do
    echo "$((i+1)). ${disks[$i]}"
  done

  read -p "请选择磁盘编号: " idx
  name=$(echo "${disks[$((idx-1))]}" | awk '{print $1}')

  if [[ "$name" == "$root_disk" ]]; then
    echo "[WARN] 你选择的是系统盘，请谨慎操作"
  fi

  target_disk="/dev/$name"
  echo "[INFO] 已选择: $target_disk"
}

# 获取分区
get_partition() {
  mapfile -t parts < <(lsblk -nr -o NAME "$target_disk" | tail -n +2)

  if [[ ${#parts[@]} -gt 0 ]]; then
    last_part="${parts[${#parts[@]}-1]}"
    target_dev="/dev/$last_part"
  else
    target_dev="$target_disk"
  fi

  echo "[INFO] 目标设备: $target_dev"
}

# 显示扩容前后容量对比
show_capacity() {
  current_size=$(lsblk -b -no SIZE "$target_dev")
  echo "[INFO] 当前设备容量: $((current_size/1024/1024/1024))G"
  # 预计扩容后容量（取磁盘总大小）
  total_size=$(lsblk -b -no SIZE "$target_disk")
  echo "[INFO] 预计扩容后容量: $((total_size/1024/1024/1024))G"
}

# 执行前确认
confirm_action() {
  show_capacity
  if is_lvm; then
    echo "类型: LVM 扩容（PV/VG/LV + 文件系统）"
  else
    echo "类型: 普通分区扩容（分区 + 文件系统）"
  fi
  read -p "是否确认执行扩容操作？(yes/no): " ans
  if [[ "$ans" != "yes" ]]; then
    echo "[INFO] 操作已取消"
    exit 1
  fi
}

# 扩容分区
resize_partition() {
  if [[ "$target_dev" =~ [0-9]+$ ]]; then
    disk=$(lsblk -no PKNAME "$target_dev")
    part_num=$(echo "$target_dev" | grep -o '[0-9]\+$')
    LC_ALL=C growpart /dev/$disk $part_num
  fi
}

# 判断是否 LVM
is_lvm() {
  lsblk -no TYPE "$target_dev" | grep -q lvm && return 0 || return 1
}

# 扩容 LVM
resize_lvm() {
  pv=$(pvs --noheadings -o pv_name | grep "$target_dev" || true)

  if [[ -z "$pv" ]]; then
    pvcreate $target_dev
  fi

  vg=$(vgs --noheadings -o vg_name | head -1 | xargs)
  lv=$(lvs --noheadings -o lv_path | head -1 | xargs)

  echo "[INFO] VG: $vg | LV: $lv"

  vgextend $vg $target_dev || true
  lvextend -l +100%FREE $lv
  resize_fs "$lv"
}

# 扩容文件系统
resize_fs() {
  dev=${1:-$target_dev}
  fs=$(lsblk -no FSTYPE "$dev")
  mnt=$(lsblk -no MOUNTPOINT "$dev")

  echo "[INFO] 文件系统类型: $fs"
  case "$fs" in
    ext2|ext3|ext4)
      resize2fs $dev
      ;;
    xfs)
      xfs_growfs $mnt
      ;;
    *)
      echo "[WARN] 不支持的文件系统"
      ;;
  esac
}

# 主流程
install_tools
select_disk
get_partition
confirm_action
resize_partition
if is_lvm; then
  resize_lvm
else
  resize_fs
fi

lsblk
df -Th

echo "✔ 扩容完成"