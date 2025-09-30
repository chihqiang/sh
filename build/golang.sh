#!/bin/bash
# ============================================
# 脚本名称：build.sh
# 脚本用途：
#   用于 Go 项目多平台交叉编译构建，支持 Windows、Linux、macOS（amd64/arm64）。
#   自动注入版本号，复制额外文件，打包压缩，并生成 MD5 和 SHA256 校验和。
#
# 必需环境变量（通过 export 设置）：
#   export BIN_NAME="myapp"      # 生成的二进制文件名
#   export VERSION="v1.0.0"      # 版本号
#
# 可选环境变量：
#   export DIST_ROOT_PATH="dist"           # 构建输出目录，默认 dist
#   export MAIN_GO="main.go"               # Go 主入口文件，默认 main.go
#   export ADD_FILES="LICENSE README.md" # 额外复制的文件或目录，多个用空格隔开
#
# 运行示例：
#   export BIN_NAME="myapp" # 生成的二进制文件名
#   export VERSION="v1.0.0"
#   export MAIN_GO="main.go"
#   export ADD_FILES="LICENSE README.md"
#   curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main//build/golang.sh | bash
#
# 输出结果：
#   在输出目录（默认 dist）生成多个平台压缩包（zip/tar.gz）和校验文件：
#     myapp_windows_amd64.zip
#     myapp_linux_amd64.tar.gz
#     myapp_darwin_arm64.tar.gz
#     ...
#     myapp_<VERSION>_checksums.md5
#     myapp_<VERSION>_checksums.sha256
#
# 作者：
#   zhiqiang
# ============================================


# ===== 构建配置 =====
# 二进制文件名，默认当前目录名
BIN_NAME="${BIN_NAME:? BIN_NAME is required}"
# 输出目录，默认 dist
DIST_ROOT_PATH="${DIST_ROOT_PATH:-"dist"}"
# Go 主入口文件路径，默认当前目录（适合 Go module）
MAIN_GO="${MAIN_GO:-"main.go"}"
VERSION="${VERSION:? VERSION is required}"
# 需要额外复制到输出目录的文件或目录（多个用空格隔开）
ADD_FILES="${ADD_FILES:-""}"
ARCHS="${ARCHS:-"windows/amd64 windows/arm64 linux/amd64 linux/arm64 darwin/amd64 darwin/arm64"}"

# ===== 彩色输出函数 =====
# 参数1：颜色代码，参数2：输出文本
color_echo() {
  local color_code=$1
  shift
  printf "\033[%sm%s\033[0m\n" "$color_code" "$*"
}
# 成功提示，绿色
success() { color_echo "1;32" "✅ $@"; }
# 错误提示，红色
error()   { color_echo "1;31" "❌ $@"; }
# 进度提示，青色
step()    { color_echo "1;36" "🚀 $@"; }

# ===== 构建函数 =====
# 参数1：GOOS，参数2：GOARCH，默认自动获取当前环境值
function build() {
    local GOOS=${1:-$(go env GOHOSTOS)}
    local GOARCH=${2:-$(go env GOHOSTARCH)}
    # 临时输出目录
    local dist_tmp_path="${DIST_ROOT_PATH}/${BIN_NAME}_${GOOS}_${GOARCH}"
    local output_bin_name

    # 清理并创建输出目录
    rm -rf "${dist_tmp_path}" && mkdir -p "${dist_tmp_path}"

    # 打印构建信息（英文）
    step "Start building ${BIN_NAME} for ${GOOS}/${GOARCH}, version: ${VERSION}"

    # 根据操作系统决定输出文件名（windows加.exe）
    if [ "$GOOS" == "windows" ]; then
        output_bin_name="${BIN_NAME}.exe"
    else
        output_bin_name="${BIN_NAME}"
    fi

    # 执行编译，注入版本信息
    GOOS=${GOOS} GOARCH=${GOARCH} go build -ldflags="-s -w -X main.version=${VERSION}" \
        -o "${dist_tmp_path}/${output_bin_name}" "${MAIN_GO}" || {
        error "Build failed for ${GOOS}/${GOARCH}"
        exit 1
    }

    # 如果有额外文件，先把换行替换为空格，再按空格拆分
    if [ ! -z "${ADD_FILES}" ]; then
        step "Adding extra files:"
        echo ${ADD_FILES}
        cp -r ${ADD_FILES} ${dist_tmp_path}/
    fi

    # 打包文件名
    local compression_name="${BIN_NAME}_${GOOS}_${GOARCH}"
    local compression_filename

    # Windows 用 zip，其他用 tar.gz
    if [ "$GOOS" == "windows" ]; then
        compression_filename="${compression_name}.zip"
        (cd "${dist_tmp_path}" && zip -r "../${compression_filename}" .)
    else
        compression_filename="${compression_name}.tar.gz"
        (cd "${dist_tmp_path}" && tar -czf "../${compression_filename}" .)
    fi

    success "Packed: ${DIST_ROOT_PATH}/${compression_filename}"

    # 生成 sha256 和 md5 校验文件
    local sha256_checksums_file="${BIN_NAME}_${VERSION}_checksums.sha256"
    local md5_checksums_file="${BIN_NAME}_${VERSION}_checksums.md5"

    (cd "${DIST_ROOT_PATH}" && sha256sum "${compression_filename}" >> "${sha256_checksums_file}")
    (cd "${DIST_ROOT_PATH}" && md5sum    "${compression_filename}" >> "${md5_checksums_file}")

    success "Checksums updated for version ${VERSION}"

    rm -rf "${dist_tmp_path}"
}

# ===== 调用构建 =====
for target in ${ARCHS}; do
    GOOS="${target%/*}"
    GOARCH="${target#*/}"
    build "$GOOS" "$GOARCH"
done

ls -al dist