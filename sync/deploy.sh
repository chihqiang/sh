#!/bin/bash

# export SSH_HOST="127.0.0.1" SSH_PORT="22" SSH_USER="root" SSH_PASSWORD="123456"
# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/sync/deploy.sh| bash


# 一旦有命令失败，立即退出
set -e

# 定义日志记录函数
log() { 
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" # 输出带时间戳的日志信息
}

# 捕获错误的处理函数
cleanup_on_error() {
  log "脚本执行失败！正在清理资源..." # 打印错误信息
  ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "rm -f ${TAR_REMOTE_FILE}" || true # 删除远程临时文件，忽略错误
  rm -f "${TAR_LOCAL_FILE}" || true # 删除本地临时文件，忽略错误
  exit 1 # 退出脚本
}

# 捕获错误并执行清理
trap cleanup_on_error ERR

# SSH 信息及目录
SSH_HOST="${SSH_HOST:-127.0.0.1}" # 远程服务器主机地址，默认 127.0.0.1
SSH_PORT="${SSH_PORT:-22}" # 远程服务器端口，默认 22
SSH_USER="${SSH_USER:-root}" # 远程服务器用户，默认 root
SSH_PASSWORD="${SSH_PASSWORD:-123456}" # SSH 密码，默认 123456
REMOTE_WEB_DIR=${REMOTE_WEB_DIR:-"/data/wwwroot"} # 远程服务器的网站根目录
REMOTE_BACK_DIR=${REMOTE_BACK_DIR:-"/data/wwwbackup"} # 远程服务器的备份目录

# 时间
TIME_YMDHMS=$(date "+%Y%m%d%H%M%S") # 获取部署时间戳

# 本地项目
PROJECT_NAME=$(basename "$(pwd)") # 获取当前项目名称
PROJECT_PATH=$(pwd) # 获取当前项目路径
TEMP_LOCAL_DEPLOY_PATH="${PROJECT_PATH}/.deploy-history" # 定义本地临时部署文件路径
TAR_LOCAL_FILE="${TEMP_LOCAL_DEPLOY_PATH}/${PROJECT_NAME}-${TIME_YMDHMS}.tar.gz" # 定义本地打包文件路径

# 远程项目目录
TAR_REMOTE_FILE="/tmp/${PROJECT_NAME}-${TIME_YMDHMS}.tar.gz" # 定义远程临时打包文件路径
SSH_WWWBACKUP_PATH="${REMOTE_BACK_DIR}/${PROJECT_NAME}/${TIME_YMDHMS}" # 定义远程备份目录路径
SSH_WWWROOT_PATH="${REMOTE_WEB_DIR}/${PROJECT_NAME}" # 定义远程网站根目录路径

# 创建临时发布目录
mkdir -p "${TEMP_LOCAL_DEPLOY_PATH}" # 创建本地部署历史目录

log "开始打包项目..."
tar -czf "${TAR_LOCAL_FILE}" ./* # 打包项目文件
log "项目打包完成：${TAR_LOCAL_FILE}"

log "开始上传文件到远程服务器..."
scp -P "$SSH_PORT" "${TAR_LOCAL_FILE}" "${SSH_USER}@${SSH_HOST}:${TAR_REMOTE_FILE}" # 上传打包文件到远程服务器
log "将 ${TAR_LOCAL_FILE} 上传到 ${TAR_REMOTE_FILE}"

log "开始在远程服务器执行部署命令..."
ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" <<EOF
  set -e # 确保脚本在错误时退出
  mkdir -p ${SSH_WWWBACKUP_PATH} # 创建远程备份目录
  tar -xzf ${TAR_REMOTE_FILE} -C ${SSH_WWWBACKUP_PATH} # 解压到备份目录
  mkdir -p ${REMOTE_WEB_DIR} # 确保远程网站根目录存在
  rm -rf ${SSH_WWWROOT_PATH} && ln -sfn ${SSH_WWWBACKUP_PATH} ${SSH_WWWROOT_PATH} # 替换软链接到最新备份
  rm -f ${TAR_REMOTE_FILE} # 删除远程临时文件
EOF
log "远程服务器部署完成!"

log "清理本地临时文件..."
rm -f "${TAR_LOCAL_FILE}" # 删除本地打包文件

log "部署完成！项目已成功发布到 ${SSH_WWWROOT_PATH}" # 部署成功日志