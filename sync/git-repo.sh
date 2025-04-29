#!/bin/bash

# export SOURCE_USERNAME="your_source_username" SOURCE_PASSWORD="your_source_password" TARGET_USERNAME="your_target_username" TARGET_PASSWORD="your_target_password"
# bash git-repo.sh https://github.com/username/repo.git https://gitee.com/username/repo.git
# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/sync/git-repo.sh | bash -s https://github.com/username/repo.git https://gitee.com/username/repo.git

# 临时目录
TEMP_PATH="$(pwd)/git-sync-code"

ARG_SOURCE_REMOTE=$1
ARG_TARGET_REMOTE=$2

# GitHub 仓库信息
SOURCE_USERNAME="${SOURCE_USERNAME:-}"
SOURCE_PASSWORD="${SOURCE_PASSWORD:-}"
SOURCE_REMOTE=${ARG_SOURCE_REMOTE}

# Gitee 仓库信息
TARGET_USERNAME="${TARGET_USERNAME:-}"
TARGET_PASSWORD="${TARGET_PASSWORD:-}"
TARGET_REMOTE="${ARG_TARGET_REMOTE}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 检查参数是否足够
if [ "$#" -lt 2 ]; then
  log "错误：请提供源仓库地址和目标仓库地址。"
  log "用法：$0 <source-remote> <target-remote>"
  exit 1
fi

log "来源仓库地址：${SOURCE_REMOTE}"
log "目标仓库地址：${TARGET_REMOTE}"

# 如果临时目录存在，清理旧文件
if [ -d "$TEMP_PATH" ]; then
  log "清理旧的临时目录..."
  rm -rf "$TEMP_PATH"
fi

# 拼接带认证信息的仓库地址
if [ -n "$SOURCE_USERNAME" ] && [ -n "$SOURCE_PASSWORD" ]; then
  AUTH_SOURCE_REMOTE="https://${SOURCE_USERNAME}:${SOURCE_PASSWORD}@${SOURCE_REMOTE#https://}"
else
  AUTH_SOURCE_REMOTE="$SOURCE_REMOTE"
fi


if [ -n "$TARGET_USERNAME" ] && [ -n "$TARGET_PASSWORD" ]; then
  AUTH_TARGET_REMOTE="https://${TARGET_USERNAME}:${TARGET_PASSWORD}@${TARGET_REMOTE#https://}"
else
  AUTH_TARGET_REMOTE="$TARGET_REMOTE"
fi


log "克隆仓库（包含所有分支和标签）到临时目录..."
git clone --mirror "$AUTH_SOURCE_REMOTE" "$TEMP_PATH"
if [ $? -ne 0 ]; then
  log "克隆仓库失败，请检查 URL 或认证信息是否正确。"
  exit 1
fi

cd "$TEMP_PATH" || { log "无法进入临时目录，迁移中止。"; exit 1; }

log "设置目标仓库远程地址..."
git remote set-url --push origin "$AUTH_TARGET_REMOTE"
if [ $? -ne 0 ]; then
  log "设置仓库远程地址失败，请检查 URL 或认证信息是否正确。"
  exit 1
fi

log "推送所有分支和标签到仓库中..."
git push --mirror
if [ $? -ne 0 ]; then
  log "推送到仓库失败，请检查网络连接或权限。"
  exit 1
fi

# 清理临时文件
cd ..
rm -rf "$TEMP_PATH"

log "迁移完成！"
