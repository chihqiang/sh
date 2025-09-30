#!/bin/bash
set -euo pipefail

# ==============================================================================
# 脚本功能：
#   自动下载安装指定版本的二进制文件并安装到指定目录。
#
# 环境变量参数：
#   VERSION           - 目标版本号（必填）
#   GIT_DOMAIN        - Git仓库域名（如 github.com、gitee.com、gitea.com、cnb.cool）
#   GIT_USERNAME      - 仓库用户名或组织名（必填）
#   GIT_REPO          - 仓库名（必填）
#   BIN_NAME          - 目标二进制文件名称（必填）
#   INSTALL_DIR       - 安装目录，默认 /usr/local/bin
#   RELEASES_FILE_EXT - 发布文件扩展名，默认 tar.gz，可支持 zip
#
# 使用示例（远程执行）：
#   export VERSION=v0.0.1 GIT_DOMAIN=cnb.cool GIT_USERNAME=zhiqiangwang GIT_REPO=tlsctl BIN_NAME=tlsctl
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/golangs.sh)"
# 
#   export VERSION=v0.0.1 GIT_REPO_ADDR="https://cnb.cool/zhiqiangwang/sshtun.git"
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/golangs.sh)"
#
# 主要流程：
#   1. 参数校验
#   2. 根据平台和架构构造下载链接
#   3. 下载压缩包并解压
#   4. 移动二进制文件到安装目录
#   5. 权限设置及安装验证
#
# 适用场景：
#   自动化部署、CI/CD、简化安装流程等
# ==============================================================================


# ========= 默认参数 =========
VERSION="${VERSION:-""}"
GIT_REPO_ADDR="${GIT_REPO_ADDR:-""}"

GIT_DOMAIN="${GIT_DOMAIN:-""}"
GIT_USERNAME="${GIT_USERNAME:-""}"
GIT_REPO="${GIT_REPO:-""}"
BIN_NAME="${BIN_NAME:-""}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
RELEASES_FILE_EXT="${RELEASES_FILE_EXT:-tar.gz}"


# ========= 从 GIT_REPO_ADDR 自动解析相关参数 =========
if [[ -n "$GIT_REPO_ADDR" ]]; then
  echo "🔍 正在从 GIT_REPO_ADDR 自动解析：$GIT_REPO_ADDR"

  # 去除协议、.git 后缀，替换冒号为斜杠
  GIT_CLEAN_ADDR=$(echo "$GIT_REPO_ADDR" | sed -E 's#(https?://|git@)##; s#\.git$##')
  GIT_CLEAN_ADDR=${GIT_CLEAN_ADDR//:/\/}

  [[ -z "$GIT_DOMAIN" ]]   && GIT_DOMAIN=$(echo "$GIT_CLEAN_ADDR" | cut -d'/' -f1)
  GIT_PATH=$(echo "$GIT_CLEAN_ADDR" | cut -d'/' -f2-)
  [[ -z "$GIT_USERNAME" ]] && GIT_USERNAME=$(echo "$GIT_PATH" | cut -d'/' -f1)

  if [[ -z "$GIT_REPO" ]]; then
    GIT_REPO=$(echo "$GIT_PATH" | cut -d'/' -f2- | sed 's/\.git$//' | tr -d '[:space:]' | tr -d '“”')
  fi

  if [[ -z "$BIN_NAME" ]]; then
    BIN_NAME=$(basename "$GIT_REPO" | tr -d '[:space:]' | tr -d '“”')
  fi
fi



# ========= 参数校验 =========
if [[ -z "$VERSION" || -z "$GIT_USERNAME" || -z "$GIT_REPO" || -z "$BIN_NAME" ]]; then
  echo "❌ 错误：必须通过环境变量传入 VERSION、GIT_USERNAME、GIT_REPO 和 BIN_NAME"
  exit 1
fi

# ========= 安装目录准备 =========
if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "📁 安装目录 $INSTALL_DIR 不存在，正在创建..."
  mkdir -p "$INSTALL_DIR"
fi
if [[ ! -w "$INSTALL_DIR" ]]; then
  echo "❌ 安装目录 $INSTALL_DIR 不可写，请使用 sudo 或更改权限"
  exit 1
fi

# ========= 系统架构检测 =========
ARCH=$(uname -m)
OS=$(uname | tr '[:upper:]' '[:lower:]')
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  i386|i686) ARCH="386" ;;
  *) echo "❌ 不支持的架构：$ARCH"; exit 1 ;;
esac

# ========= 下载地址构造 =========
FILENAME="${BIN_NAME}_${OS}_${ARCH}.${RELEASES_FILE_EXT}"
VERSION_FILENAME="${VERSION}/${FILENAME}"

case "$GIT_DOMAIN" in
  *gitee*)
    echo "🔧 检测到 Gitee 平台"
    DOWNLOAD_URL="https://gitee.com/${GIT_USERNAME}/${GIT_REPO}/releases/download/${VERSION_FILENAME}" ;;
  *github*)
    echo "🔧 检测到 Github 平台"
    DOWNLOAD_URL="https://github.com/${GIT_USERNAME}/${GIT_REPO}/releases/download/${VERSION_FILENAME}" ;;
  *gitea*)
    echo "🔧 检测到 Gitea 平台"
    DOWNLOAD_URL="https://gitea.com/${GIT_USERNAME}/${GIT_REPO}/releases/download/${VERSION_FILENAME}" ;;
  *cnb*)
    echo "🔧 检测到 CNB 平台"
    DOWNLOAD_URL="https://cnb.cool/${GIT_USERNAME}/${GIT_REPO}/-/releases/download/${VERSION_FILENAME}" ;;
  *)
    echo "⚠️ 未知平台 ${GIT_DOMAIN}，使用 GitHub 风格兜底"
    DOWNLOAD_URL="https://${GIT_DOMAIN}/${GIT_USERNAME}/${GIT_REPO}/releases/download/${VERSION_FILENAME}" ;;
esac

# ========= 信息展示 =========
echo "🛠️ 安装配置如下："
echo "   ➤ VERSION:     $VERSION"
echo "   ➤ GIT_USERNAME:$GIT_USERNAME"
echo "   ➤ GIT_REPO:    $GIT_REPO"
echo "   ➤ BIN_NAME:    $BIN_NAME"
echo "   ➤ OS/ARCH:     $OS/$ARCH"
echo "   ➤ INSTALL_DIR: $INSTALL_DIR"
echo "⬇️  下载地址:     $DOWNLOAD_URL"

# ========= 判断是否需要 sudo =========
SUDO=""
if [ "$(id -u)" -ne 0 ] && [[ ! -w "$INSTALL_DIR" ]]; then
  SUDO="sudo"
fi

# ========= 下载并解压 =========
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

ARCHIVE_PATH="${TEMP_DIR}/${BIN_NAME}.${RELEASES_FILE_EXT}"

echo "📥 正在下载..."
if ! wget --progress=dot:mega "$DOWNLOAD_URL" -O "$ARCHIVE_PATH"; then
  echo "❌ 下载失败：$DOWNLOAD_URL"
  exit 1
fi

echo "📦 正在解压..."
mkdir -p "$TEMP_DIR/unpack"
if [[ "$RELEASES_FILE_EXT" == "zip" ]]; then
  unzip -q "$ARCHIVE_PATH" -d "$TEMP_DIR/unpack"
else
  tar -zxf "$ARCHIVE_PATH" -C "$TEMP_DIR/unpack"
fi

FOUND_BIN=$(find "$TEMP_DIR/unpack" -type f -name "$BIN_NAME" -perm -111 | head -n1)
if [[ -z "$FOUND_BIN" ]]; then
  echo "❌ 解压后未找到可执行文件：$BIN_NAME"
  exit 1
fi

# ========= 安装 =========
echo "🧹 清理旧版本（如有）..."
$SUDO rm -f "${INSTALL_DIR}/${BIN_NAME}"

echo "🚀 安装 $BIN_NAME 到 $INSTALL_DIR..."
$SUDO install -m 755 "$FOUND_BIN" "${INSTALL_DIR}/${BIN_NAME}"

# ========= 校验 =========
echo "🔍 验证安装..."
if ! "${INSTALL_DIR}/${BIN_NAME}" --help >/dev/null 2>&1; then
  echo "❌ 安装失败：${BIN_NAME} 无法执行"
  exit 1
fi

echo "🎉 ${BIN_NAME} ${VERSION} 安装成功！路径：${INSTALL_DIR}/${BIN_NAME}"
