# -----------------------------------------------------------------------------
# 脚本名称: del-current-branch.sh
# 功能描述: 交互式安全删除当前 Git 分支，自动切换到主分支，支持删除本地分支，
#           并可选择同步删除远程分支，保护核心分支防止误删。
#
# 使用说明:
#   - 直接在 Git 仓库目录下运行脚本
#   - 会自动检测当前所在分支，禁止删除 main/master/develop/test 保护分支
#   - 分步询问：确认删除本地 → 自动切主分支 → 执行删除
#   - 本地删除后，再次询问是否同步删除远程同名分支
#
# 示例:
#  bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/delete-current-branch.sh)"
#
# 注意事项:
#   - 无法删除当前所在分支，脚本会自动切换到主分支后删除
#   - 强制删除会丢失未合并代码，执行前请确认分支已无用
#   - 删除远程分支需拥有对应仓库权限
#
# Author: zhiqiang
# Date: 2025-12-29
# -----------------------------------------------------------------------------
#!/bin/bash
set -euo pipefail

# 获取当前所在分支
current_branch=$(git symbolic-ref --short HEAD)
echo "当前所在分支: $current_branch"

# 保护分支列表
protect_branches=("main" "master" "develop" "test")
if [[ " ${protect_branches[@]} " =~ " ${current_branch} " ]]; then
    echo -e "\033[31m[错误] 禁止删除受保护分支：$current_branch\033[0m"
    exit 1
fi

# 确认删除本地分支
read -p "确定删除本地分支【${current_branch}】? [y/N] " local_confirm
if [[ ! $local_confirm =~ ^[Yy]$ ]]; then
    echo "已取消删除本地分支"
    exit 0
fi

# 自动切换到可用主分支
if git show-ref --verify --quiet refs/heads/main; then
    git switch main
elif git show-ref --verify --quiet refs/heads/master; then
    git switch master
else
    echo -e "\033[31m[错误] 未找到 main/master 基准分支\033[0m"
    exit 1
fi

# 删除本地当前分支
git branch -D "$current_branch"
echo -e "\033[32m✓ 本地分支已删除：$current_branch\033[0m"

# 询问是否删除远程
read -p "是否同步删除远程分支【${current_branch}】? [y/N] " remote_confirm
if [[ $remote_confirm =~ ^[Yy]$ ]]; then
    git push origin --delete "$current_branch"
    echo -e "\033[32m✓ 远程分支已删除：$current_branch\033[0m"
else
    echo "已跳过删除远程分支"
fi

echo -e "\033[32m🎉 操作完成\033[0m"