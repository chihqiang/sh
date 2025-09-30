#!/bin/bash


# ===============================================================
# 🚀 Git 分支合并工具
#
# 本脚本用于简化 Git 分支的合并流程，并提供交互式配置：
#   ✅ 自动获取当前分支
#   ✅ 支持指定目标分支进行合并
#   ✅ 检查目标分支是否存在
#   ✅ 支持合并前确认
#   ✅ 合并完成后支持推送到远程分支
#   ✅ 支持切换回原分支
#   ✅ 美化输出，操作更加清晰
#
# 👉 使用方式（直接运行）：
#    wget -O /usr/local/bin/gcpmp https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main//git/cpmp.sh && chmod +x /usr/local/bin/gcpmp
#
# 要求：
#   - Git 已安装并配置
#   - 当前仓库存在多个分支
#   - 目标分支存在
#
# 作者：zhiqiang
# ===============================================================

# === 函数：带颜色的 echo ===
# color_echo: 输出带颜色的文本
# $1 是颜色代码，$@ 是要输出的内容
color_echo() {
  local color_code=$1
  shift
  echo -e "\033[${color_code}m$@\033[0m"
}

# === 自定义输出函数 ===
# info: 输出蓝色的提示信息
info()    { color_echo "1;34" "🔧 $@"; }  # 蓝色
# success: 输出绿色的成功信息
success() { color_echo "1;32" "✅ $@"; }  # 绿色
# warning: 输出黄色的警告信息
warning() { color_echo "1;33" "⚠️  $@"; }  # 黄色
# error: 输出红色的错误信息
error()   { color_echo "1;31" "❌ $@"; }  # 红色
# step: 输出青色的步骤提示信息
step()    { color_echo "1;36" "🚀 $@"; }  # 青色
# divider: 输出分隔符
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }  # 分隔符


# === 获取当前分支名称 ===
current_branch=$(git rev-parse --abbrev-ref HEAD)

# 判断是否通过脚本参数传入目标分支（优先级最高）
if [ -n "$1" ]; then
  target_branch="$1"  # 使用第一个位置参数作为目标分支
  info "从脚本参数获取目标分支: $target_branch"
# 如果没有传参数，则检查是否设置了环境变量 G_TARGET_BRANCH
elif [ -n "$G_TARGET_BRANCH" ]; then
  target_branch="$G_TARGET_BRANCH"  # 使用环境变量中的分支名
  info "从环境变量获取的目标分支 G_TARGET_BRANCH: $target_branch"
# 如果都没有提供，则提示用户手动输入（可回车使用默认值）
else
  read -p "请输入目标分支名称 (default is 'main'): " input_branch
  target_branch="${input_branch:-main}"  # 如果用户输入为空，使用 main 作为默认值
fi
# === 检查当前分支是否是目标分支 ===
if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
  step "本地不存在目标分支 '$target_branch'，尝试从远程拉取..."
  # 检查远程是否存在该分支
  if git ls-remote --exit-code --heads origin "$target_branch" > /dev/null 2>&1; then
    git fetch origin "$target_branch":"$target_branch" || {
      error "从远程拉取 '$target_branch' 分支失败！"
      exit 1
    }
    success "成功从远程创建本地分支 '$target_branch'"
  else
    error "远程也不存在分支 '$target_branch'，请确认分支名是否正确。"
    exit 1
  fi
fi

info "当前分支是: $current_branch"
info "目标分支是: $target_branch"

# === 确认是否进行合并 ===
# 提示用户确认是否合并当前分支到目标分支
read -p "是否将当前分支 '$current_branch' 合并到 '$target_branch' 分支? (y/n): " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "操作已取消."
  exit 0
fi

# === 切换到目标分支 ===
# 使用 git checkout 命令切换到目标分支
step "正在切换到目标分支 '$target_branch' ..."
git checkout "$target_branch" || { error "切换到 $target_branch 分支失败！"; exit 1; }

# === 拉取目标分支的最新代码 ===
# 使用 git pull 命令从远程拉取目标分支的最新代码
step "拉取最新的目标分支 $target_branch ..."
git pull origin "$target_branch" || { error "拉取 $target_branch 分支失败！"; exit 1; }

# === 合并当前分支到目标分支 ===
# 使用 git merge 命令将当前分支的更改合并到目标分支
step "正在合并当前分支 '$current_branch' 到目标分支 '$target_branch' ..."
git merge "$current_branch" || { error "合并失败，存在冲突！"; exit 1; }

# === 询问是否推送到远程 ===
# 合并成功后，询问用户是否将更改推送到远程目标分支
read -p "合并成功！是否将更改推送到远程 $target_branch 分支? (y/n): " push_confirmation
if [[ "$push_confirmation" =~ ^[Yy]$ ]]; then
  step "正在推送更改到远程 $target_branch ..."
  git push origin "$target_branch" || { error "推送到远程失败！"; exit 1; }
  success "更改已推送到远程 $target_branch 分支。"
else
  echo "操作已取消，未推送到远程。"
  exit 0
fi

# === 询问是否切换回原分支 ===
# 提示用户是否回到原来的分支
read -p "分支已经完成合并，是否回到 '$current_branch' 分支? (y/n): " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "切换到 $current_branch 已取消."
  exit 0
fi

# === 切换回原分支 ===
# 使用 git checkout 命令切换回原来的分支
step "正在切换回原分支 '$current_branch' ..."
git checkout "$current_branch" || { error "切换到 $current_branch 分支失败！"; exit 1; }

# 输出分隔符，表示操作结束
divider
success "操作完成！"