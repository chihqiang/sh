#!/bin/bash

# ===============================================================
# 🚀 Git 历史邮箱和用户名批量修改工具
# ✅ 环境变量支持（可在执行前设置）：
#   - OLD_EMAIL      需要替换的旧邮箱地址（必填）
#   - CORRECT_NAME   新的用户名（可选，默认读取 git config）
#   - CORRECT_EMAIL  新的邮箱地址（可选，默认读取 git config）
#   - CONFIRM_YES    若设置为任意值，将跳过 y/n 确认提示
#   - PUSH_YES 若设置为任意值，将跳过 y/n 确认提示
# 
# 本脚本用于批量修改 Git 仓库历史提交中的邮箱和用户名：
#   ✅ 支持通过环境变量或交互输入旧邮箱
#   ✅ 自动从 git config 获取新用户名和邮箱
#   ✅ 支持全部分支和标签
#   ✅ 自动确认执行
#   ✅ 彩色输出，美观直观
#
# 👉 使用方式（在仓库根目录直接运行）：
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/commit-fixup.sh)"
#
# 注意事项：
#   - ⚠️ 会重写 Git 历史记录，请提前备份
#   - 修改后需强制推送远程仓库：git push origin --force --all --tags
#
# 作者：zhiqiang
# ===============================================================


# === 定义彩色输出函数 ===
color_echo() {
  local color=$1
  shift
  echo -e "\033[${color}m$@\033[0m"
}

info()    { color_echo "1;34" "🔧 $@"; }  # 蓝色
success() { color_echo "1;32" "✅ $@"; }  # 绿色
warning() { color_echo "1;33" "⚠️  $@"; }  # 黄色
error()   { color_echo "1;31" "❌ $@"; }  # 红色

# === 彩色输出函数 ===
color_echo() {
  local color=$1
  shift
  echo -e "\033[${color}m$@\033[0m"
}
info()    { color_echo "1;34" "🔧 $@"; }  # 蓝色
success() { color_echo "1;32" "✅ $@"; }  # 绿色
warning() { color_echo "1;33" "⚠️  $@"; }  # 黄色
error()   { color_echo "1;31" "❌ $@"; }  # 红色

# 获取 Git 用户信息（支持环境变量、本地配置、全局配置）
git_config_env() {
  local env_value="${!1}"
  local config_key="$2"
  if [ -n "$env_value" ]; then
    echo "$env_value"
    return
  fi
  local local_value
  local_value="$(git config "$config_key" 2>/dev/null)"
  if [ -n "$local_value" ]; then
    echo "$local_value"
    return
  fi

  local global_value
  global_value="$(git config --global "$config_key" 2>/dev/null)"
  if [ -n "$global_value" ]; then
    echo "$global_value"
    return
  fi
}

info "Git 历史邮箱和用户名批量修改工具"
echo

# 获取用户名和邮箱（按优先级）
CORRECT_NAME="$(git_config_env CORRECT_NAME user.name)"
CORRECT_EMAIL="$(git_config_env CORRECT_EMAIL user.email)"

# === 如果未配置则提示用户输入 ===
if [ -z "$CORRECT_NAME" ] || [ -z "$CORRECT_EMAIL" ]; then
  warning "未检测到 git 用户名或邮箱配置，需手动输入："
  if [ -z "$CORRECT_NAME" ]; then
    read -p "请输入新的用户名: " CORRECT_NAME
  fi
  if [ -z "$CORRECT_EMAIL" ]; then
    read -p "请输入新的邮箱: " CORRECT_EMAIL
  fi
else
  success "检测到默认用户名：$CORRECT_NAME"
  success "检测到默认邮箱：$CORRECT_EMAIL"
fi

# === 获取旧邮箱 ===
if [ -z "$OLD_EMAIL" ]; then
  read -p "请输入旧邮箱（要替换的邮箱）: " OLD_EMAIL
  if [ -z "$OLD_EMAIL" ]; then
    error "旧邮箱不能为空！"
    exit 1
  fi
else
  success "已从环境变量中读取旧邮箱：$OLD_EMAIL"
fi

# === 显示将要执行的修改 ===
echo
info "准备将历史中邮箱为 \"$OLD_EMAIL\" 的提交者信息修改为："
info "  👤 用户名：$CORRECT_NAME"
info "  📧 邮箱：  $CORRECT_EMAIL"

# === 用户确认 ===
if [ -n "$CONFIRM_YES" ]; then
  confirm="y"
  success "检测到环境变量 CONFIRM_YES，自动确认执行。"
else
  read -p "确认执行？(y/n): " confirm
fi

case "$confirm" in
  [Yy]) ;;
  *) warning "用户取消操作。"; exit 0 ;;
esac

info "开始执行 git filter-branch，可能会耗费一些时间，请耐心等待..."
git filter-branch --env-filter '
OLD_EMAIL="'"$OLD_EMAIL"'"
CORRECT_NAME="'"$CORRECT_NAME"'"
CORRECT_EMAIL="'"$CORRECT_EMAIL"'"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags > /dev/null 2>&1

if [ $? -ne 0 ]; then
  error "执行失败，请检查仓库状态和权限。"
  exit 1
fi

success "完成！历史提交信息已修改。"

# === 是否推送到远程仓库 ===
if [ -n "$PUSH_YES" ]; then
  push_confirm="y"
  success "检测到环境变量 PUSH_YES，自动执行远程推送。"
else
  read -p "是否推送到远程仓库？(y/n): " push_confirm
fi

if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
  info "正在推送全部分支（--force --all）..."
  git push origin --force --all

  info "正在推送全部标签（--force --tags）..."
  git push origin --force --tags

  success "✅ 已成功推送到远程仓库。"
else
  warning "已跳过远程推送，请手动执行以下命令："
  echo "  git push origin --force --all"
  echo "  git push origin --force --tags"
fi
