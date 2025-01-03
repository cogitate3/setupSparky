#!/bin/bash

# 引入日志功能的外部脚本
source 001log2File.sh

# 定义全局变量，用于存储最新版本号和下载链接
LATEST_VERSION=""  # 最新版本号
ASSETS_LINKS=()  # 存储下载链接的数组

# 检查并安装依赖工具
check_dependencies() {
  local dependencies=("jq" "curl" "wget") # 需要的依赖工具列表
  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      log 3 "缺少依赖工具 '$dep'，正在安装..."
      sudo apt update && sudo apt install -y "$dep" || {
        log 3 "无法安装依赖 '$dep'，请手动安装后重试。"
        exit 1
      }
    fi
  done
}

# 验证输入的 GitHub URL 是否有效
validate_url() {
  local url="$1"
  # URL 必须符合 GitHub releases 格式
  if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/releases ]]; then
    log 3 "无效的 GitHub URL: $url。格式应为 'https://github.com/{owner}/{repo}/releases'。"
    exit 1
  fi
}

# 主函数：获取最新版本号和下载链接
get_assets_links() {
  if [ $# -lt 1 ]; then
    log 3 "用法: get_assets_links <GitHub release 页面 URL> [--strip-v]"
    return 1
  fi

  local url="$1"
  local strip_v=false # 默认不去掉版本号的 "v" 前缀
  if [[ "$2" == "--strip-v" ]]; then
    strip_v=true
  fi

  validate_url "$url"  # 验证输入的 URL
  check_dependencies  # 检查是否安装了必要的工具

  # 从 URL 中提取仓库的 owner 和 repo 信息
  local owner_repo
  owner_repo=$(echo "$url" | grep -oP 'github\.com/\K[^/]+/[^/]+')

  # 使用 GitHub API 获取最新 release 信息
  log 1 "正在获取仓库 $owner_repo 的最新发布信息..."
  local api_url="https://api.github.com/repos/$owner_repo/releases/latest"
  local response
  response=$(curl -s "$api_url")

  if [[ $? -ne 0 || -z "$response" ]]; then
    log 3 "无法从 GitHub API 获取发布信息: $api_url"
    return 1
  fi

  # 从 JSON 响应中解析最新版本号
  LATEST_VERSION=$(echo "$response" | jq -r '.tag_name')
  if [[ -z "$LATEST_VERSION" ]]; then
    log 3 "无法从 API 响应中解析最新版本号。"
    return 1
  fi

  # 如果指定了 --strip-v 参数，则去掉版本号中的 "v" 前缀
  if [[ "$strip_v" == true ]]; then
    LATEST_VERSION="${LATEST_VERSION#v}"
  fi

  log 1 "最新版本号: $LATEST_VERSION"

  # 从 JSON 响应中解析所有下载链接0.
  local assets_links
  assets_links=$(echo "$response" | jq -r '.assets[].browser_download_url')

  if [[ -z "$assets_links" ]]; then
    log 2 "最新版本 $LATEST_VERSION 没有找到任何资源下载链接。"
    return 0
  fi

  # 将下载链接保存到全局变量 ASSETS_LINKS 中
  ASSETS_LINKS=()
  while IFS= read -r link; do
    ASSETS_LINKS+=("$link")
    log 1 "- $link" # 记录每个下载链接
  done <<< "$assets_links"

  # 可选：将下载链接保存到一个文本文件
  local output_file="download_links_$LATEST_VERSION.txt"
  printf "%s\n" "${ASSETS_LINKS[@]}" > "$output_file"
  log 1 "下载链接已保存到文件: $output_file"
}

# 如果脚本被直接运行（不是被 source），则调用函数示例
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  get_assets_links "https://github.com/localsend/localsend/releases" --strip-v
fi