#!/bin/bash

# 日志相关配置，引入log函数,set_log_file函数，logger函数
source 001log2File.sh
# log "./logs/0032.log" "第一条消息，同时设置日志文件并记录消息"
# echo 日志记录在"./logs/0032.log"

##############################################################################
# 函数：一次性获取指定repo的最新release JSON数据
# 参数：$1 => https://github.com/xxx/yyy/releases 形式的URL
# 返回：若成功，输出JSON到stdout；若失败，不输出并return 1
##############################################################################
_fetch_latest_release_data() {
  local url="$1"
  local owner_repo

  # 从类似 https://github.com/localsend/localsend/releases 里面提取 "localsend/localsend"
  owner_repo=$(echo "$url" | grep -oP 'github\.com/\K[^/]+/[^/]+')

  # 先安装依赖
  sudo apt install -y jq curl wget

  # 准备一个变量来保存状态码
  local status_code
  status_code="$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$owner_repo/releases/latest")"

  if [[ "$status_code" != "200" ]]; then
    # 若状态码不是200，就return 1
    log 3 "无法访问 GitHub Releases 最新版本 API, 状态码: $status_code"
    return 1
  fi

  # 到此表示API可访问，执行真正获取
  # 将JSON输出到stdout，以便调用者赋值或直接解析
  curl -s "https://api.github.com/repos/$owner_repo/releases/latest"
}

##############################################################################
# get_assets_links 函数
# 说明：获取GitHub仓库的最新版本Release的所有浏览器下载链接
##############################################################################
get_assets_links() {
  # 检查参数
  if [ $# -ne 1 ]; then
    # 3是最高级别的错误级别(例如ERROR)
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"

  # 调用辅助函数一次性获取API数据
  local release_json
  release_json="$(_fetch_latest_release_data "$url")" || {
    log 2 "无法获取最新release信息"
    return 1
  }

  # 使用jq提取tag_name
  # 这里不再做多次curl，只解析一次JSON
  local LATEST_VERSION
  LATEST_VERSION="$(echo "$release_json" | jq -r '.tag_name')"

  # 举个例子：
  # 如果是获取Visual Studio Code的最新版本
  # 1. 首先检查 https://api.github.com/repos/microsoft/vscode/releases/latest 是否能访问
  # 2. 如果能访问，获取JSON数据并提取版本号（比如 "1.85.0"）
  if [ -z "$LATEST_VERSION" ]; then
    log 2 "无法获取最新版本号: 解析 JSON 失败，tag_name为空"
    return 1
  else
    log 2 "最新版本号: $LATEST_VERSION, 获取成功, 但取得的版本号含有v前缀"
  fi

  # 再次使用jq获取所有资源下载链接
  local download_links_json
  download_links_json="$(echo "$release_json" | jq -r '.assets[] | .browser_download_url')"

  if [ -z "$download_links_json" ]; then
    log 2 "无法获取下载链接: assets数组可能为空，但得到了最新版本号：$LATEST_VERSION"
    return 1
  fi

  # 使用 jq 解析 JSON 数组，并循环输出
  DOWNLOAD_LINKS=()
  readarray -t DOWNLOAD_LINKS <<< "$download_links_json"

  if (( ${#DOWNLOAD_LINKS[@]} == 0 )); then
    log 2 "没有找到任何下载链接"
    return 0 # 警告，但不是错误
  fi

  # 打印最新版本，以及所有链接
  log 1 "最新版本: $LATEST_VERSION " # 输出最新版本号，以v开头
  log 1 "所有最新版本的资源下载链接:"
  for link in "${DOWNLOAD_LINKS[@]}"; do
    log 1 "- $link"
  done
}

# 如果脚本被直接运行（而不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  get_assets_links "https://github.com/localsend/localsend/releases"
fi