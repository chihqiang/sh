#!/bin/bash
set -euo pipefail

#!/bin/bash
set -euo pipefail

# ==========================================================================
# MySQL 数据库迁移脚本 - 本地导出并导入至远程数据库
#
# 功能：
#   - 支持通过环境变量或交互式输入获取本地和远程 MySQL 连接信息（主机、端口、数据库名、用户名、密码）
#   - 自动导出本地数据库为 SQL 文件，备份文件保存在 ./backup 目录，文件名含时间戳
#   - 检查远程数据库是否存在，若不存在提示手动创建
#   - 将导出文件导入远程数据库，实现数据库迁移
#   - 过程带彩色提示，提升用户体验
#   - 支持自定义端口，适配 Docker 容器和多种 MySQL 配置环境
#
# 依赖：
#   - mysql 客户端工具（mysqldump、mysql）需已安装且在 PATH 中
#
# 支持的环境变量：
#   LOCAL_HOST      本地数据库主机，默认127.0.0.1
#   LOCAL_PORT      本地数据库端口，默认3306
#   LOCAL_DB        本地数据库名
#   LOCAL_USER      本地数据库用户名，默认root
#   LOCAL_PASS      本地数据库密码
#   REMOTE_HOST     远程数据库主机
#   REMOTE_PORT     远程数据库端口，默认3306
#   REMOTE_DB       远程数据库名
#   REMOTE_USER     远程数据库用户名，默认root
#   REMOTE_PASS     远程数据库密码
#
# 使用示例：
#   可设置环境变量后执行，或运行脚本后按提示输入
#   export LOCAL_HOST=127.0.0.1
#   export LOCAL_PORT=3306
#   export LOCAL_DB=mydb
#   export LOCAL_USER=root
#   export LOCAL_PASS=123456
#   export REMOTE_HOST=192.168.1.100
#   export REMOTE_PORT=3306
#   export REMOTE_DB=mydb
#   export REMOTE_USER=root
#   export REMOTE_PASS=123456
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mysql/sync.sh)"
#
# 作者：
#   [你的名字或联系方式]
#
# 日期：
#   2025-05-24
# ==========================================================================


# === 函数：带颜色的 echo ===
color_echo() {
  local color_code=$1
  shift
  echo -e "\033[${color_code}m$@\033[0m"
}

info()    { color_echo "1;34" "🔧 $@"; }   # 蓝色
success() { color_echo "1;32" "✅ $@"; }   # 绿色
warning() { color_echo "1;33" "⚠️  $@"; }  # 黄色
error()   { color_echo "1;31" "❌ $@"; }   # 红色
step()    { color_echo "1;36" "🚀 $@"; }   # 青色
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }

# === 检查依赖 ===
for cmd in mysqldump mysql; do
    if ! command -v $cmd &>/dev/null; then
        error "未找到命令 $cmd，请安装 MySQL 客户端！"
        exit 1
    fi
done

divider
step "获取本地数据库信息..."

LOCAL_HOST="${LOCAL_HOST:-127.0.0.1}"
LOCAL_PORT="${LOCAL_PORT:-3306}"

LOCAL_DB="${LOCAL_DB:-${MYSQL_DATABASE:-}}"
if [ -z "$LOCAL_DB" ]; then
    read -rp "本地数据库名: " LOCAL_DB
fi

LOCAL_USER="${LOCAL_USER:-${MYSQL_USER:-root}}"
if [ -z "$LOCAL_USER" ]; then
    read -rp "本地用户名: " LOCAL_USER
fi

LOCAL_PASS="${LOCAL_PASS:-${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}}"
if [ -z "$LOCAL_PASS" ]; then
    read -rs -p "本地密码: " LOCAL_PASS
    echo ""
fi

divider
step "获取远程数据库信息..."

REMOTE_HOST="${REMOTE_HOST:-}"
if [ -z "$REMOTE_HOST" ]; then
    read -rp "远程主机地址: " REMOTE_HOST
fi

REMOTE_PORT="${REMOTE_PORT:-3306}"

REMOTE_DB="${REMOTE_DB:-}"
if [ -z "$REMOTE_DB" ]; then
    read -rp "远程数据库名: " REMOTE_DB
fi

REMOTE_USER="${REMOTE_USER:-root}"
if [ -z "$REMOTE_USER" ]; then
    read -rp "远程用户名: " REMOTE_USER
fi

REMOTE_PASS="${REMOTE_PASS:-}"
if [ -z "$REMOTE_PASS" ]; then
    read -rs -p "远程密码: " REMOTE_PASS
    echo ""
fi

divider
step "准备导出文件..."
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DUMP_FILE="${LOCAL_DB}_${TIMESTAMP}.sql"
if [ -f "$DUMP_FILE" ]; then
  error "导出文件 $DUMP_FILE 已存在，避免覆盖，请先手动处理该文件！"
  exit 1
fi

step "正在导出本地数据库 $LOCAL_DB..."
MYSQL_PWD=$LOCAL_PASS mysqldump -h "$LOCAL_HOST" -P "$LOCAL_PORT" -u "$LOCAL_USER" "$LOCAL_DB" > "$DUMP_FILE"
chmod 600 "$DUMP_FILE"
success "导出完成，文件保存在 $DUMP_FILE"

divider
step "检查远程数据库 $REMOTE_DB 是否存在..."

if ! MYSQL_PWD=$REMOTE_PASS mysql -h "$REMOTE_HOST" -P "$REMOTE_PORT" -u "$REMOTE_USER" -e "SHOW DATABASES LIKE '$REMOTE_DB';" | grep -wq "$REMOTE_DB"; then
    error "远程数据库 $REMOTE_DB 不存在，请先手动创建！"
    exit 1
fi

step "正在导入数据到远程数据库 $REMOTE_DB..."
MYSQL_PWD=$REMOTE_PASS mysql -h "$REMOTE_HOST" -P "$REMOTE_PORT" -u "$REMOTE_USER" "$REMOTE_DB" < "$DUMP_FILE"

success "数据库迁移完成！🚀"
