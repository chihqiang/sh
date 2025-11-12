#!/bin/bash
set -euo pipefail

# =============================================================================
# 脚本名称：init-vue.sh
# 脚本作用：自动化创建 Vue 3 项目（TypeScript + Router + Pinia + ESLint + Prettier）
# 使用方式：
#  bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/project/init-vue.sh)"
# 默认项目名：vue-app（可在提示时修改）
# 功能：
#   - 检查 npm 是否安装
#   - 创建 Vue 项目并自动选择常用配置
#   - 进入项目目录
#   - 初始化 VS Code 设置（可选）
# 作者：zhiqiang
# 日期：2025-11-12
# =============================================================================


# 检查 npm 是否安装
if ! command -v npm &> /dev/null; then
    echo "Error: npm 未安装，请先安装 Node.js 和 npm"
    exit 1
fi

# 提示用户是否使用最新版本
read -p "是否使用 create-vue 最新版本？(y/n, 默认 y): " use_latest
use_latest="${use_latest:-y}"

if [[ "$use_latest" =~ ^[Yy]$ ]]; then
    vue_version="latest"
else
    # 获取 create-vue 所有版本
    echo "正在获取 create-vue 可用版本..."
    versions_json=$(npm view create-vue versions --json)
    
    # 检查 jq 是否安装
    if ! command -v jq &> /dev/null; then
        echo "请先安装 jq 以支持版本选择"
        exit 1
    fi

    versions=($(echo "$versions_json" | jq -r '.[]'))
    
    # 下拉选择版本
    echo "请选择要使用的 create-vue 版本："
    select version in "${versions[@]}"; do
        if [[ -n "$version" ]]; then
            vue_version="$version"
            echo "你选择的版本是 $vue_version"
            break
        else
            echo "无效选择，请重新选择"
        fi
    done
fi

# 提示用户输入项目名称
read -p "请输入项目名称（默认 vue-app）：" project_name
project_name="${project_name:-vue-app}"

echo "正在创建 Vue 项目：$project_name ，使用 create-vue@$vue_version"

# 使用 create-vue 自动化创建项目
npm create vue@"$vue_version" "$project_name" -y -- \
  --typescript \
  --router \
  --pinia \
  --eslint \
  --prettier

echo "项目 $project_name 创建完成！"

# 可选：进入项目目录
cd "$project_name" || exit
echo "已进入项目目录：$(pwd)"
