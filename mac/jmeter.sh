#!/bin/bash

##############################################################################
# 脚本名称：jmeter.sh
# 功能描述：在已安装 Homebrew 的 macOS 系统中，自动完成以下操作：
#           1. 通过 Homebrew 安装或升级 JMeter 到最新版本
#           2. 自动定位 JMeter 核心配置文件 jmeter.properties
#           3. 配置 JMeter 默认中文界面（并备份原始配置文件，防止修改出错）
# 前置条件：
#           1. 设备已安装 Homebrew（未安装会报错并提示手动安装命令）
#           2. 设备已连接网络（用于下载 JMeter 及相关依赖）
#           3. 拥有 macOS 系统管理员权限（部分 brew 操作可能需要输入密码）
# 运行方式：
#           方式1：curl 一键执行（无需手动保存脚本）
#               bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/jmeter.sh)"
#           方式2：手动下载并执行（适合需查看脚本内容场景）
#               1. 下载脚本：curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/jmeter.sh -o install_jmeter.sh
#               2. 赋予权限：chmod +x install_jmeter.sh
#               3. 运行脚本：./install_jmeter.sh
# 注意事项：
#           1. 若已安装 JMeter，脚本会通过 brew upgrade 升级到最新版本
#           2. 配置文件备份路径为：jmeter.properties.bak（与原配置文件同目录）
#           3. 若未找到配置文件，仅提示警告，不中断 JMeter 安装流程
#           4. 脚本仅适配 macOS 系统
##############################################################################


# 检查 Homebrew 是否安装，未安装则直接报错退出
if ! command -v brew &> /dev/null; then
    echo "错误：未检测到 Homebrew 环境"
    echo "请先手动安装 Homebrew，安装命令："
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# 检查 brew 是否能正常执行（避免安装后未配置环境变量的情况）
if ! brew --version &> /dev/null; then
    echo "错误：Homebrew 已安装但无法正常使用，请检查环境变量配置"
    exit 1
fi

# 安装/更新 JMeter
echo "开始通过 Homebrew 安装 JMeter..."
brew update
brew install jmeter

# 验证 JMeter 安装结果
if ! command -v jmeter &> /dev/null; then
    echo "错误：JMeter 安装失败，请检查终端输出的错误信息"
    exit 1
fi

# 定位 jmeter.properties 配置文件（优先固定路径，次用搜索兜底）
JMETER_ROOT=$(brew --prefix jmeter)
JMETER_PROPS="${JMETER_ROOT}/libexec/bin/jmeter.properties"

# 若固定路径不存在，触发 find 搜索
if [ ! -f "$JMETER_PROPS" ]; then
    echo "固定路径未找到配置文件，尝试搜索..."
    JMETER_PROPS=$(find "$JMETER_ROOT" -name "jmeter.properties" | grep -E "/bin/jmeter.properties$" | head -n 1)
fi

# 配置默认中文（仅当配置文件存在时执行）
if [ -z "$JMETER_PROPS" ] || [ ! -f "$JMETER_PROPS" ]; then
    echo "警告：未找到 jmeter.properties，无法设置默认中文"
else
    echo "正在配置 JMeter 默认中文界面..."
    # 仅在无备份时创建，避免覆盖原始备份
    if [ ! -f "${JMETER_PROPS}.bak" ]; then
        cp "$JMETER_PROPS" "${JMETER_PROPS}.bak"
        echo "已备份原始配置：${JMETER_PROPS}.bak"
    fi
    # 修改语言配置（适配 macOS sed 语法）
    sed -i '' 's/^#*language=en/language=zh_CN/' "$JMETER_PROPS"
    echo "中文配置已完成"
fi

# 输出安装成功信息
echo "----------------------------------------"
echo "JMETER 安装成功！"
echo "版本：$(jmeter --version | head -n 1 | awk '{print $3}')"
echo "启动命令：jmeter"
echo "配置文件路径：$JMETER_PROPS"
echo "----------------------------------------"
