#!/bin/bash
current_branch=$(git symbolic-ref --short HEAD) || { echo "获取当前分支失败"; exit 1; }
echo "您当前的分支是: ${current_branch}"
# 提示用户输入目标分支（默认是 test）
read -p "请输入目标分支名称（默认是 test）：" target_branch
target_branch=${target_branch:-test}
# 检查目标分支是否存在
if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
  echo "目标分支 $target_branch 不存在!"
  exit 1
fi
# 显示当前分支和目标分支信息
echo "当前分支是: $current_branch"
echo "目标分支是: $target_branch"
# 确认是否合并
read -p "是否将当前分支 '$current_branch' 合并到 '$target_branch' 分支? (y/n): " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "操作已取消."
  exit 0
fi

# 切换到目标分支
git checkout "$target_branch" || { echo "切换到 $target_branch 分支失败！"; exit 1; }
# 拉取最新的目标分支
git pull origin "$target_branch" || { echo "拉取 $target_branch 分支失败！"; exit 1; }
# 合并当前分支到目标分支
git merge "$current_branch" || { echo "合并失败，存在冲突！"; exit 1; }

# 询问是否推送到远程
read -p "合并成功！是否将更改推送到远程 $target_branch 分支? (y/n): " push_confirmation
if [[ "$push_confirmation" =~ ^[Yy]$ ]]; then
  # 推送到远程
  git push origin "$target_branch" || { echo "推送到远程失败！"; exit 1; }
  echo "更改已推送到远程 $target_branch 分支。"
else
  echo "操作已取消，未推送到远程。"
  exit 0
fi

read -p "分支已经完成合并是否回到 '$current_branch' 分支? (y/n): " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "切换到 $current_branch 已取消."
  exit 0
fi
git checkout "$current_branch" || { echo "切换到 $current_branch 分支失败！"; exit 1; }

