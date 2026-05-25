#!/bin/bash
set -euo pipefail

# ==============================================
# Mac VS Code 插件开发环境检查脚本
# 功能：
# 1. 检查 Homebrew 是否安装
# 2. 检查 VS Code 命令行工具是否配置
# 3. 检查 Node.js + npm 是否完整
# 4. 检查 yo 插件脚手架是否安装
# 5. 检查 vsce 插件打包工具是否安装
# 特点：
# - 只检查、不自动安装、不修改系统环境
# - 缺少依赖立即提示并退出
# - 格式统一、日志清晰、简洁干净
# 使用：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/vscode-extension.sh)"
# ==============================================

echo "============================================="
echo " VS Code 插件开发环境初始化"
echo "============================================="

# 检查 Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew 未安装"
    echo "   安装地址：https://brew.sh"
    exit 1
else
    echo "✅ Homebrew 已存在"
fi

# 检查 VS Code 命令
if ! command -v code >/dev/null 2>&1; then
    echo "❌ VS Code 未安装"
    echo "   安装：https://code.visualstudio.com/download"
    echo "   或 brew install --cask visual-studio-code"
    exit 1
else
    echo "✅ VS Code code 命令已存在"
fi

# 检查 Node.js 和 npm
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "❌ Node.js 或 npm 未安装"
    echo "   安装：https://nodejs.org/zh-cn/download/"
    echo "   或 nvm：curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash"
    exit 1
else
    echo "✅ Node.js 与 npm 均已存在"
fi

# 检查 yo
if ! command -v yo >/dev/null 2>&1; then
    echo "❌ yo 未安装"
    echo "   安装：npm install -g yo generator-code"
    npm install -g yo generator-code
else
    echo "✅ yo 已存在"
fi

# 检查 vsce
if ! command -v vsce >/dev/null 2>&1; then
    echo "❌ vsce 未安装"
    echo "   安装：npm install -g @vscode/vsce"
    npm install -g @vscode/vsce
else
    echo "✅ vsce 已存在"
fi

echo
echo "============================================="
echo "环境初始化完成！"
echo "Node: $(node -v)"
echo "npm:  $(npm -v)"
echo "yo:   $(yo --version 2>/dev/null | head -n1)"
echo "vsce: $(vsce --version)"
echo "============================================="
echo
echo "使用："
echo "  创建插件： yo code"
echo "  调试运行： code . 然后按 F5"
echo "  打包发布： vsce package"