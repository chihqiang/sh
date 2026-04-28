#!/bin/bash
# ==============================================
# Homebrew 清华镜像管理脚本
# 功能：
# 1. 安装 Homebrew 并配置清华镜像
# 2. 仅切换已安装 Homebrew 为清华镜像
# 3. 恢复官方源并清理镜像环境变量
# 4. 仅卸载清华镜像配置（保留 Homebrew）
# 5. 彻底卸载 Homebrew 及其所有组件
# 特点：
# - 所有配置文件修改带日志可见
# - 环境变量自动清理，无残留
# - 支持 Intel / Apple Silicon 全机型
# - 交互简洁，执行一次自动退出
# 运行示例：
#   1. 直接通过 curl 一键执行脚本（默认使用设备 en0）：
#      bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/brew.sh)"
# 官方源：
# - https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
# ==============================================

# ====================== 全局常量 ======================
TUNA_BREW_GIT="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
TUNA_CORE_GIT="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
TUNA_CASK_GIT="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git"
TUNA_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
TUNA_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"

OFFICIAL_BREW_GIT="https://github.com/Homebrew/brew.git"
OFFICIAL_CORE_GIT="https://github.com/Homebrew/homebrew-core"
OFFICIAL_CASK_GIT="https://github.com/Homebrew/homebrew-cask"

PROFILE_FILES=(
    "$HOME/.zprofile"
    "$HOME/.bash_profile"
    "$HOME/.zshrc"
    "$HOME/.bashrc"
)

CONFIG_SIGN="# Homebrew Tuna Mirror Config"
BREW_OPT_PATH="/opt/homebrew"
BREW_USR_PATH="/usr/local/Homebrew"

# ====================== 日志 ======================
COLOR_INFO='\033[36m'
COLOR_SUCC='\033[32m'
COLOR_WARN='\033[33m'
COLOR_ERR='\033[31m'
COLOR_RESET='\033[0m'

log_info()  { echo -e "${COLOR_INFO}[$(date +'%Y-%m-%d %H:%M:%S')] INFO  $1${COLOR_RESET}"; }
log_succ()  { echo -e "${COLOR_SUCC}[$(date +'%Y-%m-%d %H:%M:%S')] OK    $1${COLOR_RESET}"; }
log_warn()  { echo -e "${COLOR_WARN}[$(date +'%Y-%m-%d %H:%M:%S')] WARN  $1${COLOR_RESET}"; }
log_err()   { echo -e "${COLOR_ERR}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR $1${COLOR_RESET}"; }

# ====================== 工具函数 ======================
sed_inplace() {
    [[ "$(uname -s)" == "Darwin" ]] && sed -i '' "$1" "$2" || sed -i "$1" "$2"
}

cmd_exist() {
    command -v "$1" >/dev/null 2>&1
}

show_path() {
    echo "${1/#$HOME/~}"
}

# ====================== 清理环境变量 ======================
clear_brew_env() {
    log_info "开始清理所有 Homebrew 镜像环境变量"
    for file in "${PROFILE_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "清理配置文件：$(show_path "$file")"
            sed_inplace "/^${CONFIG_SIGN}/d" "$file"
            sed_inplace '/^export HOMEBREW_BREW_GIT_REMOTE/d' "$file"
            sed_inplace '/^export HOMEBREW_CORE_GIT_REMOTE/d' "$file"
            sed_inplace '/^export HOMEBREW_API_DOMAIN/d' "$file"
            sed_inplace '/^export HOMEBREW_BOTTLE_DOMAIN/d' "$file"
        fi
    done
    log_succ "镜像环境变量清理完成"
}

# ====================== 写入环境变量 ======================
write_brew_env() {
    local content="$1"
    log_info "开始写入清华镜像环境变量"
    for file in "${PROFILE_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "写入配置文件：$(show_path "$file")"
            echo -e "\n$content" >> "$file"
        fi
    done
    log_succ "环境变量写入完成"
}

# ====================== 1. 安装 ======================
install_brew_tuna() {
    log_info "开始安装 Homebrew 并绑定清华镜像"
    [[ "$(uname -s)" == "Darwin" ]] && {
        xcode-select --install >/dev/null 2>&1 || log_warn "Xcode 工具已安装"
    }

    export HOMEBREW_BREW_GIT_REMOTE="$TUNA_BREW_GIT"
    export HOMEBREW_CORE_GIT_REMOTE="$TUNA_CORE_GIT"
    export HOMEBREW_INSTALL_FROM_API=1

    rm -rf brew-install
    git clone --depth=1 "$TUNA_BREW_GIT" brew-install >/dev/null 2>&1
    bash brew-install/install.sh
    rm -rf brew-install

    switch_only_tuna
}

# ====================== 2. 切换清华源 ======================
switch_only_tuna() {
    if ! cmd_exist brew; then
        log_err "请先安装 Homebrew"
        return
    fi

    clear_brew_env
    log_info "切换 Git 仓库为清华镜像"

    local brew_root
    brew_root="$(brew --repo)"
    git -C "$brew_root" remote set-url origin "$TUNA_BREW_GIT"
    brew tap --custom-remote homebrew/core "$TUNA_CORE_GIT" 2>/dev/null
    brew tap --custom-remote homebrew/cask "$TUNA_CASK_GIT" 2>/dev/null

    local env_content
    env_content="${CONFIG_SIGN}
export HOMEBREW_BREW_GIT_REMOTE=\"${TUNA_BREW_GIT}\"
export HOMEBREW_CORE_GIT_REMOTE=\"${TUNA_CORE_GIT}\"
export HOMEBREW_API_DOMAIN=\"${TUNA_API_DOMAIN}\"
export HOMEBREW_BOTTLE_DOMAIN=\"${TUNA_BOTTLE_DOMAIN}\""

    write_brew_env "$env_content"

    if [[ -d "$BREW_OPT_PATH" ]]; then
        local shell_cmd='eval "$(/opt/homebrew/bin/brew shellenv)"'
        for file in "${PROFILE_FILES[@]}"; do
            if [[ -f "$file" ]] && ! grep -qxF "$shell_cmd" "$file"; then
                log_info "补充 Apple Silicon 环境：$(show_path "$file")"
                echo "$shell_cmd" >> "$file"
            fi
        done
    fi

    brew update >/dev/null 2>&1
    log_succ "清华镜像切换完成"
}

# ====================== 3. 恢复官方源 ======================
restore_official_source() {
    if ! cmd_exist brew; then
        log_err "Homebrew 未安装"
        return
    fi

    log_info "恢复 Homebrew 官方原始源"
    git -C "$(brew --repo)" remote set-url origin "$OFFICIAL_BREW_GIT"
    brew tap --custom-remote homebrew/core "$OFFICIAL_CORE_GIT" 2>/dev/null
    brew tap --custom-remote homebrew/cask "$OFFICIAL_CASK_GIT" 2>/dev/null

    clear_brew_env

    brew update >/dev/null 2>&1
    log_succ "已完全恢复官方源"
}

# ====================== 4. 仅卸载镜像配置 ======================
remove_mirror_config() {
    clear_brew_env
    log_succ "镜像环境配置已卸载"
}

# ====================== 5. 彻底卸载 Homebrew ======================
uninstall_homebrew_full() {
    if ! cmd_exist brew; then
        log_err "Homebrew 未安装，无需卸载"
        return
    fi

    log_warn "================================================"
    log_warn "  警告：你即将 彻底卸载 Homebrew 及其所有安装包"
    log_warn "  此操作不可恢复！所有软件都会被删除！"
    log_warn "================================================"
    echo
    read -p "确定要彻底卸载吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消卸载"
        return
    fi

    log_info "开始执行 Homebrew 官方卸载脚本..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" --force

    log_info "清理残留目录..."
    [[ -d "$BREW_OPT_PATH" ]] && { log_info "删除：$BREW_OPT_PATH"; sudo rm -rf "$BREW_OPT_PATH"; }
    [[ -d "$BREW_USR_PATH" ]] && { log_info "删除：$BREW_USR_PATH"; sudo rm -rf "$BREW_USR_PATH"; }

    clear_brew_env

    log_succ "================================================"
    log_succ "  Homebrew 已彻底卸载完成！"
    log_succ "================================================"
}

# ====================== 菜单 ======================
show_menu() {
    clear
    echo "=================================================="
    echo "        Homebrew 镜像一键管理工具"
    echo "=================================================="
    echo "  1  安装 Homebrew + 配置清华镜像"
    echo "  2  仅切换为清华镜像源"
    echo "  3  恢复官方源（清空环境变量）"
    echo "  4  仅卸载镜像配置（保留brew）"
    echo "  5  彻底卸载 Homebrew（删除全部）"
    echo "=================================================="
    read -p "请选择操作：" opt
}
# ====================== 主程序 ======================
main() {
    show_menu
    case "$opt" in
        1) install_brew_tuna ;;
        2) switch_only_tuna ;;
        3) restore_official_source ;;
        4) remove_mirror_config ;;
        5) uninstall_homebrew_full ;;
        *) log_err "无效输入" ;;
    esac
}

main