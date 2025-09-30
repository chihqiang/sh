#!/bin/bash
set -e


# -----------------------------------------------------------------------------
# 脚本名称: svn2git.sh
# 功能描述: 将标准 SVN 仓库（trunk/branches/tags 结构）迁移为 Git 仓库，
#           支持自动安装依赖、转换 tags、检测远程冲突并推送。
#
# 使用说明:
#   - 支持通过环境变量传入参数：SVN_REPO、GIT_REMOTE_URL、TARGET_DIR（可选）
#   - 也支持无环境变量时交互式输入
#   - 依赖 git-svn 和 subversion（自动安装支持 apt/yum/brew）
#
# 示例:
#   export SVN_REPO="svn://svn.code.sf.net/p/sshpass/code"
#   export GIT_REMOTE_URL="https://cnb.cool/chihqiang/lib/sshpass.git"
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/svn2git.sh)"
#
# 注意事项:
#   - 请确保有相应的 SVN 和 Git 访问权限
#   - 该脚本假设 SVN 仓库采用标准布局（trunk/branches/tags）
#   - 迁移过程中会删除 TARGET_DIR 目录，请勿指定重要目录
#
# Author: zhiqiang
# Date: 2025-07-24
# -----------------------------------------------------------------------------
#!/bin/bash
set -e

SVN_REPO="${SVN_REPO:-}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-}"
TARGET_DIR="${TARGET_DIR:-".tmp"}"

# 读取 SVN_REPO
if [ -z "$SVN_REPO" ]; then
    read -p "请输入 SVN 仓库地址（SVN_REPO）: " SVN_REPO
    if [ -z "$SVN_REPO" ]; then
        echo "❌ 未提供 SVN_REPO，退出。"
        exit 1
    fi
fi

# 读取 GIT_REMOTE_URL
if [ -z "$GIT_REMOTE_URL" ]; then
    read -p "请输入 Git 远程仓库地址（GIT_REMOTE_URL）: " GIT_REMOTE_URL
    if [ -z "$GIT_REMOTE_URL" ]; then
        echo "❌ 未提供 GIT_REMOTE_URL，退出。"
        exit 1
    fi
fi

echo "✅ 使用的 SVN_REPO: $SVN_REPO"
echo "✅ 使用的 GIT_REMOTE_URL: $GIT_REMOTE_URL"

install_deps() {
  if command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y git-svn subversion
  elif command -v yum &>/dev/null; then
    sudo yum install -y git git-svn subversion
  elif command -v brew &>/dev/null; then
    brew install git-svn subversion
  else
    echo "不支持的系统，请手动安装 git-svn 和 subversion"
    exit 1
  fi
}

# 检查 git 是否支持 svn 子命令，以及 svn 命令是否存在
if ! git svn --version &>/dev/null || ! command -v svn &>/dev/null; then
  install_deps
  echo "缺少 git svn 或 subversion"
else
  echo "已安装 git-svn 和 subversion"
fi

# 2. 克隆 SVN 仓库（stdlayout）
echo "克隆 SVN 仓库..."
rm -rf "$TARGET_DIR"
git svn clone --stdlayout "$SVN_REPO" "$TARGET_DIR"

cd "$TARGET_DIR"

# 3. 转换 tags（跳过已存在的）
echo "转换 SVN tags 为 Git 标签"
for tag in $(git branch -r | grep 'tags/' | sed 's|  remotes/||'); do
  tagname=$(echo "$tag" | sed 's|tags/||')

  if git rev-parse "refs/tags/$tagname" >/dev/null 2>&1; then
    echo "⚠️  标签 $tagname 已存在，跳过"
    continue
  fi

  echo "✅ 创建 tag: $tagname"
  git tag -a "$tagname" -m "Imported from SVN" "remotes/$tag"
done

# 4. 清理 remotes 和 svn 数据
echo "清理远程分支和 SVN 元数据"
rm -rf .git/svn .git/logs/refs/remotes
for b in $(git branch -r); do
  git branch -rd "$b"
done

# 5. 添加远程仓库
echo "添加 Git 远程仓库: $GIT_REMOTE_URL"
git remote add origin "$GIT_REMOTE_URL"

# 6. 检查远程分支是否存在
echo "检查远程仓库状态..."
git fetch origin || true

REMOTE_HAS_MASTER=$(git ls-remote --heads origin master | wc -l)
REMOTE_HAS_MAIN=$(git ls-remote --heads origin main | wc -l)

# 推送策略
FORCE_PUSH=0
if [[ $REMOTE_HAS_MASTER -gt 0 || $REMOTE_HAS_MAIN -gt 0 ]]; then
  echo "🚨 检测到远程已存在分支：master 或 main"
  FORCE_PUSH=1
fi

# 推送
echo "开始推送..."
if [[ $FORCE_PUSH -eq 1 ]]; then
  echo "⚠️ 正在强制推送分支..."
  git push origin master --force || git push origin main --force
else
  echo "✅ 正常推送分支..."
  git push origin master || git push origin main
fi

# 7.1 推送 tag（仅推送远程不存在的）
echo "🔍 正在选择性推送本地 tags..."
REMOTE_TAGS=$(git ls-remote --tags origin | grep -v '\^{}' | awk '{print $2}' | sed 's|refs/tags/||')
for tag in $(git tag); do
  if echo "$REMOTE_TAGS" | grep -q "^$tag$"; then
    echo "⚠️  远程已存在 tag: $tag，跳过"
  else
    echo "🚀 推送 tag: $tag"
    git push origin "refs/tags/$tag"
  fi
done

echo "🎉 推送完成。你已成功将 SVN 仓库迁移为 Git 仓库。"
