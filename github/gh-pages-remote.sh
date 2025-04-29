#!/usr/bin/env bash
set -e
# Usage:
# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/github/gh-pages-remote.sh | bash -s \
# https://github.com/drawdb-io/drawdb.git main https://github.com/drawdb-io/drawdb.git build dist example.com

ORIGIN_GIT_URL="${1}"
ORIGIN_GIT_BRANCH="${2:-"main"}"
TARGET_GIT_URL="${3}"
NPM_RUN_BUILD_CMD="${4:-"build"}"
NPM_RUN_BUILD_PATH="${5:-"dist"}"
CNAME_DOMAIN="${6}"

WORKSPACE_CODE_PATH="$(pwd)/code"
BUILD_PATH="$WORKSPACE_CODE_PATH/$NPM_RUN_BUILD_PATH"

# 格式化日志输出
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# 检查必要命令是否存在
check_dependencies() {
    for cmd in git npm; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Command $cmd is not installed."
            exit 1
        fi
    done
}

# 清理工作区
clean_workspace() {
    log_info "Cleaning workspace: $WORKSPACE_CODE_PATH"
    rm -rf "$WORKSPACE_CODE_PATH"
    mkdir -p "$WORKSPACE_CODE_PATH"
}

# 构建静态页面
download_and_build_dist() {
    local git_url="$1"
    local git_branch="$2"
    local workspace="$3"
    local build_cmd="$4"

    log_info "Cloning repository from $git_url (branch: $git_branch)..."
    git clone -b "$git_branch" "$git_url" "$workspace" || {
        log_error "Failed to clone repository."
        exit 1
    }

    log_info "Installing dependencies..."
    cd "$workspace" && npm install || {
        log_error "Failed to install dependencies."
        exit 1
    }

    log_info "Building project with command: npm run $build_cmd..."
    npm run "$build_cmd" || {
        log_error "Failed to build project."
        exit 1
    }
}

# 推送到 gh-pages 分支
publish_to_gh_pages() {
    local remote_url="$1"
    local cname_domain="$2"

    log_info "Preparing to publish to $remote_url..."

    if [[ -n "$cname_domain" ]]; then
        echo "$cname_domain" > CNAME
        log_info "Added CNAME with domain: $cname_domain"
    fi

    git init
    git remote add origin "$remote_url"
    git branch -M gh-pages
    git add -A
    git commit -m "$(date "+Publish gh pages branch %Y-%m-%d %H:%M:%S")"
    git push -u origin gh-pages --force || {
        log_error "Failed to push to gh-pages."
        exit 1
    }

    log_info "Successfully pushed to gh-pages branch."
}

log_info "Starting deployment process..."

# 检查依赖
check_dependencies

# 清理并创建工作区
clean_workspace

# 下载代码并构建
download_and_build_dist "$ORIGIN_GIT_URL" "$ORIGIN_GIT_BRANCH" "$WORKSPACE_CODE_PATH" "$NPM_RUN_BUILD_CMD"

# 验证构建目录
if [[ -d "$BUILD_PATH" ]]; then
    log_info "Entering build directory: $BUILD_PATH"
    cd "$BUILD_PATH"
else
    log_error "Build directory $BUILD_PATH does not exist."
    exit 1
fi

# 推送到 gh-pages
publish_to_gh_pages "$TARGET_GIT_URL" "$CNAME_DOMAIN"