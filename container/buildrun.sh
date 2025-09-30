#!/bin/bash

# ===============================================================
# 🚀 Docker / Podman 镜像构建 & 容器运行工具
#
# 本脚本用于简化 Docker 和 Podman 镜像的构建过程，并支持交互式配置：
#   ✅ 支持指定 Dockerfile
#   ✅ 支持多个宿主机目录挂载到容器中（格式 /host:/container）
#   ✅ 支持端口映射（如 8080:80）
#   ✅ 支持注入多个环境变量（如 FOO=1 BAR=2）
#   ✅ 自动清理旧容器与镜像
#   ✅ 美化输出，操作更清晰
#
# 👉 使用方式（直接运行）：
#    wget -O /usr/local/bin/cbuildrun https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/container/buildrun.sh && chmod +x /usr/local/bin/cbuildrun
#
# 要求：
#   - Docker 或 Podman 已安装
#   - 指定的 Dockerfile 存在
#
# 作者：zhiqiang
# ===============================================================

# === 配置 ===
DEFAULT_DOCKERFILE_NAME="Dockerfile"
DEFAULT_IMAGE_NAME="buildrun:latest"
RUN_NAME="buildrun"

# === 函数：带颜色的 echo ===
color_echo() {
  local color_code=$1
  shift
  echo -e "\033[${color_code}m$@\033[0m"
}

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

info "使用 $CONTAINER_ENGINE 作为容器引擎"

# === 输入交互 ===
divider
info "构建镜像并运行容器工具（$CONTAINER_ENGINE）"
divider

read -p "📄 请输入 Dockerfile 文件名 [默认：Dockerfile]：" dockerfile_name
dockerfile_name=${dockerfile_name:-$DEFAULT_DOCKERFILE_NAME}
if [ ! -f "$dockerfile_name" ]; then
    error "Dockerfile 文件不存在：$dockerfile_name"
    exit 1
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
if [ -n "$mounts_input" ]; then
  for mount in $mounts_input; do
    host_dir=$(echo "$mount" | cut -d: -f1)
    container_dir=$(echo "$mount" | cut -d: -f2)

    if [ -z "$host_dir" ] || [ -z "$container_dir" ]; then
      error "挂载格式错误：$mount，应为 /宿主机:/容器路径"
      exit 1
    fi

    if [ ! -d "$host_dir" ]; then
      warning "宿主机目录不存在：$host_dir"
      exit 1
    fi
  done
fi

# === 清理旧容器和镜像 ===
divider
step "清理旧容器和镜像..."
$CONTAINER_ENGINE stop $RUN_NAME 2>/dev/null || true
$CONTAINER_ENGINE rm $RUN_NAME 2>/dev/null || true
$CONTAINER_ENGINE rmi -f $DEFAULT_IMAGE_NAME 2>/dev/null || true

# === 构建镜像 ===
divider
step "开始构建镜像..."
$CONTAINER_ENGINE build -f "$dockerfile_name" -t "$DEFAULT_IMAGE_NAME" .
if [ $? -ne 0 ]; then
  error "镜像构建失败！"
  exit 1
fi
success "镜像构建成功：$DEFAULT_IMAGE_NAME"

# === 组装运行参数 ===
run_args="-it --rm --name $RUN_NAME --privileged"

[ -n "$port_map" ] && run_args="$run_args -p $port_map"

if [ -n "$mounts_input" ]; then
  for mount in $mounts_input; do
    run_args="$run_args -v $mount"
  done
fi

if [ -n "$env_input" ]; then
  for env in $env_input; do
    run_args="$run_args -e $env"
  done
fi

# === 启动容器 ===
divider
step "启动容器..."
echo -e "\033[1;37m🔍 命令预览：\033[0m $CONTAINER_ENGINE run $run_args $DEFAULT_IMAGE_NAME"
divider
eval $CONTAINER_ENGINE run $run_args $DEFAULT_IMAGE_NAME

# === 结束提示 ===
divider
success "容器已退出 👋"
