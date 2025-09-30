#!/bin/bash

set -euo pipefail

# ===============================================
# syscheck.sh - 终端彩色巡检工具（增强版）
# ===============================================
# 功能说明:
# 1. 系统信息巡检：主机名、操作系统、内核版本、IP、uptime
# 2. 环境变量检查：PATH安全、敏感环境变量
# 3. 系统句柄检查：最大文件句柄、当前使用、Top进程
# 4. 安全风险检查：空密码账户、特权账户、关键文件权限、SSH配置、防火墙
# 5. 性能检查：CPU、内存、Swap、负载、Top进程
# 6. 磁盘检查：磁盘使用率、inode使用率
# 7. 网络检查：监听端口
# 8. 日志分析：最近日志中 error/warn/fail 信息
# 9. 风险统计总结：高/中/低风险汇总，并以彩色表格输出
# 10. 自动安装缺失命令：支持 apt、yum、dnf、zypper
# 11. 可选输出到文件：使用 -o 输出
#
# 使用方法:
#   bash syscheck.sh               # 终端输出
#   bash syscheck.sh -o output.txt # 同时保存到文件
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/syscheck.sh)"
#
# 颜色说明:
#   Green  : 信息
#   Yellow : 中风险/警告
#   Red    : 高风险/错误
#
# 依赖命令:
#   lsof, ss, df, awk, stat, grep, top, free, journalctl (自动检测并尝试安装)
#
# ===============================================

# -------------------------------
# 参数
# -------------------------------
OUTPUT_FILE=""
while getopts "o:" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG";;
    esac
done

# -------------------------------
# 颜色输出函数
# -------------------------------
info()  { echo -e "\033[32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[31m[ERROR]\033[0m $*"; }

# 风险统计
high_risk=0
medium_risk=0
low_risk=0
declare -a RISK_LIST

add_risk() {
    level=$1
    msg=$2
    case "$level" in
        High) high_risk=$((high_risk+1)); color="\033[31mHigh\033[0m";;
        Medium) medium_risk=$((medium_risk+1)); color="\033[33mMedium\033[0m";;
        Low) low_risk=$((low_risk+1)); color="\033[34mLow\033[0m";;
    esac
    RISK_LIST+=("$color|$msg")
}

# -------------------------------
# 打印分隔符
# -------------------------------
section() {
    echo
    echo "=============================="
    echo "▶ $1"
    echo "=============================="
}

# -------------------------------
# 自动安装命令函数
# -------------------------------
install_cmd() {
    cmd=$1
    if ! command -v "$cmd" &>/dev/null; then
        warn "$cmd 未安装，尝试自动安装..."
        if command -v apt &>/dev/null; then sudo apt update && sudo apt install -y "$cmd"
        elif command -v yum &>/dev/null; then sudo yum install -y "$cmd"
        elif command -v dnf &>/dev/null; then sudo dnf install -y "$cmd"
        elif command -v zypper &>/dev/null; then sudo zypper install -y "$cmd"
        else
            warn "无法自动安装 $cmd，请手动安装"
        fi
    fi
}

# -------------------------------
# 检查必要命令
# -------------------------------
for cmd in lsof ss df awk stat grep; do
    install_cmd "$cmd"
done

# -------------------------------
# 系统信息
# -------------------------------
section "系统信息"
echo "主机名: $(hostname)"
echo "操作系统: $(uname -a)"
echo "内核版本: $(uname -r)"
echo "IP 地址: $(hostname -I 2>/dev/null || echo '未获取到')"
uptime

# -------------------------------
# 环境变量检查
# -------------------------------
section "环境变量检查"
echo "PATH=$PATH"
if [[ "$PATH" == *".:"* || "$PATH" == *":."* ]]; then
    add_risk "Medium" "PATH 中包含 '.'，可能存在安全风险"
fi

echo
echo "敏感环境变量:"
sensitive=$( (set -o posix ; set) | grep -E 'PASS|KEY|SECRET|TOKEN' || true )
if [[ -n "$sensitive" ]]; then
    echo "$sensitive"
    add_risk "Low" "发现敏感环境变量"
else
    echo "无"
fi

# -------------------------------
# 系统句柄检查
# -------------------------------
section "系统句柄检查"
echo "最大文件句柄数: $(cat /proc/sys/fs/file-max)"
echo "当前句柄使用情况: $(lsof | wc -l)"
echo "Top 10 句柄进程:"
lsof | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10

# -------------------------------
# 安全风险检查
# -------------------------------
section "安全风险检查"

# 空密码账户
empty_accounts=$(awk -F: '($2=="" || $2=="*") {print $1}' /etc/shadow || true)
if [[ -n "$empty_accounts" ]]; then
    echo "$empty_accounts"
    add_risk "High" "存在空密码账户"
fi

# 特权账户
echo
echo "特权账户 (UID=0):"
awk -F: '($3==0) {print $1}' /etc/passwd

# 关键文件权限
for f in /etc/passwd /etc/shadow /etc/sudoers; do
    if [ -e "$f" ] && [ "$(stat -c %a "$f")" -gt 640 ]; then
        add_risk "High" "$f 权限过宽"
    fi
done

# SSH 配置
if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
    add_risk "High" "SSH 允许 root 登录"
fi
if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
    add_risk "Medium" "SSH 允许密码认证"
fi

# 防火墙
if (systemctl status firewalld 2>/dev/null || ufw status 2>/dev/null) | grep -qi "inactive"; then
    add_risk "Medium" "防火墙未启用"
fi

# -------------------------------
# 性能检查
# -------------------------------
section "性能检查"
echo "CPU 使用率:"
top -bn1 | grep "Cpu(s)"
echo "负载: $(uptime | awk -F 'load average:' '{print $2}')"
echo "内存使用情况:"
free -h
echo "Swap 使用率:"
free | awk '/Swap/ {printf "%.2f%%\n", $3/$2*100}'

# -------------------------------
# 磁盘检查
# -------------------------------
section "磁盘使用率"
echo "磁盘使用情况:"
df -hT
echo "inode 使用情况:"
df -i

# -------------------------------
# 网络检查
# -------------------------------
section "网络检查"
if command -v ss &>/dev/null; then
    echo "监听端口:"
    ss -tuln
else
    echo "ss 不存在"
fi

# -------------------------------
# 日志分析
# -------------------------------
section "日志分析"
echo "最近 10 条系统日志 (包含 error/warn/fail):"
if command -v journalctl &>/dev/null; then
    journalctl -n 50 | grep -Ei 'error|warn|fail' || echo "无相关日志"
else
    tail -n 50 /var/log/messages | grep -Ei 'error|warn|fail' || echo "无相关日志"
fi

# -------------------------------
# 风险统计总结
# -------------------------------
section "风险统计总结"

# 打印彩色表格
printf "┌─────────┬───────────────────────────────┐\n"
printf "│ 风险等级 │ 风险内容                        │\n"
printf "├─────────┼───────────────────────────────┤\n"
for item in "${RISK_LIST[@]}"; do
    IFS='|' read -r level msg <<< "$item"
    printf "│ %-7b │ %-30b │\n" "$level" "$msg"
done
printf "└─────────┴───────────────────────────────┘\n"

echo "高风险: $high_risk  中风险: $medium_risk  低风险: $low_risk"
if (( high_risk > 0 )); then
    error "存在高风险问题，请立即处理！"
elif (( medium_risk > 0 )); then
    warn "存在中风险问题，请关注。"
else
    info "系统状态良好，无明显风险。"
fi

# 输出到文件（可选）
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "输出结果到 $OUTPUT_FILE"
    script -q -c "bash $0" "$OUTPUT_FILE"
fi

info "巡检完成 ✅"
