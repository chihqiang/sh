#!/bin/bash
set -e

# ===============================================================
# 🚀 在各种操作系统安装 Go 语言（官方二进制包）
#
# 👉 支持环境变量（可选）：
#    GOLANG_MIRROR - Go 下载镜像地址（默认: https://mirrors.aliyun.com/golang）
#    GO_VERSION    - 指定安装的 Go 版本（例如: 1.18.10）
#    INSTALL_DIR   - 安装目录（默认: /usr/local）
#
# 使用示例：
#   export GO_VERSION=1.18.10
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/golang.sh)"
#
# 作者：zhiqiang
# 更新时间：2025-06-18
# ===============================================================

# --- 自动检测适合的 shell 配置文件 ---
detect_profile_file() {
  local shell_name
  shell_name=$(basename "$SHELL")
  local profile=""

  if [ "$(uname | tr '[:upper:]' '[:lower:]')" = "darwin" ]; then
    # macOS
    if [ -f "$HOME/.zprofile" ]; then
      profile="$HOME/.zprofile"
    elif [ -f "$HOME/.zshrc" ]; then
      profile="$HOME/.zshrc"
    else
      profile="$HOME/.bash_profile"
    fi
  else
    # Linux 和其他
    case "$shell_name" in
      bash)
        if [ -f "$HOME/.bashrc" ]; then
          profile="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
          profile="$HOME/.bash_profile"
        else
          profile="$HOME/.profile"
        fi
        ;;
      zsh)
        if [ -f "$HOME/.zshrc" ]; then
          profile="$HOME/.zshrc"
        elif [ -f "$HOME/.zprofile" ]; then
          profile="$HOME/.zprofile"
        else
          profile="$HOME/.profile"
        fi
        ;;
      *)
        # 其他 shell fallback
        if [ -f "$HOME/.profile" ]; then
          profile="$HOME/.profile"
        else
          profile="$HOME/.bashrc"
        fi
        ;;
    esac
  fi

  echo "$profile"
}

# --- 判断架构 ---
get_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "armv6l" ;;
    *) echo "unsupported" ;;
  esac
}

# --- 判断系统类型 ---
get_os() {
  local os
  os=$(uname | tr '[:upper:]' '[:lower:]')
  if [ "$os" = "linux" ]; then
    if [ -f /etc/alpine-release ]; then
      echo "alpine"
    else
      echo "linux"
    fi
  else
    echo "$os"
  fi
}

# --- 安装依赖包 ---
install_deps() {
  local os="$1"
  local pkg="$2"

  if command -v "$pkg" >/dev/null 2>&1; then
    return
  fi

  case "$os" in
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y "$pkg"
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y "$pkg"
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$pkg"
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm "$pkg"
      elif command -v apk >/dev/null 2>&1; then
        sudo apk add "$pkg"
      else
        echo "❌ 不支持的 Linux 包管理器，请手动安装 $pkg"
        exit 1
      fi
      ;;
    alpine)
      sudo apk add "$pkg"
      ;;
    darwin)
      echo "⚠️ macOS 请确认已安装 $pkg，如无请手动安装"
      ;;
    *)
      echo "❌ 不支持的操作系统，请手动安装 $pkg"
      exit 1
      ;;
  esac
}

# 初始化变量
GOLANG_MIRROR="${GOLANG_MIRROR:-"https://mirrors.aliyun.com/golang"}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local}"
PROFILE_FILE=$(detect_profile_file)

OS=$(get_os)
ARCH=$(get_arch)

if [ "$ARCH" = "unsupported" ]; then
echo "❌ 不支持的架构: $(uname -m)"
exit 1
fi

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

echo "📌 将安装 Go 版本: $GO_VERSION"
echo "🌏 系统类型: $OS"
echo "🧱 架构: $ARCH"
echo "📂 安装目录: $INSTALL_DIR"
echo "⚙️ 环境配置文件: $PROFILE_FILE"

# 安装依赖 wget 和 tar
install_deps "$OS" wget
install_deps "$OS" tar

TARFILE="go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
DOWNLOAD_URL="${GOLANG_MIRROR}/${TARFILE}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "⬇️ 正在下载：$DOWNLOAD_URL"
wget --progress=dot:giga -O "$TMPDIR/go.tar.gz" "$DOWNLOAD_URL"

echo "🧹 删除旧版本 Go（如果存在）"
sudo rm -rf "$INSTALL_DIR/go"

echo "📦 解压 Go 到 $INSTALL_DIR"
sudo tar -C "$INSTALL_DIR" -xzf "$TMPDIR/go.tar.gz"

# 写入环境变量（避免重复）
if ! grep -q '### Go env start ###' "$PROFILE_FILE" 2>/dev/null; then
cat >> "$PROFILE_FILE" <<EOF

### Go env start ###
export GO_HOME=$INSTALL_DIR/go
export GOPATH=\$HOME/go
export PATH=\$GO_HOME/bin:\$GOPATH/bin:\$PATH
### Go env end ###
EOF
echo "✅ 环境变量已写入 $PROFILE_FILE"
else
echo "ℹ️ 环境变量已存在于 $PROFILE_FILE，跳过写入"
fi

echo ""
echo "🎉 安装完成，请运行以下命令让环境变量生效："
echo "    source $PROFILE_FILE"
echo "或者重新打开一个终端窗口。"
echo ""
echo "Go 版本信息："
"$INSTALL_DIR/go/bin/go" version