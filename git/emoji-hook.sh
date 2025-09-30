#!/bin/bash

# ============================================
# Emoji Commit Hook 安装脚本
# --------------------------------------------
# 说明：
# 本脚本会在当前 Git 项目下安装一个 Git Hook，
# 自动为你的提交信息添加对应的 Emoji 前缀。
#
# 默认支持的前缀包括：
#   feat:     -> ✨ feat:
#   fix:      -> 🐛 fix:
#   docs:     -> 📝 docs:
#   style:    -> 🎨 style:
#   refactor: -> ♻️ refactor:
#   test:     -> ✅ test:
#   chore:    -> 🔧 chore:
#   perf:     -> ⚡ perf:
#   ci:       -> 🤖 ci:
#   revert:   -> ⏪ revert:
#   中文支持：新增/修复/优化/撤回
#
# 可选：你可以在项目根目录添加 `.emoji-commitrc` 来覆盖默认规则。
# 使用方式：
#  curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/emoji-hook.sh | bash
#
#
#
#. 全局使用
# mkdir -p $HOME/.githooks
# cat .git/hooks/prepare-commit-msg > "$HOME/.githooks/prepare-commit-msg"
# chmod +x "$HOME/.githooks/prepare-commit-msg"
# git config --global core.hooksPath "$HOME/.githooks"
# ============================================

set -e

HOOK_PATH=".git/hooks/prepare-commit-msg"

echo "🔧 开始安装 Git Emoji commit hook..."

# 检查是否在 git 仓库
if [ ! -d .git ]; then
  echo "❌ 当前目录不是 Git 仓库，请进入项目根目录后再试。"
  exit 1
fi

mkdir -p "$(dirname "$HOOK_PATH")"

# 写入 hook 脚本
cat > "$HOOK_PATH" <<'EOF'
#!/bin/bash

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"
CONFIG_FILE=".emoji-commitrc"

# 跳过 merge commit
if [[ "$COMMIT_SOURCE" == "merge" ]]; then
  exit 0
fi

# 兼容 macOS 和 Linux 的 sed -i
if [[ "$(uname)" == "Darwin" ]]; then
  SED_CMD="sed -i ''"
else
  SED_CMD="sed -i"
fi

# 默认规则
read_default_rules() {
  cat <<'RULES'
feat:|✨ feat:
fix:|🐛 fix:
docs:|📝 docs:
style:|🎨 style:
refactor:|♻️ refactor:
test:|✅ test:
chore:|🔧 chore:
perf:|⚡ perf:
ci:|🤖 ci:
revert:|⏪ revert:
新增:|✨ feat:
修复:|🐛 fix:
优化:|⚡ perf:
撤回:|⏪ revert:
RULES
}

# 加载规则
if [[ -f "$CONFIG_FILE" ]]; then
  RULES=$(grep -Ev '^\s*#|^\s*$' "$CONFIG_FILE" | tr -d '\r')
else
  RULES=$(read_default_rules)
fi

# 替换第一行
FIRST_LINE=$(head -n1 "$COMMIT_MSG_FILE")
while IFS='|' read -r key val; do
  [[ -z "$key" || -z "$val" ]] && continue
  if echo "$FIRST_LINE" | grep -i -q "^$key"; then
    $SED_CMD "1s/^$key/$val/I" "$COMMIT_MSG_FILE"
    break
  fi
done <<< "$RULES"
EOF

# 加执行权限
chmod +x "$HOOK_PATH"

echo
echo "✅ 安装完成！🎉"
echo "✨ 提交时将自动添加 emoji 到 commit message 开头。"
echo "💡 可选：在项目根目录创建 .emoji-commitrc 来自定义规则。"