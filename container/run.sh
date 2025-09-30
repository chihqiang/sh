#!/bin/bash

# ===============================================================
# 🚀 容器运行工具
#
# 本脚本支持 Podman 和 Docker，简化容器启动过程，并支持以下功能：
#   ✅ 支持指定容器镜像（例如 nginx:latest）
#   ✅ 支持多个宿主机目录挂载到容器（格式 /host:/container）
#   ✅ 支持端口映射（例如 8080:80）
#   ✅ 支持注入多个环境变量（如 FOO=1 BAR=2）
#   ✅ 自动清理旧容器与镜像，避免冲突
#   ✅ 美化输出，操作更加清晰和可追溯
#
# 👉 使用方式：
#   wget -O /usr/local/bin/crun https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main//container/run.sh && chmod +x /usr/local/bin/crun
#
# 要求：
#   - 已安装 Podman 或 Docker
#   - 宿主机上存在指定的挂载目录（如果有）
#
# 作者：zhiqiang
# ===============================================================

# === 配置 ===
RUN_NAME="crun"  # 设置容器的名称

# === 函数：带颜色的 echo ===
# 这个函数用于输出带颜色的消息，方便在终端中显示不同类型的信息
color_echo() {
  local color_code=$1
  shift
  echo -e "\033[${color_code}m$@\033[0m"
}

# 各种颜色的输出函数，分别对应不同的消息类型
info()    { color_echo "1;34" "🔧 $@"; }  # 蓝色
success() { color_echo "1;32" "✅ $@"; }  # 绿色
warning() { color_echo "1;33" "⚠️  $@"; }  # 黄色
error()   { color_echo "1;31" "❌ $@"; }  # 红色
step()    { color_echo "1;36" "🚀 $@"; }  # 青色
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }

# ✅ 检查 Podman 或 Docker 是否已安装
# 检查是否已安装 Podman，如果未安装，则检查 Docker
if command -v podman &> /dev/null; then
  CONTAINER_ENGINE="podman"
  info "🔧 检测到 Podman，正在使用 Podman 启动容器"
elif command -v docker &> /dev/null; then
  CONTAINER_ENGINE="docker"
  info "🔧 检测到 Docker，正在使用 Docker 启动容器"
else
  error "❌ 未检测到 Podman 或 Docker，请先安装其中一个工具后再运行此脚本"
  error "🔧 安装参考：https://podman.io/getting-started/installation"
  exit 1
fi

# === 镜像名称 ===
docker_image="${C_IMAGE:-}"
if [ -z "$docker_image" ]; then
  read -p "📦 请输入需运行容器镜像名称（例如 nginx:latest）: " docker_image
  info "镜像来自用户输入：$docker_image"
else
  info "镜像来自环境变量 C_IMAGE：$docker_image"
fi

# === 挂载目录 ===
mounts_input="${C_MOUNT_MAP:-}"
if [ -z "$mounts_input" ]; then
  echo "📁 支持多个挂载目录，例如：/host:/container /log:/log"
  read -p "📁 输入挂载目录对 [默认不挂载]：" mounts_input
  info "挂载目录来自用户输入：$mounts_input"
else
  info "挂载目录来自环境变量 C_MOUNT_MAP：$mounts_input"
fi

# === 端口映射 ===
port_map="${C_PORT_MAP:-}"
if [ -z "$port_map" ]; then
  read -p "🌐 输入端口映射（支持多个，如 8080:80 8443:443）[默认不映射]：" port_map
  info "端口映射来自用户输入：$port_map"
else
  info "端口映射来自环境变量 C_PORT_MAP：$port_map"
fi

# === 环境变量 ===
env_input="${C_ENV_MAP:-}"
if [ -z "$env_input" ]; then
  read -p "🌱 输入环境变量（如 FOO=1 BAR=2）[默认不注入]：" env_input
  info "环境变量来自用户输入：$env_input"
else
  info "环境变量来自环境变量 C_ENV_MAP：$env_input"
fi



# === 校验挂载目录 ===
# 校验用户输入的挂载目录是否合法
if [ -n "$mounts_input" ]; then
  for mount in $mounts_input; do
    # 分割目录路径
    host_dir=$(echo "$mount" | cut -d: -f1)
    container_dir=$(echo "$mount" | cut -d: -f2)

    # 如果格式错误，提示并退出
    if [ -z "$host_dir" ] || [ -z "$container_dir" ]; then
      error "挂载格式错误：$mount，应为 /宿主机:/容器路径"
      exit 1
    fi

    # 检查宿主机目录是否存在
    if [ ! -d "$host_dir" ]; then
      warning "宿主机目录不存在：$host_dir"
      exit 1
    fi
  done
fi

# === 清理旧容器和镜像 ===
divider
step "清理旧容器和镜像..."
# 停止并删除已存在的同名容器
$CONTAINER_ENGINE stop $RUN_NAME 2>/dev/null || true
$CONTAINER_ENGINE rm $RUN_NAME 2>/dev/null || true

# === 组装运行参数 ===
# 初始化运行参数
run_args="-it --rm --name $RUN_NAME --privileged"

# 如果有端口映射，添加到运行参数中
[ -n "$port_map" ] && run_args="$run_args -p $port_map"

# 如果有挂载目录，添加到运行参数中
if [ -n "$mounts_input" ]; then
  for mount in $mounts_input; do
    run_args="$run_args -v $mount"
  done
fi

# 如果有环境变量，添加到运行参数中
if [ -n "$env_input" ]; then
  for env in $env_input; do
    run_args="$run_args -e $env"
  done
fi

# === 启动容器 ===
divider
step "启动容器..."
# 打印运行命令并执行
echo -e "\033[1;37m🔍 命令预览：\033[0m $CONTAINER_ENGINE run $run_args $docker_image"
divider
eval $CONTAINER_ENGINE run $run_args $docker_image

# === 结束提示 ===
divider
success "容器已退出 👋"
