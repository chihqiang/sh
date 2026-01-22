#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 脚本名称：del-actions.sh
# 脚本作用：删除 GitHub Action 工作流运行记录
# 使用方式：
#  1. 使用环境变量（优先）：
#     export GITHUB_OWNER=username
#     export GITHUB_REPO=my-repo
#     export GITHUB_TOKEN=ghp_xxx
#     export GITHUB_KEEP_LATEST=5
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/github/del-actions.sh)"
# 环境变量：
#   - GITHUB_OWNER: 仓库所有者
#   - GITHUB_REPO: 仓库名称
#   - GITHUB_TOKEN: GitHub 访问令牌（需要 repo 权限）
#   - GITHUB_KEEP_LATEST: 保留最近的运行记录数量（默认：10）
# 功能：
#   - 删除所有工作流的运行记录
#   - 保留最近的运行记录（默认：10个）
#   - 避免 API 速率限制
#   - 彩色输出，提高可读性
# 依赖：
#   - jq: 用于解析 JSON 响应
# 作者：zhiqiang
# 日期：2026-01-22
# =============================================================================

# 颜色定义
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# 从环境变量读取配置
# 从环境变量读取
OWNER=${GITHUB_OWNER:-""}
REPO=${GITHUB_REPO:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
KEEP_LATEST=${GITHUB_KEEP_LATEST:-10}

# 如果环境变量未设置，通过交互输入
if [[ -z "$OWNER" ]]; then
read -p "请输入仓库所有者: " OWNER
fi

if [[ -z "$REPO" ]]; then
read -p "请输入仓库名称: " REPO
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
read -s -p "请输入 GitHub 访问令牌: " GITHUB_TOKEN
 echo
fi

# 检查是否有命令行参数（如果有，显示帮助信息）
if [[ $# -gt 0 ]]; then
  echo -e "${YELLOW}提示: 此脚本不需要命令行参数，使用环境变量或交互式输入配置${NC}"
  echo ""
  show_help
  exit 0
fi

# 检查必填参数
if [[ -z "$OWNER" || -z "$REPO" || -z "$GITHUB_TOKEN" ]]; then
  echo -e "${RED}错误: 必须指定仓库所有者、仓库名称和 GitHub 令牌${NC}"
  exit 1
fi

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
  echo -e "${RED}错误: jq 命令未找到，请安装 jq 以解析 JSON 响应${NC}"
  exit 1
fi

# 构建 API URL
API_BASE="https://api.github.com/repos/$OWNER/$REPO/actions"
HEADERS=("Authorization: token $GITHUB_TOKEN" "Accept: application/vnd.github.v3+json")

# 获取工作流列表
echo -e "${GREEN}获取工作流列表...${NC}"
workflows=$(curl -s -H "${HEADERS[0]}" -H "${HEADERS[1]}" "$API_BASE/workflows")

# 检查 API 响应
if [[ $(echo "$workflows" | jq -r '.message // empty') ]]; then
  echo -e "${RED}API 错误: $(echo "$workflows" | jq -r '.message')${NC}"
  exit 1
fi

# 提取工作流 ID
workflow_ids=$(echo "$workflows" | jq -r '.workflows[].id')

if [[ -z "$workflow_ids" ]]; then
  echo -e "${YELLOW}警告: 未找到工作流${NC}"
  exit 0
fi

# 遍历每个工作流
for workflow_id in $workflow_ids; do
  echo -e "${GREEN}处理工作流 ID: $workflow_id${NC}"
  
  # 获取工作流运行记录
  echo -e "${GREEN}获取工作流运行记录...${NC}"
  runs=$(curl -s -H "${HEADERS[0]}" -H "${HEADERS[1]}" "$API_BASE/workflows/$workflow_id/runs?per_page=100")
  
  # 检查 API 响应
  if [[ $(echo "$runs" | jq -r '.message // empty') ]]; then
    echo -e "${RED}API 错误: $(echo "$runs" | jq -r '.message')${NC}"
    continue
  fi
  
  # 获取所有运行记录
  filtered_runs=$(echo "$runs" | jq -r '.workflow_runs[].id')
  
  # 计算要删除的运行记录
  total_runs=$(echo "$filtered_runs" | wc -l | tr -d ' ')
  if [[ $total_runs -le $KEEP_LATEST ]]; then
    echo -e "${YELLOW}运行记录数量 ($total_runs) 不超过保留数量 ($KEEP_LATEST)，跳过${NC}"
    continue
  fi
  
  # 排序并获取要删除的运行记录
  runs_to_delete=$(echo "$filtered_runs" | tail -n +$((KEEP_LATEST + 1)))
  delete_count=$(echo "$runs_to_delete" | wc -l | tr -d ' ')
  
  if [[ $delete_count -eq 0 ]]; then
    echo -e "${YELLOW}没有需要删除的运行记录${NC}"
    continue
  fi
  
  echo -e "${GREEN}准备删除 $delete_count 个运行记录（保留最近 $KEEP_LATEST 个）${NC}"
  
  # 执行删除
  for run_id in $runs_to_delete; do
    echo -e "${GREEN}删除运行记录 ID: $run_id${NC}"
    response=$(curl -s -X DELETE -H "${HEADERS[0]}" -H "${HEADERS[1]}" "$API_BASE/runs/$run_id")
    
    # 检查删除是否成功
    if [[ $(echo "$response" | jq -r '.message // empty') ]]; then
      echo -e "${RED}删除失败: $(echo "$response" | jq -r '.message')${NC}"
    else
      echo -e "${GREEN}删除成功${NC}"
    fi
    
    # 避免 API 速率限制
    sleep 1
  done
done

echo -e "${GREEN}操作完成${NC}"

