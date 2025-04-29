#!/bin/bash

# 安装 podman 和 podman-desktop
brew install podman podman-desktop

# 配置默认的镜像仓库为 docker.io
mkdir -p ~/.config/containers  # 确保目录存在
echo "unqualified-search-registries = ['docker.io']" > ~/.config/containers/registries.conf

# 初始化 Podman 虚拟机
podman machine init

# 启动 Podman 虚拟机
podman machine start

# 输出 Podman 版本信息，确认安装成功
podman --version
