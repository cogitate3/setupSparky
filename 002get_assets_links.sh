#!/bin/bash

# 日志相关配置，引入log函数,set_log_file函数，logger函数
source 001log2File.sh
# log "./logs/0032.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息
# echo 日志记录在"./logs/0032.log"

get_assets_links() {
  # 检查参数
  if [ $# -ne 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"

  # 使用更可靠的方法提取 owner 和 repo
  local owner_repo=$(echo "$url" | grep -oP 'github\.com/\K[^/]+/[^/]+')

  # 获取最新版本号，并检查 curl 和 jq 的返回值
  # 这行代码分为几个步骤，我们一步一步来执行：
  # 
  # 第1步：检查最新版本的API是否可访问
  # curl -s：安静模式，不显示进度条
  # -o /dev/null：丢弃返回的内容，我们只关心状态码
  # -w "%{http_code}"：只输出HTTP状态码（比如200表示成功）
  # 最后用grep -q 200检查是否返回200（成功）状态码
  # 
  # 第2步：如果第1步成功（&&），则获取版本号
  # curl -s：再次调用API获取完整信息
  # jq -r：用jq工具解析JSON，-r表示原始输出（不带引号）
  # '.tag_name'：从JSON中提取tag_name字段（这就是版本号）
  # 
  # 把上面的步骤组合成一个命令：
  LATEST_VERSION=$(
    # 第1步：检查API是否可访问
    curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$owner_repo/releases/latest" | grep -q 200 && \
    # 第2步：如果可访问，获取版本号
    curl -s "https://api.github.com/repos/$owner_repo/releases/latest" | jq -r '.tag_name'
  )

  # 举个例子：
  # 如果是获取Visual Studio Code的最新版本
  # 1. 首先检查 https://api.github.com/repos/microsoft/vscode/releases/latest 是否能访问
  # 2. 如果能访问，获取JSON数据并提取版本号（比如 "1.85.0"）
  if [ $? -ne 0 ] || [ -z "$LATEST_VERSION" ]; then
    log 3 "无法获取最新版本号: curl 返回码 $?，版本号: $LATEST_VERSION"
    return 1
  fi

  # 获取所有 assets 的下载链接，并检查 curl 和 jq 的返回值
  local download_links_json=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$owner_repo/releases/latest" | grep -q 200 && curl -s "https://api.github.com/repos/$owner_repo/releases/latest" | jq -r '.assets[] | .browser_download_url')

  if [ $? -ne 0 ] || [ -z "$download_links_json" ]; then
    log 3 "无法获取下载链接: curl 返回码 $?，链接: $download_links_json"
    return 1
  fi

  # 使用 jq 解析 JSON 数组，并循环输出
  DOWNLOAD_LINKS=()
  readarray -t DOWNLOAD_LINKS <<< "$download_links_json"

  if (( ${#DOWNLOAD_LINKS[@]} == 0 )); then
    log 2 "没有找到任何下载链接"
    return 0 # 警告，但不是错误
  fi


  log 1 "最新版本: $LATEST_VERSION" # 输出最新版本号，以v开头
  log 1 "所有最新版本的资源下载链接:"
  for link in "${DOWNLOAD_LINKS[@]}"; do
    log 1 "- $link"
  done

}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
get_assets_links "https://github.com/localsend/localsend/releases"
fi
