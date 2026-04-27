#!/bin/bash
set -euo pipefail
# ===============================================================================
# 脚本名称: disk.sh
# 功能: Linux 磁盘管理工具，支持云盘初始化挂载和云盘扩容
# 适用环境: Linux 云服务器 (Debian/Ubuntu/CentOS/RHEL/Alibaba Linux 等)
# 使用方法:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/disk.sh)"
# ===============================================================================

# ---------------------- 确认函数 ----------------------
confirm() {
    local prompt="$1"
    read -p "$prompt (y/yes or n/no): " ans
    ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
    [[ "$ans" == "y" || "$ans" == "yes" ]]
}

# ---------------------- 检查 root ----------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERROR] 脚本必须以 root 用户执行"
        exit 1
    fi
}

# ===============================================================================
# 分区挂载功能
# ===============================================================================
mount_disk() {
    echo "=== 云盘初始化挂载 ==="

    # 列出未初始化云盘
    echo "当前未初始化的云盘："
    mapfile -t disks < <(lsblk -d -o NAME,SIZE,TYPE,FSTYPE | awk '$3=="disk" && $4==""{print $1 " " $2}')

    if [ ${#disks[@]} -eq 0 ]; then
        echo "[INFO] 没有未初始化的云盘"
        return
    fi

    for i in "${!disks[@]}"; do
        echo "$((i+1)). ${disks[$i]}"
    done

    read -p "请输入要初始化的云盘编号: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#disks[@]}" ]; then
        echo "[ERROR] 输入编号无效"
        return
    fi

    disk_name=$(echo "${disks[$((choice-1))]}" | awk '{print $1}')
    target_disk="/dev/$disk_name"
    echo "[INFO] 已选择云盘: $target_disk"

    # 安装 parted
    if ! command -v parted &>/dev/null; then
        if command -v apt-get &>/dev/null; then
            apt-get update -y
            apt-get install -y parted
        else
            yum install -y parted
        fi
    fi

    # 创建 GPT 分区
    if confirm "创建 GPT 分区？(将清除所有数据)"; then
        parted "$target_disk" --script mklabel gpt mkpart primary 1MiB 100%
        echo "[INFO] 分区已创建"
    fi

    # 刷新分区表
    partprobe "$target_disk"
    sleep 2

    # 获取新分区
    new_part=$(lsblk -nr -o NAME,TYPE "$target_disk" | awk '$2=="part"{print $1}' | tail -n 1)

    if [[ -z "$new_part" ]]; then
        echo "[ERROR] 未检测到分区，请检查磁盘状态"
        return
    fi

    target_dev="/dev/$new_part"
    echo "[INFO] 新分区: $target_dev"

    # 创建文件系统
    read -p "创建文件系统 (ext4/xfs)? 默认 ext4: " fs_type
    fs_type=${fs_type:-ext4}

    read -p "卷标 (可选): " label

    if [[ "$fs_type" == "ext4" ]]; then
        mkfs_cmd="mkfs.ext4 -F ${label:+-L $label} $target_dev"
    elif [[ "$fs_type" == "xfs" ]]; then
        mkfs_cmd="mkfs.xfs ${label:+-L $label} $target_dev"
    else
        echo "[ERROR] 不支持的文件系统: $fs_type"
        return
    fi

    if confirm "确认执行 $mkfs_cmd ?"; then
        eval "$mkfs_cmd"
        echo "[INFO] 文件系统已创建: $fs_type"
    fi

    # 挂载目录
    read -p "请输入挂载目录 (如 /data): " mnt

    if [[ -z "$mnt" || "$mnt" != /* ]]; then
        echo "[ERROR] 挂载目录必须是以 / 开头的绝对路径"
        return
    fi

    mkdir -p "$mnt"

    if [ -n "$(ls -A "$mnt")" ]; then
        echo "[ERROR] 挂载目录非空: $mnt"
        return
    fi

    mount "$target_dev" "$mnt"
    echo "[INFO] 挂载完成: $target_dev -> $mnt"

    # 配置开机自动挂载
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

    # 校验
    echo "=== 磁盘状态 ==="
    lsblk
    echo "=== 挂载情况 ==="
    df -Th
    echo "云盘初始化挂载完成"
}

# ===============================================================================
# 云盘扩容功能
# ===============================================================================
expand_disk() {
    echo "=== 云盘扩容工具 ==="

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
                return 1
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
        total_size=$(lsblk -b -no SIZE "$target_disk")
        echo "[INFO] 预计扩容后容量: $((total_size/1024/1024/1024))G"
    }

    # 判断是否 LVM
    is_lvm() {
        lsblk -no TYPE "$target_dev" | grep -q lvm && return 0 || return 1
    }

    # 扩容分区
    resize_partition() {
        if [[ "$target_dev" =~ [0-9]+$ ]]; then
            disk=$(lsblk -no PKNAME "$target_dev")
            part_num=$(echo "$target_dev" | grep -o '[0-9]\+$')
            LC_ALL=C growpart /dev/$disk $part_num
        fi
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

    install_tools
    select_disk
    get_partition
    show_capacity

    if is_lvm; then
        echo "类型: LVM 扩容"
    else
        echo "类型: 普通分区扩容"
    fi

    read -p "是否确认执行扩容操作？(yes/no): " ans
    if [[ "$ans" != "yes" ]]; then
        echo "[INFO] 操作已取消"
        return
    fi

    resize_partition
    if is_lvm; then
        resize_lvm
    else
        resize_fs
    fi

    echo "=== 扩容后状态 ==="
    lsblk
    df -Th
    echo "云盘扩容完成"
}

# ===============================================================================
# 主菜单
# ===============================================================================
main() {
    check_root

    echo ""
    echo "======================================"
    echo "     Linux 磁盘管理工具"
    echo "======================================"
    echo ""
    echo "请选择操作："
    echo "  1) 初始化挂载云盘"
    echo "  2) 扩容云盘"
    echo "  3) 退出"
    echo ""
    read -p "请输入选项 [1-3]: " option

    case "$option" in
        1)
            mount_disk
            ;;
        2)
            expand_disk
            ;;
        3)
            echo "已退出"
            exit 0
            ;;
        *)
            echo "[ERROR] 无效选项"
            exit 1
            ;;
    esac
}

main
