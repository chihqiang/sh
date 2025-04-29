#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/git/user.sh | bash -s github

# 定义关联数组
declare -A users=(
    ["github-actions"]="github-actions[bot]|41898282+github-actions[bot]@users.noreply.github.com"
    ["cnb"]="zhiqiang|eCIr200kcdcRjB6TDaNE4G+zhiqiang@noreply.cnb.cool"
    ["github"]="zhiqiang|40115555+chihqiang@users.noreply.github.com"
    ["gitee"]="zhiqiang|340157+zhiqiangwang@user.noreply.gitee.com"
)

# 检查参数是否存在于数组中
if [[ -n "${users[$1]}" ]]; then
    # 解析键值对
    IFS='|' read -r user email <<< "${users[$1]}"
    
    # 设置 Git 配置
    echo "Set user: ${user}"
    git config user.name "${user}"
    echo "Set email: ${email}"
    git config user.email "${email}"
else
    # 提示未知参数
    echo "Unknown argument. Use one of the following keys: ${!users[*]}"
    exit 1
fi
