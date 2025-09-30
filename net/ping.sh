#!/bin/bash

# =====================================
# HTTP Ping 脚本 - 输出浏览器风格结果
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main//net/ping.sh)"
# =====================================

# 优先使用环境变量，如果没有，则提示用户输入
HOST="${PING_HOST:-}"
COUNT="${PING_COUNT:-}"

# 如果环境变量没有定义，则交互输入
if [[ -z "$HOST" ]]; then
    read -p "请输入目标主机 (例如 www.baidu.com): " HOST
fi

if [[ -z "$COUNT" ]]; then
    read -p "请输入请求次数 (默认 4): " COUNT
    COUNT="${COUNT:-4}"  # 默认 4 次
fi

# 如果没有提供 host 参数，提示用法并退出
if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <host> [count]"
  exit 1
fi

# 判断操作系统，选择合适的毫秒时间获取方式
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS 获取毫秒时间戳
    get_ms_time() { echo $(( $(date +%s%N)/1000000 )); }
else
    # Linux 获取毫秒时间戳
    get_ms_time() { date +%s%3N; }
fi

# 输出测试信息
echo "🌐 HTTP PING $HOST 测试结果:"
echo "⏰ 测试时间: $(date '+%Y/%m/%d %H:%M:%S')"
echo "🎯 目标主机: $HOST"
echo "🔢 测试次数: $COUNT"
echo "📡 测试方法: HTTP请求 (浏览器环境限制)"
echo

# 初始化统计变量
total=0      # 总延迟累加
success=0    # 成功请求计数
min=100000   # 最小延迟初始化为大值，方便比较
max=0        # 最大延迟初始化为 0

# 循环发送 HTTP HEAD 请求
for i in $(seq 1 $COUNT); do
  start=$(get_ms_time)                           # 记录请求开始时间
  curl -Is --max-time 8 "$HOST" >/dev/null 2>&1  # 发送 HTTP HEAD 请求，超时 8 秒
  status=$?                                      # 获取 curl 返回状态
  end=$(get_ms_time)                             # 记录请求结束时间
  latency=$((end-start))                         # 计算延迟毫秒数

  # 根据请求结果输出
  if [ $status -eq 0 ]; then
    # 请求成功，统计数据累加
    success=$((success+1))
    total=$((total+latency))
    ((latency < min)) && min=$latency           # 更新最小延迟
    ((latency > max)) && max=$latency           # 更新最大延迟
    echo "$i. 响应时间: ${latency}ms - 连接成功"
  else
    # 请求失败，显示 N/A
    echo "$i. 响应时间: N/A - 连接失败"
  fi

  sleep 1  # 每次请求间隔 1 秒
done

# 计算平均延迟
if [ $success -gt 0 ]; then
  avg=$((total/success))
else
  # 如果没有成功请求，重置统计数据
  min=0
  max=0
  avg=0
fi

# 输出统计信息
echo
echo "📊 === 统计信息 ==="
echo "📤 发送请求: $COUNT 个"
echo "✅ 成功响应: $success 个"
# 使用 awk 计算成功率并保留一位小数
success_rate=$(awk "BEGIN {printf \"%.1f\", $success/$COUNT*100}")
echo "📈 成功率: ${success_rate}%"
echo "⚡ 最小延迟: ${min}ms"
echo "🔥 最大延迟: ${max}ms"
echo "📊 平均延迟: ${avg}ms"
