#!/bin/bash

# wget https://raw.githubusercontent.com/chihqiang/sh/main/firewalld.sh
# 防火墙管理脚本
# 用于管理Linux firewalld防火墙

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 请使用root权限运行此脚本"
    exit 1
fi

# 检查firewalld是否安装
if ! command -v firewall-cmd &> /dev/null; then
    echo "错误: firewalld未安装"
    echo "请使用以下命令安装:"
    echo "  CentOS/RHEL: sudo yum install firewalld"
    echo "  Ubuntu/Debian: sudo apt install firewalld"
    exit 1
fi

# 显示菜单
show_menu() {
    clear
    echo "╭───────────────── Firewalld 防火墙管理脚本 ─────────────────╮"
    echo "│                                                            │"
    echo "│  1. 显示防火墙状态           2. 启动防火墙               │"
    echo "│  3. 停止防火墙               4. 重启防火墙               │"
    echo "│  5. 开放端口                 6. 关闭端口                 │"
    echo "│  7. 显示所有开放的端口       8. 配置端口转发             │"
    echo "│  9. 删除端口转发             10. 显示所有端口转发        │"
    echo "│  11. 添加服务                12. 删除服务                │"
    echo "│  13. 显示所有服务            14. 导出防火墙配置          │"
    echo "│                                                            │"
    echo "│  0. 退出                                                  │"
    echo "│                                                            │"
    echo "╰────────────────────────────────────────────────────────────╯"
}

# 显示防火墙状态
show_status() {
    echo "防火墙状态:"
    systemctl status firewalld | grep Active
    echo ""
    echo "默认区域:"
    firewall-cmd --get-default-zone
    echo ""
    echo "按任意键继续..."
    read -n 1
}

# 启动防火墙
start_firewall() {
    echo "正在启动防火墙..."
    systemctl start firewalld
    echo "防火墙已启动"
    echo "按任意键继续..."
    read -n 1
}

# 停止防火墙
stop_firewall() {
    echo "正在停止防火墙..."
    systemctl stop firewalld
    echo "防火墙已停止"
    echo "按任意键继续..."
    read -n 1
}

# 重启防火墙
restart_firewall() {
    echo "正在重启防火墙..."
    systemctl restart firewalld
    echo "防火墙已重启"
    echo "按任意键继续..."
    read -n 1
}

# 开放端口
open_port() {
    echo "请输入要开放的端口号: "
    read port
    echo "请选择协议类型:"
    echo "1. TCP"
    echo "2. UDP"
    echo "3. TCP和UDP"
    echo -n "请选择 [1-3]: "
    read proto_choice
    
    case $proto_choice in
        1)
            protocol="tcp"
            ;;
        2)
            protocol="udp"
            ;;
        3)
            protocol="both"
            ;;
        *)
            echo "无效的选择，默认使用TCP"
            protocol="tcp"
            ;;
    esac
    
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$port" ]; then
        echo "错误: 端口不能为空"
    else
        if [ "$protocol" = "both" ]; then
            echo "正在开放端口 $port/tcp 和 $port/udp 在区域 $zone..."
            firewall-cmd --zone=$zone --add-port=$port/tcp --permanent
            firewall-cmd --zone=$zone --add-port=$port/udp --permanent
        else
            echo "正在开放端口 $port/$protocol 在区域 $zone..."
            firewall-cmd --zone=$zone --add-port=$port/$protocol --permanent
        fi
        firewall-cmd --reload
        echo "端口已开放"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 关闭端口
close_port() {
    echo -n "请输入要关闭的端口号: "
    read port
    echo -n "请输入协议类型 (tcp/udp): "
    read protocol
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$port" ] || [ -z "$protocol" ]; then
        echo "错误: 端口和协议不能为空"
    else
        echo "正在关闭端口 $port/$protocol 在区域 $zone..."
        firewall-cmd --zone=$zone --remove-port=$port/$protocol --permanent
        firewall-cmd --reload
        echo "端口已关闭"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 显示所有开放的端口
list_ports() {
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    echo "区域 $zone 中开放的端口:"
    firewall-cmd --zone=$zone --list-ports
    
    echo -n "按任意键继续..."
    read -n 1
}

# 配置端口转发
add_port_forward() {
    echo -n "请输入源端口号: "
    read source_port
    echo -n "请输入目标IP地址: "
    read target_ip
    echo -n "请输入目标端口号: "
    read target_port
    echo -n "请输入协议类型 (tcp/udp): "
    read protocol
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$source_port" ] || [ -z "$target_ip" ] || [ -z "$target_port" ] || [ -z "$protocol" ]; then
        echo "错误: 所有字段不能为空"
    else
        echo "正在添加端口转发..."
        firewall-cmd --zone=$zone --add-forward-port=port=$source_port:proto=$protocol:toport=$target_port:toaddr=$target_ip --permanent
        firewall-cmd --reload
        echo "端口转发已添加"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 删除端口转发
remove_port_forward() {
    echo -n "请输入源端口号: "
    read source_port
    echo -n "请输入目标IP地址: "
    read target_ip
    echo -n "请输入目标端口号: "
    read target_port
    echo -n "请输入协议类型 (tcp/udp): "
    read protocol
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$source_port" ] || [ -z "$target_ip" ] || [ -z "$target_port" ] || [ -z "$protocol" ]; then
        echo "错误: 所有字段不能为空"
    else
        echo "正在删除端口转发..."
        firewall-cmd --zone=$zone --remove-forward-port=port=$source_port:proto=$protocol:toport=$target_port:toaddr=$target_ip --permanent
        firewall-cmd --reload
        echo "端口转发已删除"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 显示所有端口转发
list_port_forwards() {
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    echo "区域 $zone 中的端口转发:"
    firewall-cmd --zone=$zone --list-forward-ports
    
    echo -n "按任意键继续..."
    read -n 1
}

# 添加服务
add_service() {
    echo -n "请输入要添加的服务名称: "
    read service
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$service" ]; then
        echo "错误: 服务名称不能为空"
    else
        echo "正在添加服务 $service 到区域 $zone..."
        firewall-cmd --zone=$zone --add-service=$service --permanent
        firewall-cmd --reload
        echo "服务已添加"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 删除服务
remove_service() {
    echo -n "请输入要删除的服务名称: "
    read service
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    if [ -z "$service" ]; then
        echo "错误: 服务名称不能为空"
    else
        echo "正在从区域 $zone 中删除服务 $service..."
        firewall-cmd --zone=$zone --remove-service=$service --permanent
        firewall-cmd --reload
        echo "服务已删除"
    fi
    
    echo -n "按任意键继续..."
    read -n 1
}

# 显示所有服务
list_services() {
    echo -n "请输入区域名称 (默认为public): "
    read zone
    
    if [ -z "$zone" ]; then
        zone="public"
    fi
    
    echo "区域 $zone 中开放的服务:"
    firewall-cmd --zone=$zone --list-services
    
    echo -n "按任意键继续..."
    read -n 1
}

# 导出防火墙配置
export_config() {
    echo -n "请输入导出文件路径 (默认为 ./firewall_config.txt): "
    read export_path
    
    if [ -z "$export_path" ]; then
        export_path="./firewall_config.txt"
    fi
    
    echo "正在导出防火墙配置到 $export_path..."
    
    {
        echo "===== 防火墙配置导出 ====="
        echo "导出时间: $(date)"
        echo ""
        
        echo "== 防火墙状态 =="
        echo "状态: $(systemctl is-active firewalld)"
        echo "默认区域: $(firewall-cmd --get-default-zone)"
        echo ""
        
        echo "== 活动区域 =="
        firewall-cmd --get-active-zones
        echo ""
        
        echo "== 服务列表 =="
        for zone in $(firewall-cmd --get-zones); do
            echo "区域: $zone"
            echo "服务: $(firewall-cmd --zone=$zone --list-services)"
            echo ""
        done
        
        echo "== 端口列表 =="
        for zone in $(firewall-cmd --get-zones); do
            echo "区域: $zone"
            echo "端口: $(firewall-cmd --zone=$zone --list-ports)"
            echo ""
        done
        
        echo "== 端口转发 =="
        for zone in $(firewall-cmd --get-zones); do
            echo "区域: $zone"
            echo "转发: $(firewall-cmd --zone=$zone --list-forward-ports)"
            echo ""
        done
        
        echo "===== 配置导出结束 ====="
    } > "$export_path"
    
    echo "配置已导出到 $export_path"
    echo -n "按任意键继续..."
    read -n 1
}

# 主循环
while true; do
    show_menu
    echo -n "请选择一个选项 [0-14]: "
    read choice
    
    case $choice in
        0)
            echo "退出..."
            exit 0
            ;;
        1)
            show_status
            ;;
        2)
            start_firewall
            ;;
        3)
            stop_firewall
            ;;
        4)
            restart_firewall
            ;;
        5)
            open_port
            ;;
        6)
            close_port
            ;;
        7)
            list_ports
            ;;
        8)
            add_port_forward
            ;;
        9)
            remove_port_forward
            ;;
        10)
            list_port_forwards
            ;;
        11)
            add_service
            ;;
        12)
            remove_service
            ;;
        13)
            list_services
            ;;
        14)
            export_config
            ;;
        *)
            echo "无效的选项，请重试"
            echo -n "按任意键继续..."
            read -n 1
            ;;
    esac
done 
