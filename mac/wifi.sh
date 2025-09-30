#!/bin/bash

# Wi-Fi 管理脚本（macOS）
# 功能：
#   1. 列出当前系统保存的所有 Wi-Fi 网络（SSID）
#   2. 支持查看指定 Wi-Fi 的密码（需要钥匙串授权）
#   3. 支持删除指定的保存的 Wi-Fi 配置
#   4. 交互式操作，用户输入编号查看密码或删除，支持退出
#
# 使用说明：
#   - 请确保脚本用 bash 执行（macOS 默认 bash 版本可能较旧，建议使用 /bin/bash）
#   - 根据你的无线设备名修改变量 DEVICE（常见为 en0，可用 `networksetup -listallhardwareports` 查看）
#   - 查看密码时可能弹出钥匙串访问授权弹窗，需允许访问
#
# 运行示例：
#   1. 直接通过 curl 一键执行脚本（默认使用设备 en0）：
#      bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/wifi.sh)"
#
#   2. 指定无线设备（比如 en1）运行脚本：
#      DEVICE=en1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/wifi.sh)"
#
#   3. 或者下载脚本后再执行，方便调试修改：
#      curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/wifi.sh -o wifi.sh
#      chmod +x wifi.sh
#      ./wifi.sh
#
# 注意事项：
#   - 脚本涉及钥匙串访问权限，执行时可能会弹窗，需允许
#   - 某些操作可能需要管理员权限，视系统提示操作


# 需要根据你的实际 Wi-Fi 设备名修改，常见为 en0
DEVICE="${DEVICE:-en0}"

# 获取所有保存的 Wi-Fi 名称列表（去除第一行标题）
get_wifi_list() {
    networksetup -listpreferredwirelessnetworks "$DEVICE" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//'
}

# 根据 Wi-Fi 名称显示对应密码
show_password() {
    local ssid="$1"
    echo "🔍 Wi-Fi [$ssid] 密码:"
    # security 命令会弹钥匙串授权弹窗，grep 提取密码行
    security find-generic-password -ga "$ssid" 2>&1 | grep "password:" || echo "❌ 无权限或无记录"
}

# 根据 Wi-Fi 名称删除保存的网络配置
delete_wifi() {
    local ssid="$1"
    echo "⚠️ 删除 Wi-Fi 网络 [$ssid]"
    networksetup -removepreferredwirelessnetwork "$DEVICE" "$ssid"
    if [ $? -eq 0 ]; then
        echo "✅ 删除成功"
    else
        echo "❌ 删除失败"
    fi
}

# 询问用户是否继续操作，输入 y 继续，n 退出
prompt_continue() {
    while true; do
        read -p "是否继续操作？(y/n): " yn
        case $yn in
            [Yy]* ) return 0 ;;    # 继续，返回到主循环
            [Nn]* ) echo "退出"; exit 0 ;;  # 退出脚本
            * ) echo "请输入 y 或 n" ;;  # 输入不合法，继续循环询问
        esac
    done
}

# 主循环
while true; do
    echo
    echo "📜 保存的 Wi-Fi 网络列表："

    # 读取 Wi-Fi 名称到数组 wifi_list
    wifi_list=()
    while IFS= read -r line; do
        wifi_list+=("$line")
    done < <(get_wifi_list)

    # 如果没有保存的 Wi-Fi，退出脚本
    if [ ${#wifi_list[@]} -eq 0 ]; then
        echo "（无保存的 Wi-Fi 网络）"
        exit 0
    fi

    # 列出所有保存的 Wi-Fi，带编号
    for i in "${!wifi_list[@]}"; do
        echo "[$i] ${wifi_list[$i]}"
    done

    echo
    # 操作提示，告诉用户如何输入
    echo "请输入操作："
    echo "  - 输入 Wi-Fi 编号查看密码（例如 1）"
    echo "  - 输入 d加编号删除 Wi-Fi（例如 d2）"
    echo "  - 输入 q 退出"
    read -p "你的选择：" input

    # 退出
    if [[ "$input" == "q" ]]; then
        echo "退出"
        exit 0
    # 删除操作，格式 d<number>
    elif [[ "$input" =~ ^d([0-9]+)$ ]]; then
        idx="${BASH_REMATCH[1]}"
        # 检查编号是否合法
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#wifi_list[@]}" ]; then
            delete_wifi "${wifi_list[$idx]}"
            prompt_continue
        else
            echo "无效编号"
        fi
    # 查看密码，纯数字输入
    elif [[ "$input" =~ ^[0-9]+$ ]]; then
        idx="$input"
        if [ "$idx" -lt "${#wifi_list[@]}" ]; then
            show_password "${wifi_list[$idx]}"
            prompt_continue
        else
            echo "无效编号"
        fi
    else
        # 其它无效输入
        echo "无效输入"
    fi
done
