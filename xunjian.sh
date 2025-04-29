#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/xunjian.sh | bash
# apt install -y net-tools
# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 打印分隔线
print_separator() {
    echo -e "${YELLOW}========================================${NC}"
}

# 打印标题
print_title() {
    echo -e "\n${GREEN}$1${NC}"
    print_separator
}

# 打印警告信息
print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

# 打印错误信息
print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 打印成功信息
print_success() {
    echo -e "${GREEN}[正常] $1${NC}"
}

# 系统基本信息检查
print_title "1. 系统基本信息"
OS_NAME=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
KERNEL_VERSION=$(uname -r)
HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d":" -f2 | sed 's/[ \t]*//')
CPU_CORES=$(nproc)
MEMORY_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
MEMORY_USED=$(free -h | grep "Mem:" | awk '{print $3}')
MEMORY_FREE=$(free -h | grep "Mem:" | awk '{print $4}')

echo "操作系统: $OS_NAME"
echo "操作系统名称: $(uname)"
echo "硬件架构类型: $(uname -m)"
echo "内核版本: $KERNEL_VERSION"
echo "主机名: $HOSTNAME"
echo "运行时间: $UPTIME"
echo "CPU型号: $CPU_MODEL"
echo "CPU核心数: $CPU_CORES"
echo "总内存: $MEMORY_TOTAL"
echo "已用内存: $MEMORY_USED"
echo "可用内存: $MEMORY_FREE"


print_title "2. 磁盘使用情况"  # 打印标题信息（自定义函数，展示“磁盘使用情况”）
# 获取磁盘使用情况，过滤掉 tmpfs 和 devtmpfs，然后从第二行开始逐行读取
df -h | grep -v "tmpfs" | grep -v "devtmpfs" | tail -n +2 | while read line; do
    FILESYSTEM=$(echo $line | awk '{print $1}')     # 提取文件系统名称
    MOUNTPOINT=$(echo $line | awk '{print $6}')     # 提取挂载点
    SIZE=$(echo $line | awk '{print $2}')           # 提取总大小
    USED=$(echo $line | awk '{print $3}')           # 提取已用空间
    AVAIL=$(echo $line | awk '{print $4}')          # 提取可用空间
    USE_PERCENT=$(echo $line | awk '{print $5}')    # 提取使用率（百分比形式）

    USE_PERCENT_NUM=$(echo $USE_PERCENT | tr -d '%')  # 去掉百分号，转为纯数字
    if [ $USE_PERCENT_NUM -gt 80 ]; then
        # 如果使用率超过 80%，输出错误信息（使用自定义函数 print_error）
        print_error "文件系统: $FILESYSTEM 挂载点: $MOUNTPOINT 使用率: $USE_PERCENT"
    else
        # 否则，正常打印磁盘使用情况
        echo "文件系统: $FILESYSTEM 挂载点: $MOUNTPOINT 总大小: $SIZE 已用: $USED 可用: $AVAIL 使用率: $USE_PERCENT"
    fi
done


# 网络连接检查
print_title "3. 网络连接状态"
netstat -tuln | grep -v "Active" | grep -v "Proto" | while read line; do
    PROTO=$(echo $line | awk '{print $1}')
    LOCAL=$(echo $line | awk '{print $4}')
    REMOTE=$(echo $line | awk '{print $5}')
    STATE=$(echo $line | awk '{print $6}')
    echo "协议: $PROTO 本地地址: $LOCAL 远程地址: $REMOTE 状态: $STATE"
done

# 系统负载检查
print_title "4. 系统负载"
LOAD=$(uptime | awk -F'load average: ' '{print $2}')
LOAD1=$(echo $LOAD | cut -d',' -f1)
LOAD5=$(echo $LOAD | cut -d',' -f2)
LOAD15=$(echo $LOAD | cut -d',' -f3)

CPU_CORES=$(nproc)
LOAD1_NUM=$(echo $LOAD1 | tr -d ' ')
if (( $(echo "$LOAD1_NUM > $CPU_CORES" | bc -l) )); then
    print_error "系统负载过高 - 1分钟: $LOAD1, 5分钟: $LOAD5, 15分钟: $LOAD15"
else
    echo "1分钟负载: $LOAD1"
    echo "5分钟负载: $LOAD5"
    echo "15分钟负载: $LOAD15"
fi

# 进程检查
print_title "5. 进程状态"
echo "CPU使用率最高的5个进程:"
ps aux --sort=-%cpu | head -n 6 | tail -n 5 | while read line; do
    PID=$(echo $line | awk '{print $2}')
    USER=$(echo $line | awk '{print $1}')
    CPU=$(echo $line | awk '{print $3}')
    MEM=$(echo $line | awk '{print $4}')
    CMD=$(echo $line | awk '{print $11}')
    echo "PID: $PID 用户: $USER CPU使用率: $CPU% 内存使用率: $MEM% 命令: $CMD"
done

# 系统日志检查
print_title "6. 系统日志检查"
echo "最近的10条系统日志:"
journalctl -n 10 --no-pager | while read line; do
    TIME=$(echo $line | awk '{print $1" "$2" "$3}')
    SERVICE=$(echo $line | awk '{print $5}')
    MESSAGE=$(echo $line | cut -d':' -f4-)
    
    if echo "$line" | grep -q "error\|failed\|critical"; then
        print_error "时间: $TIME 服务: $SERVICE 消息: $MESSAGE"
    elif echo "$line" | grep -q "warning"; then
        print_warning "时间: $TIME 服务: $SERVICE 消息: $MESSAGE"
    else
        echo "时间: $TIME 服务: $SERVICE 消息: $MESSAGE"
    fi
done

# 安全检查
print_title "7. 安全检查"

# 检查SSH配置
SSH_CONFIG=$(grep "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "PermitRootLogin yes")
if echo "$SSH_CONFIG" | grep -q "no"; then
    print_success "SSH Root登录已禁用"
else
    print_warning "SSH Root登录未禁用"
fi

# 检查防火墙状态
if command -v firewall-cmd &> /dev/null; then
    FIREWALL_STATUS=$(firewall-cmd --state 2>&1)
    if [ "$FIREWALL_STATUS" = "running" ]; then
        print_success "防火墙已启用"
    else
        print_error "防火墙未启用"
    fi
else
    print_warning "防火墙未安装"
fi

# 检查系统更新
if command -v yum &> /dev/null; then
    UPDATES=$(yum check-update -q 2>/dev/null | wc -l)
    if [ $UPDATES -eq 0 ]; then
        print_success "系统已更新到最新版本"
    else
        print_warning "有$UPDATES个更新可用"
    fi
elif command -v apt &> /dev/null; then
    apt update &> /dev/null
    UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ $UPDATES -eq 0 ]; then
        print_success "系统已更新到最新版本"
    else
        print_warning "有$UPDATES个更新可用"
    fi
fi

print_separator
echo -e "${GREEN}巡检完成${NC}" 
