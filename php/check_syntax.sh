#!/bin/bash
set -euo pipefail

# ==========================================================================
# PHP 语法检查脚本
#
# 功能：
#   遍历当前目录下所有 PHP 文件（排除 vendor 和 node_modules），执行语法检查
#
# 使用示例：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/php/check_syntax.sh)"
#
# 作者：zhiqiang
# 日期：2025-06-13
# ==========================================================================


# 颜色函数
green() { echo -e "\033[32m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# 统计变量
total=0
success=0
fail=0

# 遍历所有 PHP 文件，排除 vendor 和 node_modules
while IFS= read -r file; do
  ((total++))
  result=$(php -l "$file" 2>&1)
  if [[ $result == *"No syntax errors detected"* ]]; then
    ((success++))
    green "✅ [OK] $file"
  else
    ((fail++))
    red "❌ [ERROR] $file"
    echo "$result"
    exit 1;
  fi
done < <(find . -type f -name "*.php"  -not -path "*/vendor/*" -not -path "*/node_modules/*")

# 输出统计结果
echo "----------------------------------------"
green "✔️  检查完成：共 $total 个文件，成功 $success 个"
if [[ $fail -gt 0 ]]; then
  red "❌ 有 $fail 个文件存在语法错误"
else
  green "✅ 所有文件语法正常"
fi
