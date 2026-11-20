#!/bin/bash
#
# macOS 清理脚本
#   1) 日志目录、临时目录：删除 N 天前的文件
#   2) 已卸载但没卸载干净的应用残留：
#      Containers / Group Containers / Preferences / Caches /
#      HTTPStorages / WebKit / Saved Application State /
#      Application Support（按脚本内数组）/
#      失效的 LaunchAgents/LaunchDaemons / 失效的 /usr/local/bin 链接
#   3) Skills 目录黑名单：无条件删除 SKILL_DIRS_BLACKLIST 中列出的目录
#
# 用法：
#   ./cleanup.sh                  # 预览（默认，不删除任何东西）
#   ./cleanup.sh --apply          # 执行清理（会先确认）
#   ./cleanup.sh --apply --yes    # 执行清理（不询问，适合定时任务）
#   ./cleanup.sh --apply --system # 同时清理系统级日志（需要 sudo）
#   ./cleanup.sh --days 14        # 只清理 14 天前的日志/临时文件（默认 7）
#   ./cleanup.sh --no-color       # 关闭彩色输出（管道/重定向时也会自动关闭）
#
# 说明：
#   - 安装过的 App 及其数据不会被删除；只处理确认“应用不存在”的残留。
#   - 统一规则表 APP_RULES、Skills 目录黑名单都直接定义在脚本内的数组里。
#   - Skills 黑名单为无条件删除，不受“应用是否安装”影响，请先用预览确认。
#   - 所有操作直接输出到控制台，分 INFO/WARN/DEL 三个等级并带颜色。

set -u

# 应用残留规则表：bundle id | Application Support 目录名 | 策略
#   keep = 无条件保留（辅助组件等，安装路径不在本脚本扫描范围内，避免误删）
#   auto = 未安装时删除；目录名为 ~/Library/Application Support 下的文件夹名，
#          该目录名无法从 bundle id 推断，必须显式映射
APP_RULES=(
  # ---- 无条件保留 ----
  "ai.opencode.desktop||keep"
  "com.google.Keystone.Agent||keep"
  "com.google.GoogleUpdater||keep"
  "com.google.GoogleUpdater.wake||keep"
  "com.tencent.meeting||keep"
  "com.tencent.qqexbrowser||keep"
  "com.tencent.qqexdoc||keep"
  
  # ---- Application Support 残留（未安装则删除）----
  "cn.trae.app|Trae CN|auto"
  "com.trae.app|Trae|auto"
  "com.tencent.webplusdevtools|微信开发者工具|auto"
  "com.tencent.codebuddycn|CodeBuddy CN|auto"
  "com.tencent.codebuddycn|CodeBuddyExtension|auto"
  "com.jetbrains.goland|JetBrains|auto"
  "com.aliyun.ecd.jvs|jvs-pc-client|auto"
  "com.prect.NavicatPremium12|PremiumSoft CyberTech|auto"
  "com.todesktop.230313mzl4w4u92|Cursor|auto"
  "com.tencent.qclaw|QClaw|auto"
  "org.tabby|tabby|auto"
  "org.RedisLabs.RedisInsight-V2|RedisInsight|auto"
  "io.dcloud.HBuilderX|HBuilder X|auto"
)

# Skills 目录黑名单（参考 https://github.com/vercel-labs/skills/blob/main/docs/agents.md 的 Global Path 列）
# 这里列出的目录会被无条件删除，不受对应应用是否安装影响。
SKILL_DIRS_BLACKLIST=(
  "$HOME/.aider-desk/skills"
  "$HOME/.config/agents/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.astrbot/data/skills"
  "$HOME/.autohand/skills"
  "$HOME/.augment/skills"
  "$HOME/.bob/skills"
  "$HOME/.claude/skills"
  "$HOME/.openclaw/skills"
  "$HOME/.agents/skills"
  "$HOME/.codeartsdoer/skills"
  "$HOME/.codebuddy/skills"
  "$HOME/.codemaker/skills"
  "$HOME/.codestudio/skills"
  "$HOME/.commandcode/skills"
  "$HOME/.continue/skills"
  "$HOME/.snowflake/cortex/skills"
  "$HOME/.config/crush/skills"
  "$HOME/.cursor/skills"
  "$HOME/.deepagents/agent/skills"
  "$HOME/.config/devin/skills"
  "$HOME/.factory/skills"
  "$HOME/.firebender/skills"
  "$HOME/.forge/skills"
  "$HOME/.gemini/skills"
  "$HOME/.config/goose/skills"
  "$HOME/.grok/skills"
  "$HOME/.hermes/skills"
  "$HOME/.inferencesh/skills"
  "$HOME/.jazz/skills"
  "$HOME/.junie/skills"
  "$HOME/.iflow/skills"
  "$HOME/.kilo/skills"
  "$HOME/.config/kimchi/harness/skills"
  "$HOME/.kiro/skills"
  "$HOME/.kode/skills"
  "$HOME/.lingma/skills"
  "$HOME/.mcpjam/skills"
  "$HOME/.minimax/skills"
  "$HOME/.vibe/skills"
  "$HOME/.moxby/skills"
  "$HOME/.mux/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.openhands/skills"
  "$HOME/.ona/skills"
  "$HOME/.posit/assistant/skills"
  "$HOME/.qoder/skills"
  "$HOME/.qoder-cn/skills"
  "$HOME/.qwen/skills"
  "$HOME/.reasonix/skills"
  "$HOME/.rovodev/skills"
  "$HOME/.roo/skills"
  "$HOME/.tabnine/agent/skills"
  "$HOME/.terramind/skills"
  "$HOME/.tinycloud/skills"
  "$HOME/.trae/skills"
  "$HOME/.trae-cn/skills"
  "$HOME/.codeium/windsurf/skills"
  "$HOME/.zcode/skills"
  "$HOME/.zencoder/skills"
  "$HOME/.neovate/skills"
  "$HOME/.pochi/skills"
  "$HOME/.adal/skills"
)

# ---------------- 路径配置 ----------------
LIB="$HOME/Library"
APP_SUPPORT_DIR="$LIB/Application Support"
CACHES_DIR="$LIB/Caches"
CONTAINERS_DIR="$LIB/Containers"
GROUP_CONTAINERS_DIR="$LIB/Group Containers"
HTTP_STORAGES_DIR="$LIB/HTTPStorages"
LAUNCH_AGENTS_DIR="$LIB/LaunchAgents"
LOG_DIR="$LIB/Logs"
DIAG_REPORTS_DIR="$LOG_DIR/DiagnosticReports"
PREFERENCES_DIR="$LIB/Preferences"
SAVED_STATE_DIR="$LIB/Saved Application State"
WEBKIT_DIR="$LIB/WebKit"

# 安装判定扫描的 App 目录（bundle id 来源）
APP_DIRS=(
  /Applications
  /System/Applications
  "$HOME/Applications"
  /System/Library/CoreServices
)

# remove_path 永不删除的目录
PROTECTED_DIRS=(
  /
  "$HOME"
  "$LIB"
  "$APP_SUPPORT_DIR"
  "$CACHES_DIR"
  "$CONTAINERS_DIR"
  "$GROUP_CONTAINERS_DIR"
  "$HTTP_STORAGES_DIR"
  "$PREFERENCES_DIR"
  "$SAVED_STATE_DIR"
  "$WEBKIT_DIR"
)

# 系统级路径
SYS_LAUNCH_DIRS=(/Library/LaunchAgents /Library/LaunchDaemons)
SYS_LOG_DIRS=(/var/log /Library/Logs)
BIN_DIR=/usr/local/bin

DAYS=7
APPLY=0
ASSUME_YES=0
WITH_SYSTEM=0
INSTALLED_LIST=""

REMOVED=0
PLANNED=0

usage() {
  if [ -f "$0" ] && [ -r "$0" ]; then
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
    return 0
  fi
  # 经 curl | bash 运行时 $0 不是脚本文件，退回精简帮助
  printf '%s\n' \
    "用法: cleanup.sh [--apply] [--yes] [--days N] [--system] [--no-color]" \
    "  --apply     执行清理（默认仅预览）" \
    "  --yes       执行前不再确认" \
    "  --days N    只处理 N 天前的日志/临时文件（默认 7）" \
    "  --system    同时清理系统级日志（需要 sudo）" \
    "  --no-color  关闭彩色输出"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)        APPLY=1 ;;
    -n|--dry-run)   APPLY=0 ;;
    -y|--yes)       ASSUME_YES=1 ;;
    --system)       WITH_SYSTEM=1 ;;
    --days)         shift; DAYS="${1:-7}" ;;
    --no-color)     NO_COLOR=1 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

case "$DAYS" in
  ''|*[!0-9]*) echo "错误: --days 需要是数字" >&2; exit 1 ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
  echo "错误: 本脚本只适用于 macOS" >&2
  exit 1
fi

INSTALLED_LIST="$(mktemp "${TMPDIR:-/tmp}/cleanup-installed.XXXXXX")" || exit 1
cleanup_tmp() { rm -f "$INSTALLED_LIST"; }
trap cleanup_tmp EXIT

# 三个输出等级：INFO(青色) / WARN(黄色) / DEL(红色，删除操作)
setup_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_INFO=$'\033[36m'
    C_WARN=$'\033[33m'
    C_DEL=$'\033[31m'
    C_TITLE=$'\033[35m'
    C_BOLD=$'\033[1m'
  else
    C_RESET="" C_INFO="" C_WARN="" C_DEL="" C_TITLE="" C_BOLD=""
  fi
}

info() { printf '%s %s[INFO]%s %s\n' "$(date '+%F %T')" "$C_INFO" "$C_RESET" "$*"; }
warn() { printf '%s %s[WARN]%s %s\n' "$(date '+%F %T')" "$C_WARN" "$C_RESET" "$*"; }
del()  { printf '%s %s[DEL ]%s %s\n' "$(date '+%F %T')" "$C_DEL"  "$C_RESET" "$*"; }

section() {
  printf '\n%s%s==== %s ====%s\n' "$C_BOLD" "$C_TITLE" "$*" "$C_RESET"
}

setup_colors

is_dry() { [ "$APPLY" -eq 0 ]; }

# ---------- 建立已安装 App 的 bundle id 列表 ----------
build_installed_list() {
  local app id
  while IFS= read -r app; do
    id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)
    [ -n "$id" ] && printf '%s\n' "$id"
  done < <(
    find "${APP_DIRS[@]}" -maxdepth 3 -name '*.app' -prune -print 2>/dev/null
  ) | tr '[:upper:]' '[:lower:]' | sort -u > "$INSTALLED_LIST"
}

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# 规范化 id：去后缀、10 位 Team ID 前缀、group. 前缀
normalize_id() {
  local id="$1"
  id="${id%.savedState}"
  id="${id%.plist}"
  id="${id%.binarycookies}"
  case "$id" in
    [A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9].*)
      id="${id#??????????.}" ;;
  esac
  id="${id#group.}"
  printf '%s\n' "$id"
}

is_installed() {
  local id known
  id="$(lc "$1")"
  [ -n "$id" ] || return 1
  grep -qxF -- "$id" "$INSTALLED_LIST" 2>/dev/null && return 0
  while IFS= read -r known; do
    [ -n "$known" ] || continue
    # 子组件 id，如 com.tencent.xinWeChat.WeChatMacShare
    case "$id" in "$known".*) return 0 ;; esac
    # 厂商级名字，如 Group Containers 里的 com.tencent：任一该厂商应用在装即视为在用
    case "$known" in "$id".*) return 0 ;; esac
  done < "$INSTALLED_LIST"
  return 1
}

# 命中 keep 规则（仅按 bundle id 匹配，与目录名无关）
is_protected() {
  local id entry r_id r_policy
  id="$(lc "$1")"
  for entry in "${APP_RULES[@]}"; do
    IFS='|' read -r r_id _ r_policy <<< "$entry"
    [ "$r_policy" = "keep" ] || continue
    [ "$(lc "$r_id")" = "$id" ] && return 0
  done
  return 1
}

is_ignored_id() {
  local id
  id="$(lc "$1")"
  case "$id" in
    ''|com.apple.*|*.apple.*|group.com.apple.*|is.workflow.*|org.sparkle-project.*|org.jcef.*)
      return 0 ;;
  esac
  is_protected "$id" && return 0
  return 1
}

path_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

# 数据已清空、仅剩 macOS 容器元数据的目录（删不掉，也没必要反复尝试）
is_container_stub() {
  local p="$1"
  [ -d "$p" ] || return 1
  [ -z "$(find "$p" -mindepth 1 -maxdepth 1 \
    ! -name '.com.apple.containermanagerd.metadata.plist' 2>/dev/null | head -1)" ]
}

remove_path() {
  local p="$1" size d
  [ -n "$p" ] || return 0
  [ -e "$p" ] || [ -L "$p" ] || return 0
  for d in "${PROTECTED_DIRS[@]}"; do
    if [ "$p" = "$d" ]; then
      warn "  跳过危险路径: $p"
      return 0
    fi
  done
  size="$(path_size "$p")"
  if is_dry; then
    del "  [将删除] ${size:-?} $p"
    PLANNED=$((PLANNED + 1))
    return 0
  fi
  if rm -rf -- "$p" 2>/dev/null; then
    del "  [已删除] ${size:-?} $p"
    REMOVED=$((REMOVED + 1))
  elif [ ! -e "$p" ] || is_container_stub "$p"; then
    del "  [已清理, 仅剩系统元数据] ${size:-?} $p"
    REMOVED=$((REMOVED + 1))
  else
    warn "  [部分删除/系统保护] $p"
  fi
}

clean_old_files() {
  local dir="$1" label="$2" count size_mb
  [ -d "$dir" ] || return 0
  count=$(find "$dir" -type f -mtime +"$DAYS" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count:-0}" -eq 0 ]; then
    info "  $label: 没有 $DAYS 天前的文件"
    return 0
  fi
  size_mb=$(find "$dir" -type f -mtime +"$DAYS" -exec du -k {} + 2>/dev/null |
    awk '{s += $1} END {printf "%.1f", s / 1024}')
  info "  $label: $count 个文件，约 ${size_mb:-0} MB"
  if is_dry; then
    find "$dir" -type f -mtime +"$DAYS" 2>/dev/null | head -10 | sed 's/^/    /'
    [ "$count" -gt 10 ] && info "    ... 其余 $((count - 10)) 个文件"
  else
    find "$dir" -type f -mtime +"$DAYS" -delete 2>/dev/null
    info "  $label: 已清理"
  fi
}

# ======================================================================
# 执行确认
# ======================================================================
if [ "$APPLY" -eq 1 ] && [ "$ASSUME_YES" -eq 0 ]; then
  printf '将清理日志/临时文件，并删除已卸载应用的残留数据，确认执行? [y/N] '
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "已取消。"; exit 0 ;;
  esac
fi

FREE_BEFORE=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}')
[ -n "${FREE_BEFORE:-}" ] || FREE_BEFORE=$(df -k / | awk 'NR==2 {print $4}')

info "启动清理 (模式: $(is_dry && echo 预览 || echo 执行), 阈值: ${DAYS} 天)"
build_installed_list
info "已识别 $(wc -l < "$INSTALLED_LIST" | tr -d ' ') 个已安装 App"

# ======================================================================
# 第一步：日志目录 + 临时目录
# ======================================================================
section "清理日志目录"
clean_old_files "$LOG_DIR" "~/Library/Logs"
clean_old_files "$DIAG_REPORTS_DIR" "诊断报告"

section "清理临时目录"
clean_old_files "${TMPDIR:-/tmp}" "\$TMPDIR"
clean_old_files "/tmp" "/tmp"
clean_old_files "/private/var/tmp" "/private/var/tmp"

if [ "$WITH_SYSTEM" -eq 1 ]; then
  section "清理系统日志 (需要 sudo)"
  if is_dry; then
    warn "  [将执行] sudo find ${SYS_LOG_DIRS[*]} -type f -mtime +$DAYS -delete"
    warn "  [将执行] sudo find /private/var/tmp -type f -mtime +$DAYS -delete"
  else
    sudo find "${SYS_LOG_DIRS[@]}" -type f -mtime +"$DAYS" -delete 2>/dev/null
    sudo find /private/var/tmp -type f -mtime +"$DAYS" -delete 2>/dev/null
    info "  系统日志/临时文件已清理"
  fi
else
  warn "  (跳过系统级 /var/log、/Library/Logs，如需清理请加 --system)"
fi

# ======================================================================
# 第二步：已卸载应用的残留
# ======================================================================
section "失效的 LaunchAgent / LaunchDaemon"

check_agent_plist() {
  local plist="$1" scope="$2" label prog
  [ -f "$plist" ] || return 0
  label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null)
  prog=$(/usr/libexec/PlistBuddy -c 'Print :Program' "$plist" 2>/dev/null)
  if [ -z "$prog" ]; then
    prog=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null)
  fi
  [ -n "$prog" ] || return 0
  case "$prog" in /*) ;; *) return 0 ;; esac
  [ -e "$prog" ] && return 0

  if [ "$scope" = "system" ] && [ "$WITH_SYSTEM" -ne 1 ]; then
    warn "  [系统级, 未处理] ${label:-$plist} -> 缺失: $prog (加 --system 处理)"
    return 0
  fi

  if is_dry; then
    del "  [将删除] $plist -> 缺失: $prog"
    PLANNED=$((PLANNED + 1))
    return 0
  fi

  if [ -z "$label" ]; then
    warn "  [跳过] 无法读取 Label: $plist"
    return 0
  fi

  if [ "$scope" = "system" ]; then
    sudo launchctl bootout "system/$label" 2>/dev/null
    sudo launchctl disable "system/$label" 2>/dev/null
    sudo rm -f "$plist"
  else
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
    launchctl disable "gui/$(id -u)/$label" 2>/dev/null
    rm -f "$plist"
  fi
  del "  [已删除] $plist (目标程序不存在)"
  REMOVED=$((REMOVED + 1))
}

for p in "$LAUNCH_AGENTS_DIR"/*.plist; do
  [ -e "$p" ] && check_agent_plist "$p" user
done
for d in "${SYS_LAUNCH_DIRS[@]}"; do
  for p in "$d"/*.plist; do
    [ -e "$p" ] && check_agent_plist "$p" system
  done
done

section "失效的 /usr/local/bin 链接"
for p in "$BIN_DIR"/*; do
  [ -L "$p" ] || continue
  [ -e "$p" ] && continue
  if is_dry; then
    del "  [将删除] $p -> $(readlink "$p")"
    PLANNED=$((PLANNED + 1))
  elif rm -f -- "$p" 2>/dev/null; then
    del "  [已删除] $p -> 失效链接"
    REMOVED=$((REMOVED + 1))
  else
    warn "  [需 sudo] $p -> $(readlink "$p")"
  fi
done

scan_bundle_dir() {
  local root="$1" label="$2" mode="${3:-dirs}" p name id
  [ -d "$root" ] || return 0
  for p in "$root"/*; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    name=$(basename "$p")
    case "$mode" in
      dirs)      [ -d "$p" ] || continue ;;
      container) [ -d "$p" ] || continue; is_container_stub "$p" && continue ;;
      plist)     case "$name" in *.plist) ;; *) continue ;; esac ;;
      http)      if [ ! -d "$p" ]; then case "$name" in *.binarycookies) ;; *) continue ;; esac; fi ;;
    esac
    id=$(normalize_id "$name")
    # 只自动处理形如 bundle id 的名字，避免误删普通目录/文件
    case "$id" in
      *.*) ;;
      *) continue ;;
    esac
    is_ignored_id "$id" && continue
    is_installed "$id" && continue
    info "  [$label] 未安装: $id"
    remove_path "$p"
  done
}

section "Containers"
scan_bundle_dir "$CONTAINERS_DIR" "容器" container

section "Group Containers"
scan_bundle_dir "$GROUP_CONTAINERS_DIR" "共享容器" dirs

section "Preferences"
scan_bundle_dir "$PREFERENCES_DIR" "偏好设置" plist

section "Caches"
scan_bundle_dir "$CACHES_DIR" "缓存" dirs

section "HTTPStorages / WebKit / Saved Application State"
scan_bundle_dir "$HTTP_STORAGES_DIR" "HTTPStorages" http
scan_bundle_dir "$WEBKIT_DIR" "WebKit" dirs
scan_bundle_dir "$SAVED_STATE_DIR" "窗口状态" dirs

section "Application Support"
for entry in "${APP_RULES[@]}"; do
  IFS='|' read -r id name policy <<< "$entry"
  [ "$policy" = "auto" ] && [ -n "$name" ] || continue
  local_path="$APP_SUPPORT_DIR/$name"
  [ -e "$local_path" ] || continue
  if is_installed "$id"; then
    info "  保留 $name (已安装: $id)"
    continue
  fi
  info "  [Application Support] 未安装: $id"
  remove_path "$local_path"
done

section "Skills 目录黑名单"
warn "  黑名单目录将被无条件删除（与对应 App 是否安装无关）"
skill_found=0
for skill_dir in "${SKILL_DIRS_BLACKLIST[@]}"; do
  [ -e "$skill_dir" ] || [ -L "$skill_dir" ] || continue
  skill_found=$((skill_found + 1))
  remove_path "$skill_dir"
done
[ "$skill_found" -eq 0 ] && info "  未发现黑名单中的 Skills 目录"

# ======================================================================
# 汇总
# ======================================================================
section "清理结果"
FREE_AFTER=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}')
[ -n "${FREE_AFTER:-}" ] || FREE_AFTER=$(df -k / | awk 'NR==2 {print $4}')
FREED_MB=$(( (FREE_AFTER - FREE_BEFORE) / 1024 ))
[ "$FREED_MB" -lt 0 ] && FREED_MB=0

if is_dry; then
  info "预览完成：共发现 $PLANNED 项可清理内容，未删除任何文件。"
  info "确认无误后执行: $0 --apply"
else
  info "清理完成：共删除 $REMOVED 项，释放约 ${FREED_MB} MB。"
fi
