#!/bin/bash

DEFAULT_DOCKERFILE_NAME="Dockerfile"
DEFAULT_IMAGE_NAME="runtest:latest"
RUN_NAME="runtest"

read -p "请输入你构建镜像的 Dockerfile 文件名 [默认：Dockerfile]：" dockerfile_name
dockerfile_name=${dockerfile_name:-$DEFAULT_DOCKERFILE_NAME}
if [ ! -f "$dockerfile_name" ]; then
    echo "❌ Dockerfile 文件不存在，请确认后重新运行"
    exit 1
fi
read -p "请输入要挂载的宿主机目录 (例如 /data/test) [默认不挂载]：" host_dir
read -p "请输入容器内目录 (例如 /app) [默认不挂载]：" container_dir
read -p "请输入要映射的端口 (例如 8080:80) [默认不映射]：" port_map
read -p "请输入要注入的环境变量 (例如 FOO=123 BAR=xyz) [默认不注入]：" env_input
if [ -n "$host_dir" ] && [ ! -d "$host_dir" ]; then
    echo "⚠️ 宿主机挂载目录 $host_dir 不存在"
    exit 1
fi


echo "🔄 清理旧容器和镜像..."
podman stop $RUN_NAME 2>/dev/null || true
podman rm $RUN_NAME 2>/dev/null || true
podman rmi -f $DEFAULT_IMAGE_NAME 2>/dev/null || true

echo "🚀 正在构建镜像..."
podman build -f "$dockerfile_name" -t "$DEFAULT_IMAGE_NAME" .
if [ $? -ne 0 ]; then
  echo "❌ 镜像构建失败，终止运行"
  exit 1
fi

echo "🚪 正在运行容器..."
run_args="-it --rm --name $RUN_NAME --privileged"

# 添加端口映射
[ -n "$port_map" ] && run_args="$run_args -p $port_map"

# 添加挂载目录
[ -n "$host_dir" ] && [ -n "$container_dir" ] && run_args="$run_args -v $host_dir:$container_dir"

# 添加环境变量
if [ -n "$env_input" ]; then
  for env in $env_input; do
    run_args="$run_args -e $env"
  done
fi

# 用 eval 来正确解析所有参数
eval podman run $run_args $DEFAULT_IMAGE_NAME

echo "✅ 容器已退出"
