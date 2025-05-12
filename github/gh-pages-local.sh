#!/usr/bin/env bash
set -e

# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/github/gh-pages-local.sh | bash -s build dist example.com


# 默认参数
NPM_RUN_BUILD_CMD="${1:-"build"}"
NPM_RUN_BUILD_PATH="${2:-"dist"}"
CNAME_DOMAIN="${3}"

# 输出高亮格式化日志
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

# 构建静态页面
build_dist() {
    log_info "Step 1: Installing dependencies..."
    npm ci || { log_error "npm ci failed"; exit 1; }

    log_info "Step 2: Building project with command: npm run ${NPM_RUN_BUILD_CMD}..."
    npm run "${NPM_RUN_BUILD_CMD}" || { log_error "npm run ${NPM_RUN_BUILD_CMD} failed"; exit 1; }
}

# 推送到 gh-pages 分支
publish_pages() {
    local remote_url="$1"
    local cname_domain="$2"

    log_info "Step 3: Preparing to publish..."
    if [[ -n "$cname_domain" ]]; then
        echo "$cname_domain" > CNAME
        log_info "Added CNAME with domain: $cname_domain"
    fi

    git init
    git remote add origin "$remote_url"
    git branch -M gh-pages
    git add -A
    git commit -m "$(date "+Publish gh pages branch %Y-%m-%d %H:%M:%S")"
    git push -u origin gh-pages --force || { log_error "Git push failed"; exit 1; }
    log_info "Step 4: Pushed to gh-pages branch."
}

# 检查路径有效性
validate_path() {
    if [[ ! -d "$NPM_RUN_BUILD_PATH" ]]; then
        log_error "Build path '$NPM_RUN_BUILD_PATH' does not exist. Please check your build configuration."
        exit 1
    fi
}

# 主执行逻辑
log_info "Checking dependencies..."
check_dependencies

remote_addr=$(git config --get remote.origin.url)
if [[ -z "$remote_addr" ]]; then
    log_error "Unable to fetch remote repository URL. Ensure you are in a git repository."
    exit 1
fi

log_info "Cleaning up temporary files..."
rm -rf node_modules "${NPM_RUN_BUILD_PATH}" || true

build_dist

log_info "Step 5: Validating build directory..."
validate_path

log_info "Entering build directory..."
cd "${NPM_RUN_BUILD_PATH}"

publish_pages "${remote_addr}" "${CNAME_DOMAIN}"

log_info "Deployment completed successfully."
