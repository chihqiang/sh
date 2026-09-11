#!/usr/bin/env bash
#
# 把各项目依赖的 infra-go 升级到指定版本，并逐个做完整校验。
#
# 用法:
#   ./infra-go.sh                  # 升级到 @latest（默认不提交、不推送）
#   ./infra-go.sh main             # 升级到 main 分支最新提交
#   ./infra-go.sh b17fe014d        # 升级到指定 commit / tag / 版本号
#   ./infra-go.sh -c               # 检查通过后自动提交（commit）
#   ./infra-go.sh -p               # 检查通过后自动提交并推送（commit + push）
#   ./infra-go.sh -h               # 查看帮助
#
# 选项也可以写成环境变量，两种写法完全等价（推荐放脚本名前面）:
#   COMMIT=1 ./infra-go.sh main         # 等同于 ./infra-go.sh main -c
#   PUSH=1 ./infra-go.sh main           # 等同于 ./infra-go.sh main -p
#   DRY_RUN=1 COMMIT=1 ./infra-go.sh main   # 先演练，只打印 commit 命令不真执行
#   SKIP_TEST=1 COMMIT=1 ./infra-go.sh main # 跳过测试（仍做 build + vet）后提交
#   CROSS=1 PUSH=1 ./infra-go.sh main       # 加 linux 交叉编译检查并提交推送
#   COMMIT=1 PUSH=1 ./infra-go.sh 
#
# 注意: 环境变量必须写在脚本名【前面】。
#   ./infra-go.sh main COMMIT=1   # 错误示范：COMMIT=1 会被当成版本号，go get 会失败
#
# 不下载、直接远程执行:
#   curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/my/infra-go.sh | COMMIT=1 PUSH=1 bash -s --
#   curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/my/infra-go.sh | bash -s -- main
#   -s -- 后面拼参数（如 main / -c / -p）；环境变量写在 bash 前面，写 curl 前面不会传给脚本
#   远程执行时读不到自身文件，WORKDIR 默认为当前目录，所以【在哪个目录执行就以哪里为根】
#
# 项目列表写在下面的 PROJECTS 里，值可以是 git 地址或本地路径:
#   git@github.com:chihqiang/q-chat.git
#   https://github.com/chihqiang/q-chat.git
#
# 依次执行（任一步失败即停在该步，不再往下跑）:
#   go get <module>@<ref>
#   go mod tidy                     # 让 go.mod / go.sum 收敛
#   go build -o /dev/null ./...     # 编译所有包（含 main），API 变更基本在这里暴露
#   go vet ./...                    # 静态检查
#   go test -count=1 ./...          # 跑测试，-count=1 不使用测试缓存
#
# 可调环境变量:
#   DRY_RUN=1      只打印要执行的动作，不真正执行
#   SKIP_VET=1     跳过 go vet（只图快时用）
#   SKIP_TEST=1    跳过 go test（只验证编译）
#   CROSS=1        额外做一次 linux/amd64 交叉编译（默认关闭，部署产物是 linux）
#   TEST_FLAGS     传给 go test 的参数，默认 "-count=1"，如 TEST_FLAGS="-count=1 -race"
#   COMMIT=1       检查通过后自动提交（默认关闭），等价于 -c
#   PUSH=1         检查通过后自动提交并推送（默认关闭，隐含 COMMIT=1），等价于 -p
#
# 说明:
#   - 单个项目失败不会中断其它项目，最后统一汇总并返回非 0 退出码。
#   - 本地已有同名仓库就直接用，没有才 clone 到 WORKDIR。
#   - 提交 / 推送默认关闭，且只有检查全部通过的项目才会提交，测试没过的不进仓库。
#   - 提交时用 pathspec 只带 go.mod / go.sum，不会裹挟项目里其它未完成的改动。
#   - 提交信息自动生成，格式为 chore(deps): upgrade infra-go to <版本>。
#   - 把 infra-go 换成你自己的模块路径，或改下面 MODULE 变量即可复用。
#
# 其他环境变量:
#   WORKDIR        仓库放在哪个目录，默认脚本同级目录；已有的仓库会被直接复用
#
set -uo pipefail

readonly MODULE="github.com/chihqiang/infra-go"

# 脚本自身路径。远程执行（curl | bash 或 bash <(curl ...)）时拿不到真实文件，
# 此时 SCRIPT_FILE 为空 / 不是普通文件，ROOT 回退到当前目录
SCRIPT_FILE="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -f "${SCRIPT_FILE}" ]]; then
  # 赋值与 readonly 分开写：避免 declare 的返回值掩盖命令替换的失败（SC2155）
  SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_FILE}")" && pwd)"
fi
ROOT="${SCRIPT_DIR:-${PWD}}"
readonly ROOT

# 需要升级的项目（git 地址或本地路径）；本地缺少时会 clone 到 WORKDIR 下同名目录
readonly PROJECTS=(
  git@github.com:chihqiang/ccsim-svr.git
  git@github.com:chihqiang/llm-gate.git
  git@github.com:chihqiang/dskpanel.git
  git@github.com:chihqiang/q-iam.git
  git@github.com:chihqiang/msg-push.git
  git@github.com:chihqiang/q-chat.git  
)

# 本地仓库根目录，默认脚本同级目录
WORKDIR="${WORKDIR:-${ROOT}}"

# 命令行参数（REF）在 parse_args 里解析
REF=""
DRY_RUN="${DRY_RUN:-0}"
SKIP_VET="${SKIP_VET:-0}"
SKIP_TEST="${SKIP_TEST:-0}"
CROSS="${CROSS:-0}"
TEST_FLAGS="${TEST_FLAGS:--count=1}"

# 提交 / 推送默认关闭，必须显式开启（COMMIT=1 / PUSH=1 或 -c / -p）
COMMIT="${COMMIT:-0}"
PUSH="${PUSH:-0}"
if [[ "$PUSH" == "1" ]]; then
  COMMIT=1
fi

if [[ -t 1 ]]; then
  readonly RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m'
  readonly BLUE=$'\033[34m' DIM=$'\033[2m' RESET=$'\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' DIM='' RESET=''
fi

log()  { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
err()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*" >&2; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }

# ── 全局状态 ──────────────────────────────────────────────
failed=()    # 需要关注的项目
changed=()   # 版本真的发生变化的项目
committed=() # 已完成提交（PUSH=1 时含推送）的项目

# ── 输出与执行 ────────────────────────────────────────────
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s[dry-run]%s %s\n' "$DIM" "$RESET" "$*"
    return 0
  fi
  "$@"
}

# 执行单项检查：通过打印 ok，失败打印错误并登记到 failed
check() {
  local name="$1" desc="$2"
  shift 2

  if run "$@"; then
    ok "${name}: ${desc}"
    return 0
  fi

  err "${name}: ${desc} 失败"
  failed+=("${name}  →  ${desc} 失败")
  return 1
}

# ── 小工具 ────────────────────────────────────────────────

# 从 git 地址推出本地目录名：git@host:owner/name.git → name
repo_name() {
  local url="${1%/}"
  url="${url##*/}"
  printf '%s\n' "${url%.git}"
}

# 读取当前依赖的版本号
current_version() {
  go -C "$1" list -m -f '{{.Version}}' "${MODULE}" 2>/dev/null || echo '未依赖'
}

# go.mod / go.sum 是否已有未提交改动（必须在升级前调用）
is_gomod_dirty() {
  [[ -n "$(git -C "$1" status --porcelain -- go.mod go.sum 2>/dev/null || true)" ]]
}

# 失败后的回滚提示；升级前 go.mod 本来就脏时不能乱指路
rollback_hint() {
  local name="$1" dir="$2" was_dirty="${3:-0}"

  if [[ "$was_dirty" == "1" ]]; then
    warn "${name}: go.mod / go.sum 升级前就有未提交改动，回滚请自行判断"
  else
    warn "${name}: 如需回滚 → git -C ${dir} checkout -- go.mod go.sum"
  fi
}

# ── 仓库准备 ─────────────────────────────────────────────

# 本地已有就直接用，没有才 clone。
# 成功时把 REPO_READY 置 1（表示目录真实可用），失败返回非 0
ensure_repo() {
  local name="$1" url="$2" dir="$3"
  REPO_READY=0

  if [[ -d "${dir}/.git" ]]; then
    ok "${name}: 本地已存在，直接使用 → ${dir}"
    REPO_READY=1
    return 0
  fi

  # 目录被同名文件 / 非 git 目录占着，不动它，避免误删用户数据
  if [[ -e "${dir}" ]]; then
    err "${name}: ${dir} 已存在但不是 git 仓库，请自行处理"
    return 1
  fi

  log "${name}: 本地不存在，克隆 ${url}"
  run mkdir -p "${WORKDIR}" || return 1
  if ! run git clone "${url}" "${dir}"; then
    err "${name}: git clone 失败 → ${url}"
    return 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    warn "${name}: DRY_RUN 不会真的克隆，后续命令仅作预览"
    return 0
  fi

  ok "${name}: 克隆完成 → ${dir}"
  REPO_READY=1
  return 0
}

# ── 核心步骤 ──────────────────────────────────────────────

# 升级依赖，失败则登记并返回非 0
# 用 go -C <dir> 而非 cd/pushd，避免依赖 pushd/popd 成对出现和 cwd 泄漏
do_upgrade() {
  local name="$1" dir="$2"

  run go -C "${dir}" get "${MODULE}@${REF}" && return 0

  err "${name}: go get ${MODULE}@${REF} 失败"
  failed+=("${name}  →  go get 失败")
  return 1
}

# 依次做各项检查，任一步失败即停（后面的检查已无意义）
do_checks() {
  local name="$1" dir="$2"

  check "${name}" "go mod tidy" go -C "${dir}" mod tidy || return 1

  # -o /dev/null：只做编译+链接检查。不带它时若模块根目录就是 main 包，
  # go build 会在工作区里落一个可执行文件（污染 workspace）
  check "${name}" "go build ./..." go -C "${dir}" build -o /dev/null ./... || return 1

  if [[ "$SKIP_VET" != "1" ]]; then
    check "${name}" "go vet ./..." go -C "${dir}" vet ./... || return 1
  fi

  if [[ "$SKIP_TEST" != "1" ]]; then
    # TEST_FLAGS 故意不加引号，需要按空格拆成多个参数
    # shellcheck disable=SC2086
    check "${name}" "go test ${TEST_FLAGS} ./..." go -C "${dir}" test ${TEST_FLAGS} ./... || return 1
  fi

  if [[ "$CROSS" == "1" ]]; then
    check "${name}" "交叉编译 linux/amd64" \
      env GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go -C "${dir}" build -o /dev/null ./... || return 1
  fi

  return 0
}

# ── 提交与推送（默认关闭） ────────────────────────────────

# 提交信息自动生成，不对外开放传入
commit_message() {
  printf 'chore(deps): upgrade %s to %s\n' "${MODULE##*/}" "$1"
}

# 提交（PUSH=1 时并推送）。
# 调用前提：该项目的检查已全部通过 —— 测试没过的东西不该进仓库。
do_commit_push() {
  local name="$1" dir="$2" version="$3"
  local msg
  msg="$(commit_message "${version}")"

  # 只带上确实存在的文件：go.sum 可能压根不存在，pathspec 写死会直接报错
  local -a paths=()
  [[ -f "${dir}/go.mod" ]] && paths+=("go.mod")
  [[ -f "${dir}/go.sum" ]] && paths+=("go.sum")
  if [[ "${#paths[@]}" -eq 0 ]]; then
    warn "${name}: 找不到 go.mod / go.sum，跳过提交"
    return 0
  fi

  # 版本没变化时可能压根没有待提交内容，此时 git commit 会直接失败
  if [[ "$DRY_RUN" != "1" ]] && [[ -z "$(git -C "${dir}" status --porcelain -- "${paths[@]}")" ]]; then
    warn "${name}: go.mod / go.sum 没有改动，跳过提交"
    return 0
  fi

  # 必须先 add：go.sum 若是新增文件（未被 git 跟踪），直接 commit 加 pathspec 会报
  # "pathspec 'go.sum' did not match any file(s) known to git"
  if ! check "${name}" "git add (${paths[*]})" \
    git -C "${dir}" add -A -- "${paths[@]}"; then
    warn "${name}: git add 失败，请手动处理"
    return 1
  fi

  # 用 pathspec 限定路径：即使仓库里已经有其它已暂存的改动，也不会被裹挟进这次提交
  if ! check "${name}" "git commit (${paths[*]})" \
    git -C "${dir}" commit -m "${msg}" -- "${paths[@]}"; then
    warn "${name}: 提交失败，请手动处理（可能不在预期分支或有冲突）"
    return 1
  fi

  if [[ "$PUSH" == "1" ]]; then
    if ! check "${name}" "git push" git -C "${dir}" push; then
      warn "${name}: 本地已提交，但推送失败；确认远端与 upstream 后手动 push"
      return 1
    fi
  fi

  return 0
}

# ── 单个项目 ──────────────────────────────────────────────

# 失败不中断整体流程，只登记到 failed
upgrade_one() {
  local url="$1"
  local name dir before after was_dirty=0
  name="$(repo_name "${url}")"
  dir="${WORKDIR}/${name}"

  printf '\n%s━━━ %s ━━━%s\n' "$BLUE" "$name" "$RESET"

  if ! ensure_repo "${name}" "${url}" "${dir}"; then
    failed+=("${name}  →  仓库不可用")
    return 0
  fi

  # 真实克隆过才检查 go.mod；DRY_RUN 下目录不存在，不能据此判失败
  if [[ "$REPO_READY" == "1" && ! -f "${dir}/go.mod" ]]; then
    warn "${name}: 缺少 go.mod，跳过: ${dir}"
    failed+=("${name}  →  缺少 go.mod")
    return 0
  fi

  before="$(current_version "${dir}")"
  if is_gomod_dirty "${dir}"; then
    was_dirty=1
  fi
  log "${name}: 当前 ${MODULE}@${before}"

  if ! do_upgrade "${name}" "${dir}"; then
    rollback_hint "${name}" "${dir}" "${was_dirty}"
    return 0
  fi

  after="$(current_version "${dir}")"
  if [[ "$DRY_RUN" != "1" && "$before" == "$after" ]]; then
    warn "${name}: 版本没变化（${after}），检查是否被 require / replace 约束住了"
  elif [[ "$before" != "$after" ]]; then
    changed+=("${name}  ${before} → ${after}")
  fi

  if do_checks "${name}" "${dir}"; then
    ok "${name}: ${before} → ${after}，检查全部通过"

    # 只有检查全通过才提交；提交/推送失败不影响其它项目继续处理
    if [[ "$COMMIT" == "1" ]] && do_commit_push "${name}" "${dir}" "${after}"; then
      committed+=("${name}")
    fi
  else
    rollback_hint "${name}" "${dir}" "${was_dirty}"
  fi

  return 0
}

# ── 汇总 ──────────────────────────────────────────────────

# 失败项 > 0 时返回 1，由 main 决定退出码
summarize() {
  printf '\n%s═════════ 汇总 ═════════%s\n' "$BLUE" "$RESET"

  if [[ "$DRY_RUN" != "1" && "${#changed[@]}" -gt 0 ]]; then
    printf '%s版本变化:%s\n' "$DIM" "$RESET"
    printf '  - %s\n' "${changed[@]}"
  fi

  if [[ "${#failed[@]}" -gt 0 ]]; then
    printf '%s以下 %d 个项目需要关注:%s\n' "$YELLOW" "${#failed[@]}" "$RESET"
    printf '  %s\n' "${failed[@]}"
    return 1
  fi

  ok "全部 ${#PROJECTS[@]} 个项目已升级到 ${REF} 且检查通过"

  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi

  if [[ "${#committed[@]}" -gt 0 ]]; then
    if [[ "$PUSH" == "1" ]]; then
      ok "已提交并推送 ${#committed[@]} 个项目: ${committed[*]}"
    else
      ok "已提交 ${#committed[@]} 个项目（未推送）: ${committed[*]}"
      printf '%s提示: 需要推送请用 -p 或 PUSH=1 重跑，或在各仓库手动 push。%s\n' "$DIM" "$RESET"
    fi
  else
    printf '%s提示: go.mod / go.sum 已改动，未提交（默认不提交）；确认无误后加 -c 提交或 -p 提交并推送。%s\n' "$DIM" "$RESET"
  fi

  return 0
}

# ── 入口 ──────────────────────────────────────────────────

# 帮助文本优先取自文件头注释（改文档不用改两处）；
# 远程执行时读不到自身文件，退化为内置的简版帮助
usage() {
  if [[ -n "${SCRIPT_FILE}" && -f "${SCRIPT_FILE}" ]]; then
    sed -n '2,/^set /p' "${SCRIPT_FILE}" | sed -e '$d' -e 's/^#\{1,\} \{0,1\}//'
    return 0
  fi

  cat <<'EOF'
简单用法（完整说明见脚本头部注释）:
  ./infra-go.sh [版本] [-c] [-p] [-h]

  版本        默认 latest，可写 main / tag / commit
  -c          检查通过后自动提交
  -p          检查通过后自动提交并推送（隐含 -c）
  -h          查看帮助

环境变量（必须写在脚本名 / bash 前面，否则会被当成版本号）:
  COMMIT=1 PUSH=1 ./infra-go.sh
  SKIP_TEST=1 CROSS=1 ./infra-go.sh main
  WORKDIR     仓库所在根目录；远程执行时默认为当前目录

远程执行:
  curl -fsSL <url> | COMMIT=1 PUSH=1 bash -s --

项目列表在脚本顶部的 PROJECTS 数组里维护。
EOF
}

# 参数解析放在 main 里，保证所有函数都已定义好
# 位置参数只有可选的 [版本]，其余为选项
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c | --commit)
        COMMIT=1
        ;;
      -p | --push)
        COMMIT=1
        PUSH=1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        err "未知参数: $1"
        usage >&2
        exit 2
        ;;
      *)
        REF="$1"
        ;;
    esac
    shift
  done

  REF="${REF:-latest}"
}

main() {
  parse_args "$@"

  log "模块: ${MODULE}    目标版本: ${REF}    项目数: ${#PROJECTS[@]}"
  log "本地仓库目录: ${WORKDIR}"
  if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY_RUN 已开启，不会真正改动文件"
  fi
  if [[ "$COMMIT" == "1" ]]; then
    if [[ "$PUSH" == "1" ]]; then
      warn "PUSH 已开启：检查全部通过的项目会自动提交并推送"
    else
      warn "COMMIT 已开启：检查全部通过的项目会自动提交（不推送）"
    fi
  fi

  local url
  for url in "${PROJECTS[@]}"; do
    upgrade_one "${url}"
  done

  summarize || exit 1
}

main "$@"
