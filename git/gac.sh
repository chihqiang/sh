#!/bin/bash
set -euo pipefail

#=============================================================================
# gac.sh — Git 多账号 SSH 配置工具
#=============================================================================
#
# 功能:
#   为多个 Git 平台 (GitHub / Gitee / GitLab / 自建) 分别生成独立的
#   SSH 密钥，并自动配置 SSH 和 Git，实现不同仓库自动使用不同身份提交。
#
# 核心流程 (6 步):
#   1. 生成 SSH 密钥        -> ed25519 密钥对，存储在 ~/.ssh/gac/
#   2. 检测端口 & SSH 配置   -> 自动探测 22 端口可达性，写入配置分片
#   3. 生成 Git 身份文件    -> 每个账号独立的 [user] 配置
#   4. 自动身份切换规则     -> includeIf.hasconfig 按仓库路径匹配身份
#   5. 输出公钥             -> 提示用户添加到平台 Settings
#   6. 完成提示             -> 展示克隆命令和提交身份
#
# 实现原理:
#
#   SSH 层面:
#     - ~/.ssh/config 仅在首次运行时追加一行 Include 引用 (后续不再修改):
#         Include ~/.ssh/gac/config.d/*
#     - 每个平台的 SSH 配置写入独立分片文件:
#         ~/.ssh/gac/config.d/github.com
#         ~/.ssh/gac/config.d/gitee.com
#         ...
#     - 每次运行自动检测目标平台 22 端口是否可达，不可达则切换备用地址:
#         github.com:22 不通 -> ssh.github.com:443
#         gitee.com:22  不通 -> ssh.gitee.com
#         gitlab.com:22 不通 -> altssh.gitlab.com:443
#
#   Git 层面:
#     - 每个账号生成独立身份文件:
#         ~/.ssh/gac/gitconfig/github-xqde
#         ~/.ssh/gac/gitconfig/github-zhangsan
#     - ~/.gitconfig 通过 include.path 引用 ~/.ssh/gac/.gitconfig
#     - ~/.ssh/gac/.gitconfig 使用 includeIf.hasconfig 按远程 URL 自动匹配:
#         clone git@github.com:xqde/repo.git  -> 自动用 xqde 身份
#         clone git@github.com:zhangsan/repo.git -> 自动用 zhangsan 身份
#
# 涉及文件:
#
#   SSH 密钥:
#     ~/.ssh/gac/id_ed25519_{platform}-{user}      # 私钥
#     ~/.ssh/gac/id_ed25519_{platform}-{user}.pub  # 公钥
#
#   SSH 配置:
#     ~/.ssh/config                     # 仅首次写入 Include 引用行
#     ~/.ssh/gac/config.d/{hostname}    # 每个平台一个 SSH 配置分片
#
#   Git 身份:
#     ~/.ssh/gac/gitconfig/{platform}-{user}  # 每个账号一个身份文件
#     ~/.ssh/gac/.gitconfig                   # 自动身份切换规则
#     ~/.gitconfig                            # Git 全局配置 (include.path 引用)
#
# 特性:
#   - 纯增量追加，不覆盖已有配置
#   - ~/.ssh/config 只在首次运行写入一次，后续永不修改
#   - 支持同一平台多账号 (github-xqde, github-zhangsan)
#   - 支持 GitHub / Gitee / GitLab / 自建 Git
#   - 自动检测 22/443 端口
#
# 用法:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/gac.sh)"
#=============================================================================


#---------------------------------------
# 日志 & 分割线
#---------------------------------------
info()  { echo "  [INFO] $*"; }
warn()  { echo "  [WARN] $*"; }
ok()    { echo "  [OK]   $*"; }
err()   { echo "  [ERR]  $*"; }

# 华丽分割线
hr()    { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
hr_d()  { echo "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"; }

#---------------------------------------
# 确认 Y/n
#---------------------------------------
confirm() {
    local result
    read -rp "$1 (Y/n): " result
    [[ -z "${result}" || "${result}" =~ ^[Yy]$ ]]
}

#---------------------------------------
# 读取 Git 全局配置
#---------------------------------------
get_git_global() {
    git config --global --get "$1" 2>/dev/null || true
}

#---------------------------------------
# 输入: 平台域名
#---------------------------------------
input_hostname() {
    local default="github.com"
    if confirm "使用默认平台 ${default}"; then
        echo "${default}"
    else
        read -rp "请输入平台域名: " host
        echo "${host}"
    fi
}

#---------------------------------------
# 输入: 用户名
#---------------------------------------
input_username() {
    local default
    default=$(get_git_global user.name)
    if [[ -n "${default}" ]] && confirm "使用默认用户名 ${default}"; then
        echo "${default}"
        return
    fi
    read -rp "请输入用户名: " user
    echo "${user}"
}

#---------------------------------------
# 输入: 邮箱
#---------------------------------------
input_email() {
    local default
    default=$(get_git_global user.email)
    if [[ -n "${default}" ]] && confirm "使用默认邮箱 ${default}"; then
        echo "${default}"
        return
    fi
    read -rp "请输入邮箱: " email
    echo "${email}"
}

#---------------------------------------
# 生成唯一别名: github.com + xqde -> github-xqde
#---------------------------------------
make_alias() {
    echo "${1%%.*}-${2}"
}

#=============================================================================
# 主流程
#=============================================================================
clear

echo ""
echo "  ██████╗  █████╗  ██████╗"
echo "  ██╔════╝ ██╔══██╗ ██╔════╝"
echo "  ██║  ███╗███████║ ██║"
echo "  ██║   ██║██╔══██║ ██║"
echo "  ╚██████╔╝██║  ██║ ╚██████╗"
echo "   ╚═════╝ ╚═╝  ╚═╝  ╚═════╝"
echo ""
echo "     Git Account Config"
echo ""
echo "     多账号 SSH 密钥 & 身份管理"
echo ""
hr

# --- 读取输入 ---
HOSTNAME=$(input_hostname)
USER=$(input_username)
EMAIL=$(input_email)

[[ -z "${HOSTNAME}" ]] && { err "平台不能为空"; exit 1; }
[[ -z "${USER}" ]]     && { err "用户名不能为空"; exit 1; }
[[ -z "${EMAIL}" ]]    && { err "邮箱不能为空"; exit 1; }

# --- 生成路径 ---
ALIAS=$(make_alias "${HOSTNAME}" "${USER}")
GAC_DIR="${HOME}/.ssh/gac"
GITCONFIG_DIR="${GAC_DIR}/gitconfig"
CONFD_DIR="${GAC_DIR}/config.d"           # SSH 分片配置目录
KEY_FILE="${GAC_DIR}/id_ed25519_${ALIAS}"
CONFIG="${HOME}/.ssh/config"
GLOBAL_GIT="${HOME}/.gitconfig"
GIT_USER_FILE="${GITCONFIG_DIR}/${ALIAS}"
SSH_CONF_FILE="${CONFD_DIR}/${HOSTNAME}"   # 每个平台一个 SSH 配置分片

# 确保目录存在
mkdir -p "${GAC_DIR}" "${GITCONFIG_DIR}" "${CONFD_DIR}"

hr_d
info "配置摘要"
info "  平台:       ${HOSTNAME}"
info "  账号:       ${USER}"
info "  邮箱:       ${EMAIL}"
info "  别名:       ${ALIAS}"
echo ""
info "涉及文件:"
info "  ${KEY_FILE}"
info "  ${KEY_FILE}.pub"
info "  ${SSH_CONF_FILE}"
info "  ${GIT_USER_FILE}"
info "  ${GLOBAL_GIT}"

#=====================================================================
# 1. 生成 SSH 密钥
#=====================================================================
hr_d
if [[ -f "${KEY_FILE}" ]]; then
    warn "密钥已存在, 跳过"
    info "  -> ${KEY_FILE}"
else
    info "生成 SSH 密钥 -> ${KEY_FILE}"
    ssh-keygen -t ed25519 -C "${EMAIL}" -f "${KEY_FILE}" -N "" >/dev/null 2>&1
    ok "已生成"
fi

#=====================================================================
# 2. 检测端口并写入 SSH 配置分片
#=====================================================================
hr_d
SSH_HOST="${HOSTNAME}"
SSH_PORT=""

if ! timeout 3 bash -c "echo >/dev/tcp/${HOSTNAME}/22" 2>/dev/null; then
    warn "${HOSTNAME}:22 不可达"
    case "${HOSTNAME}" in
        github.com) SSH_HOST="ssh.github.com";    SSH_PORT="443"; info "切换到 ${SSH_HOST}:${SSH_PORT}" ;;
        gitee.com)  SSH_HOST="ssh.gitee.com";                    info "切换到 ${SSH_HOST}" ;;
        gitlab.com) SSH_HOST="altssh.gitlab.com"; SSH_PORT="443"; info "切换到 ${SSH_HOST}:${SSH_PORT}" ;;
        *)          warn "未知平台, 保持默认 22 端口" ;;
    esac
else
    ok "${HOSTNAME}:22 可达"
fi

# 2.1 确保 ~/.ssh/config 引用 gac 配置目录 (仅首次写入一次)
GAC_INCLUDE_LINE="Include ${CONFD_DIR}/*"
if ! grep -qFx "${GAC_INCLUDE_LINE}" "${CONFIG}" 2>/dev/null; then
    info "首次启用: 在 ${CONFIG} 中添加 Include 引用"
    echo "" >> "${CONFIG}"
    echo "# GAC: 自动管理多账号 SSH 配置" >> "${CONFIG}"
    echo "${GAC_INCLUDE_LINE}" >> "${CONFIG}"
    ok "已添加 Include 引用 (仅此一次)"
else
    ok "${CONFIG} 已包含 Include 引用, 无需修改"
fi

# 2.2 写入/更新平台 SSH 配置分片
if [[ -f "${SSH_CONF_FILE}" ]]; then
    info "SSH 配置分片已存在 -> ${SSH_CONF_FILE}"
else
    info "创建 SSH 配置分片 -> ${SSH_CONF_FILE}"
    {
        echo "# Auto: ${HOSTNAME}  (${HOSTNAME%%.*})"
        echo "Host ${HOSTNAME}"
        echo "  HostName ${SSH_HOST}"
        [[ -n "${SSH_PORT}" ]] && echo "  Port ${SSH_PORT}"
        echo "  User git"
    } > "${SSH_CONF_FILE}"
    ok "Host 块已创建"
fi

# 2.3 追加 IdentityFile (不重复添加)
if grep -qFx "  IdentityFile ${KEY_FILE}" "${SSH_CONF_FILE}" 2>/dev/null; then
    warn "IdentityFile 已存在, 跳过"
    info "  -> ${KEY_FILE}"
else
    info "追加 IdentityFile -> ${SSH_CONF_FILE}"
    echo "  IdentityFile ${KEY_FILE}" >> "${SSH_CONF_FILE}"
    ok "已追加"
fi

#=====================================================================
# 3. 生成 Git 身份文件
#=====================================================================
hr_d
if [[ -f "${GIT_USER_FILE}" ]]; then
    warn "Git 身份文件已存在, 跳过"
    info "  -> ${GIT_USER_FILE}"
else
    info "创建 Git 身份文件 -> ${GIT_USER_FILE}"
    cat > "${GIT_USER_FILE}" << EOF
[user]
  name = ${USER}
  email = ${EMAIL}
EOF
    ok "已创建"
fi

#=====================================================================
# 4. 写入 includeIf 自动身份切换规则
#=====================================================================
hr_d
GAC_GITCONFIG="${GAC_DIR}/.gitconfig"
match_str="git@${HOSTNAME}:${USER}/*"

# 4.1 确保 ~/.gitconfig 引用 gac 配置
if ! git config --global --get-all "include.path" 2>/dev/null | grep -qFx "${GAC_GITCONFIG}"; then
    info "注册 gac 配置入口 -> ${GLOBAL_GIT}"
    git config --global --add "include.path" "${GAC_GITCONFIG}"
    ok "已注册"
fi

# 4.2 写入 includeIf 规则到 gac 专属文件
if git config --file "${GAC_GITCONFIG}" --get-all "includeIf.hasconfig:remote.*.url:${match_str}.path" >/dev/null 2>&1; then
    warn "自动身份规则已存在, 跳过"
    info "  -> ${GAC_GITCONFIG}"
else
    info "追加自动身份规则 -> ${GAC_GITCONFIG}"
    git config --file "${GAC_GITCONFIG}" "includeIf.hasconfig:remote.*.url:${match_str}.path" "${GIT_USER_FILE}"
    ok "已追加"
fi

#=====================================================================
# 5. 输出公钥
#=====================================================================
echo ""
hr
echo ""
echo "   公钥文件: ${KEY_FILE}.pub"
echo ""
echo "   请复制以下内容到 ${HOSTNAME}"
echo "   Settings -> SSH and GPG keys"
echo ""
hr
echo ""
cat "${KEY_FILE}.pub"
echo ""
hr

#=====================================================================
# 6. 完成提示
#=====================================================================
echo ""
ok "配置完成"
echo ""
hr_d
info "涉及文件:"
info "  ${KEY_FILE}"
info "  ${KEY_FILE}.pub"
info "  ${SSH_CONF_FILE}"
info "  ${GIT_USER_FILE}"
info "  ${GLOBAL_GIT}"
hr_d
echo ""
echo "   克隆命令:"
echo "     git clone git@${HOSTNAME}:${USER}/repo.git"
echo ""
echo "   提交身份: ${USER} <${EMAIL}>"
echo ""
hr
