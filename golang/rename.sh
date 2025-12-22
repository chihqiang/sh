#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 🟢 Go Module Rename & Migrate (Interactive)
#
# 功能：
#   1. 检查当前目录是否为 git 仓库，且所有改动已提交
#   2. 检查当前目录是否有 go.mod 文件
#   3. 获取当前 module 名称
#   4. 交互式输入新的 module 路径
#   5. 替换 go.mod 和 import 路径
#   6. 执行 go mod tidy
#   7. 执行 go test ./...
#
# 注意：
#   - 脚本会修改源文件，请确保 git 工作区干净
#   - 支持 Linux/macOS sed 语法
#
# 使用方式：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/golang/rename.sh)"
# ==============================================================================

echo "🟢 Go module rename & migrate (interactive)"
echo

# 🔎 检查是否在 git 仓库
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 当前目录不是 git 仓库"
  exit 1
fi

# 🔎 检查是否有未提交的改动
if ! git diff-index --quiet HEAD --; then
  echo "❌ 当前 git 有未提交的改动，请先提交或 stash"
  git status --short
  exit 1
fi


# 1️⃣ 判断是否存在 go.mod
if [ ! -f go.mod ]; then
  echo "❌ 当前目录没有 go.mod"
  exit 1
fi

# 2️⃣ 获取 go.mod 文件中的 module 名称
OLD_MODULE=$(go mod edit -json | sed -n 's/.*"Path": "\(.*\)".*/\1/p' | head -n1)
if [ -z "$OLD_MODULE" ]; then
  echo "❌ 无法从 go.mod 读取 module"
  exit 1
fi
echo "当前 module: $OLD_MODULE"
echo

# 3️⃣ 输入新的 module 名称
read -r -p "请输入新的 module 路径: " NEW_MODULE
if [ -z "$NEW_MODULE" ]; then
  echo "❌ 新 module 不能为空"
  exit 1
fi

# 4️⃣ 对比新旧 module
if [ "$NEW_MODULE" = "$OLD_MODULE" ]; then
  echo "⚠️ 新旧 module 相同，无需修改"
  exit 0
fi

echo
echo "将执行以下操作："
echo "  - go.mod: $OLD_MODULE → $NEW_MODULE"
echo "  - 替换 import 中的路径"
echo "  - 执行 go mod tidy"
echo "  - 执行 go test ./..."
echo

read -r -p "确认继续？(y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

# 5️⃣ 修改 go.mod
echo "修改 go.mod"
go mod edit -module "$NEW_MODULE"

# 6️⃣ 遍历所有 go 文件，替换 import 中的旧 module 并打印修改的文件名
echo "替换 import 路径并打印修改文件"

if sed --version >/dev/null 2>&1; then
  SED=(-i)
else
  SED=(-i '')
fi

find . -name '*.go' -type f | while read -r file; do
  # 检查文件中是否存在旧 module
  if grep -q "$OLD_MODULE" "$file"; then
    # 替换 import
    sed "${SED[@]}" -E "/^[[:space:]]*import[[:space:]]+/ s|$OLD_MODULE|$NEW_MODULE|g" "$file"
    sed "${SED[@]}" -E "/^[[:space:]]*import[[:space:]]*\(/,/^[[:space:]]*\)/ s|$OLD_MODULE|$NEW_MODULE|g" "$file"
    echo "修改文件: $file"
  fi
done

# 7️⃣ 执行 go mod tidy
echo "执行 go mod tidy"
go mod tidy

# 8️⃣ 执行 go test ./...
echo "执行 go test ./..."
if ! go test ./...; then
  echo "❌ 测试未通过，请检查代码"
  exit 1
fi

# 9️⃣ 输出完成提示
echo "操作完成 ✅"
echo "module 已更新为: $NEW_MODULE"
echo "import 路径已替换，依赖已整理，所有测试通过"
