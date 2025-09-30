#!/bin/bash
set -euo pipefail

# ==========================================================================
# MySQL 单库备份脚本
#
# 功能：
#   - 支持通过环境变量或交互式输入获取本地 MySQL 连接信息（含主机、端口、数据库名、用户名、密码）
#   - 自动导出指定数据库为 SQL 文件，备份文件保存在当前目录，文件名包含时间戳
#   - 备份文件存在则报错，避免覆盖
#   - 过程带彩色提示，提升用户体验
#
# 依赖：
#   - 需要安装 MySQL 客户端工具（mysqldump、mysql）且在 PATH 中
#
# 使用说明：
#   1. 可事先通过环境变量设置连接信息：
#      LOCAL_HOST、LOCAL_PORT、LOCAL_DB、LOCAL_USER、LOCAL_PASS
#   2. 运行脚本时会提示输入，按回车可使用默认或环境变量值
#   3. 备份文件将保存在当前目录，文件名格式：<数据库名>_YYYYMMDD_HHMMSS.sql
#
# 示例：
#   export LOCAL_HOST=127.0.0.1
#   export LOCAL_PORT=3306
#   export LOCAL_DB=mydb
#   export LOCAL_USER=root
#   export LOCAL_PASS=123456
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mysql/backup.sh)"
#
# 作者：
#   zhiqiang
#
# 日期：
#   2025-05-24
# ==========================================================================


color_echo() {
  local color_code=$1; shift
  echo -e "\033[${color_code}m$@\033[0m"
}
info()    { color_echo "1;34" "🔧 $@"; }
success() { color_echo "1;32" "✅ $@"; }
warning() { color_echo "1;33" "⚠️  $@"; }
error()   { color_echo "1;31" "❌ $@"; }
step()    { color_echo "1;36" "🚀 $@"; }
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }

for cmd in mysqldump mysql; do
  if ! command -v $cmd &>/dev/null; then
    error "未找到命令 $cmd，请安装 MySQL 客户端！"
    exit 1
  fi
done

divider
step "请输入本地数据库连接信息 (环境变量已设定时不再提示输入)..."

# 只有当变量为空才提示输入
if [ -z "${LOCAL_HOST:-}" ]; then
  DEFAULT_HOST="127.0.0.1"
  read -rp "本地数据库主机 [$DEFAULT_HOST]: " input
  LOCAL_HOST="${input:-$DEFAULT_HOST}"
else
  info "使用环境变量 LOCAL_HOST=$LOCAL_HOST"
fi

if [ -z "${LOCAL_PORT:-}" ]; then
  DEFAULT_PORT="3306"
  read -rp "本地数据库端口 [$DEFAULT_PORT]: " input
  LOCAL_PORT="${input:-$DEFAULT_PORT}"
else
  info "使用环境变量 LOCAL_PORT=$LOCAL_PORT"
fi

if [ -z "${LOCAL_DB:-}" ]; then
  LOCAL_DB="${MYSQL_DATABASE:-}"
  while [ -z "$LOCAL_DB" ]; do
    read -rp "本地数据库名: " LOCAL_DB
  done
else
  info "使用环境变量 LOCAL_DB=$LOCAL_DB"
fi

if [ -z "${LOCAL_USER:-}" ]; then
  LOCAL_USER="${MYSQL_USER:-root}"
  read -rp "本地数据库用户名 [$LOCAL_USER]: " input
  LOCAL_USER="${input:-$LOCAL_USER}"
else
  info "使用环境变量 LOCAL_USER=$LOCAL_USER"
fi

if [ -z "${LOCAL_PASS:-}" ]; then
  LOCAL_PASS="${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}"
  if [ -z "$LOCAL_PASS" ]; then
    read -rs -p "本地数据库密码: " LOCAL_PASS
    echo ""
  else
    info "使用环境变量 MYSQL_PASSWORD 或 MYSQL_ROOT_PASSWORD"
  fi
else
  info "使用环境变量 LOCAL_PASS=******"
fi

divider
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${LOCAL_DB}_${TIMESTAMP}.sql"

if [ -f "$BACKUP_FILE" ]; then
  error "备份文件 $BACKUP_FILE 已存在，请先移除或改名，避免覆盖！"
  exit 1
fi

step "开始导出数据库 $LOCAL_DB 到文件 $BACKUP_FILE ..."

if MYSQL_PWD="$LOCAL_PASS" mysqldump -h "$LOCAL_HOST" -P "$LOCAL_PORT" -u "$LOCAL_USER" "$LOCAL_DB" > "$BACKUP_FILE"; then
  chmod 600 "$BACKUP_FILE"
  success "备份成功，文件：$BACKUP_FILE"
else
  error "备份失败！请检查数据库连接信息及权限。"
  exit 1
fi
