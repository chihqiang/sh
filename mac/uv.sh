#!/bin/bash
set -euo pipefail
# ==============================================
# Mac 开发环境自动安装脚本
# 功能：
# 1. 检查并安装 Homebrew
# 2. 检查并安装 UV 包管理器
# 3. 批量安装代码规范工具：ruff, black, isort
# 特点：
# - 所有工具先判断，不重复安装
# - 使用数组管理工具列表，易于扩展
# - 日志干净美观，无冗余输出
# 使用
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/uv.sh)"
# ==============================================
info() {
  echo -e "\033[32m✅ $1\033[0m"
}

step() {
  echo -e "\n\033[34m===== $1 =====\033[0m"
}

# ======================================
# 工具数组：代码格式化工具
# 可以根据需要添加其他工具
# ======================================
TOOLS=("ruff" "black" "isort")

echo "=================================================="
echo "      Mac 开发环境检查与安装脚本"
echo "=================================================="

# 1. 检查安装 brew
step "检查 Homebrew"
if ! command -v brew &> /dev/null; then
  echo "未安装，正在安装 Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  info "Homebrew 安装完成"
else
  info "Homebrew 已存在"
fi

# 2. 检查安装 uv
step "检查 UV 包管理器"
if ! command -v uv &> /dev/null; then
  echo "未安装，通过 brew 安装..."
  brew install uv
  info "UV 安装完成"
else
  info "UV 已存在"
fi

# 3. 数组循环安装工具（自动判断是否已安装）
step "检查并安装代码格式化工具"
for tool in "${TOOLS[@]}"; do
  echo -n "检查 $tool ... "
  if uv tool list | grep -q "^$tool "; then
    info "已存在"
  else
    echo "未安装，开始安装..."
    uv tool install "$tool"
    info "$tool 安装成功"
  fi
done

step "检查项目并自动格式化代码"
if [ -f "uv.lock" ]; then
  echo "✅ 发现 uv.lock，使用项目环境自动格式化..."
  uv run ruff check --fix .
  uv run black .
  uv run isort .
  info "代码格式化完成！"
else
  info "当前目录不是 UV 项目，跳过格式化"
fi
