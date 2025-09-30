#!/bin/bash
set -eu

# ===============================================================
# 🚀 goinstall.sh - 快速安装 Go 工具包（go install）
#
# 📦 功能简介：
#   - 自动下载安装指定版本的 Go（支持阿里云镜像）
#   - 设置临时 Go 环境并安装指定的 Go 包
#   - 自动移动生成的二进制文件到 /usr/local/bin
#   - 可交互确认是否覆盖已有同名命令
#
# 👉 使用方式（推荐直接在线执行）：
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/goinstall.sh)"
#
# ✅ 支持环境变量（可选）：
#     GOLANG_MIRROR   - Go 下载镜像地址（默认: https://mirrors.aliyun.com/golang）
#     GO_VERSION      - 指定安装的 Go 版本（例如: 1.22.3）
#     GO_PACKAGE      - 要安装的 Go 包路径（例如: github.com/spf13/cobra-cli@latest）
#     FORCE           - 设置为 1 可自动覆盖 /usr/local/bin 中已有同名文件（非交互）
#
# 💡 示例：
#     export GOLANG_MIRROR="https://mirrors.aliyun.com/golang"
#     export GO_VERSION=1.22.3
#     export GO_PACKAGE="github.com/spf13/cobra-cli@latest"
#     export FORCE=1
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/goinstall.sh)"
#
# 🧑‍💻 作者：zhiqiang
# 📅 更新时间：2025-06-05
# ===============================================================

# 检查必要工具
command -v wget >/dev/null 2>&1 || { echo "❌ 未安装 wget，请先安装。"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "❌ 未安装 tar，请先安装。"; exit 1; }

GOLANG_MIRROR="${GOLANG_MIRROR:-"https://mirrors.aliyun.com/golang"}"

# ===== 获取 Go 版本号 =====
GO_VERSION="${GO_VERSION:-}"
if [ -z "$GO_VERSION" ]; then
  read -p "请输入 Go 版本号（留空自动获取最新版）: " USER_INPUT
  if [ -n "$USER_INPUT" ]; then
    GO_VERSION="$USER_INPUT"
  else
    echo "🔍 正在获取最新 Go 版本..."
    GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n1 | sed 's/^go//')
  fi
fi
echo "📌 使用 Go 版本: $GO_VERSION"

# ===== 获取 Go 包路径 =====
GO_PACKAGE="${GO_PACKAGE:-}"
if [ -z "$GO_PACKAGE" ]; then
  read -p "请输入要安装的 Go 包路径（例如 github.com/spf13/cobra-cli@latest）: " USER_INPUT
  if [ -n "$USER_INPUT" ]; then
    GO_PACKAGE="$USER_INPUT"
  else
    echo "❌ 包路径不能为空。"
    exit 1
  fi
fi
echo "📦 待安装的 Go 包: $GO_PACKAGE"

# ===== 获取系统架构信息 =====
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "❌ 暂不支持该架构: $ARCH"; exit 1 ;;
esac

GO_TARBALL="go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
DOWNLOAD_URL="${GOLANG_MIRROR}/${GO_TARBALL}"

# ===== 创建临时目录 =====
TEMP="$(mktemp -d)"
trap 'rm -rf $TEMP' EXIT INT TERM

# ===== 下载 Go 安装包，带重试机制 =====
echo "⬇️  正在下载 Go 安装包: $GO_TARBALL ..."
max_retries=3
count=0
until wget --progress=dot:mega "${DOWNLOAD_URL}" -O "$TEMP/go.tar.gz"; do
  count=$((count+1))
  if [ $count -ge $max_retries ]; then
    echo "❌ 下载失败，已重试 $max_retries 次，退出。"
    exit 1
  fi
  echo "⚠️ 下载失败，第 $count 次重试，5秒后重试..."
  sleep 5
done

echo "📦 正在解压..."
tar -zxf "$TEMP/go.tar.gz" -C "$TEMP"

# ===== 设置临时 Go 环境变量 =====
export GO_HOME=$TEMP/go
export GOPATH=$TEMP/gopath
export PATH=$GO_HOME/bin:$GOPATH/bin:$PATH

# ===== 输出 Go 信息并配置模块代理 =====
go version
go env -w GO111MODULE=on
go env -w GOPROXY=https://goproxy.cn,direct

# ===== 安装指定 Go 包，带重试机制 =====
echo "⚙️  正在安装 Go 包: $GO_PACKAGE"
count=0
until go install "$GO_PACKAGE"; do
  count=$((count+1))
  if [ $count -ge $max_retries ]; then
    echo "❌ go install 失败，重试次数达到 $max_retries 次，退出。"
    echo "Go version: $(go version)"
    echo "Go env:"
    go env
    exit 1
  fi
  echo "⚠️ go install 失败，第 $count 次重试，5秒后重试..."
  sleep 5
done

# ===== 获取二进制文件名称与路径 =====
BIN_NAME=$(basename "${GO_PACKAGE%%@*}")
BIN_PATH="$GOPATH/bin/$BIN_NAME"

# ===== 移动二进制文件到系统路径 =====
TARGET_PATH="/usr/local/bin/$BIN_NAME"
if [ -f "$TARGET_PATH" ]; then
  if [ "${FORCE:-}" = "1" ]; then
    echo "⚠️ 文件 $TARGET_PATH 已存在，但已开启 FORCE=1，自动覆盖..."
    sudo mv "$BIN_PATH" "$TARGET_PATH"
    chmod +x "$TARGET_PATH"
    echo "✅ 已自动覆盖安装二进制文件：$TARGET_PATH"
  else
    read -p "⚠️ 文件 $TARGET_PATH 已存在，是否覆盖？(y/n): " yn
    case "$yn" in
      [Yy]* )
        sudo mv "$BIN_PATH" "$TARGET_PATH"
        chmod +x "$TARGET_PATH"
        echo "✅ 已覆盖安装二进制文件：$TARGET_PATH"
        ;;
      * )
        echo "❌ 取消安装，二进制文件未覆盖。"
        exit 1
        ;;
    esac
  fi
else
  sudo mv "$BIN_PATH" "$TARGET_PATH"
  chmod +x "$TARGET_PATH"
  echo "✅ 安装成功，二进制文件已放置于：$TARGET_PATH"
fi


# ===== 运行帮助命令验证 =====
echo "🚀 正在运行: $BIN_NAME --help"
"$BIN_NAME" --help || { echo "❌ 运行失败"; exit 1; }

echo "----------------------------------------"
echo "🎉 构建完成"
echo "📦 包名：$GO_PACKAGE"
echo "🛠️ 可执行文件路径：/usr/local/bin/$BIN_NAME"
echo "----------------------------------------"
