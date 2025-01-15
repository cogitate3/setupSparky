#!/bin/bash

# 日志相关配置，引入 log 函数, set_log_file 函数, logger 函数
# 以及 get_assets_links 函数(在 002get_assets_links.sh 中)
source 001log2File.sh
source 002get_assets_links.sh

# log "./logs/0032.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息
# echo 日志记录在"./logs/0032.log"

# 002get_assets_links.sh中有一个全局变量DOWNLOAD_LINKS=()，保存了找到的所有最新版的资源下载链接

##############################################################################
# 函数：get_download_link
# 功能：获取用户指定的 GitHub release 页面，调用 get_assets_links 获取所有资源下载链接（保存在 DOWNLOAD_LINKS 中）。
#       然后根据可选的正则表达式做匹配，若匹配成功，则将第一个匹配项存入全局变量 DOWNLOAD_URL。
# 用法：
#       get_download_link <release_url> [regex]
# 参数：
#       release_url: 主页面链接，比如 "https://github.com/amir1376/ab-download-manager/releases"
#       regex: 可选参数，为正则表达式，用于匹配 DOWNLOAD_LINKS 中的下载链接
# 注意：
#       如果 regex 为空，则仅再次输出(或获取)最新版本信息，并结束
##############################################################################
get_download_link() {
  # 检查参数
  if [ $# -lt 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"
  local regex="$2"

  # 只调用一次 get_assets_links，用于初始化 DOWNLOAD_LINKS 和 LATEST_VERSION
  get_assets_links "$url" >/dev/null 2>&1
  
  # 访问参数1的页面，找到规律，写一个正则表达式匹配规则，作为第二个参数，比如".*linux-[^/]*\.deb$"
  # 用chatgpt生成匹配规则
  # local regex="$2"
  
  # 如果参数2为空，则输出找到的最新版本号，但不做链接匹配
  if [ -z "$regex" ]; then
    # 已经执行过 get_assets_links 函数，所以 LATEST_VERSION 已可用
    # 你可以选择把下面的注释还原为实际 log 或 echo
    log 1 "未提供匹配规则，只获取最新版本号: $LATEST_VERSION"
    return 0
  fi

  # 检查 DOWNLOAD_LINKS 是否为空
  if [ -z "${DOWNLOAD_LINKS[*]}" ]; then
    log 3 "未找到资源链接，匹配代码无法运行"
    return 1
  fi

  # 声明一个数组来存储匹配的链接
  declare -a MATCHED_LINKS=()

  # 遍历数组中的每个链接
  for link in "${DOWNLOAD_LINKS[@]}"; do
      # 这里可根据需要决定是否把这条 log 注释掉，比方说仅在 debug 时启用
      # log 1 "Checking link: $link" >/dev/null 2>&1  # Log each link being checked
      if [[ "$link" =~ $regex ]]; then
          MATCHED_LINKS+=("$link")
          log 1 "匹配到: $link"
      else
          log 2 "不匹配: $link"
      fi
  done

  # 显示匹配结果统计
  log 1 "共找到 ${#MATCHED_LINKS[@]} 个匹配的下载链接"

  # Check if a download link was found
  if [ ${#MATCHED_LINKS[@]} -eq 0 ]; then
      log 3 "没有找到合适的下载链接,请检查正则表达式参数"
      return 1
  fi

  # 选择第一个匹配的下载链接
  DOWNLOAD_URL="${MATCHED_LINKS[0]}"
  log 1 "Found matching download link，适配的最新版的下载链接是: $DOWNLOAD_URL"

  return 0
}

##############################################################################
# install_package 函数
# 功能：对下载链接进行最大 max_retries 次重试，并根据文件后缀选择安装方式
#       - .deb => dpkg -i + apt-get install -f -y
#       - .tar.gz/.tgz => 仅提示用户手动安装
#       - 其他 => 不支持的文件类型
##############################################################################
install_package() {
    local download_link="$1"
    local max_retries=3
    local retry_delay=5
    local timeout=30
    local retry_count=0
    local success=false
    
    local tmp_dir="/tmp/downloads"
    mkdir -p "$tmp_dir"
    
    # 给文件名添加一个进程ID后缀，以免并发冲突（可选）
    local file_basename="$(basename "$download_link")"
    local random_suffix="$$"          # 当前脚本进程ID
    local tmp_filename="$file_basename-$random_suffix"

    log 1 "开始下载: ${download_link}..."
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -fSL --progress-bar --fail-early \
            --connect-timeout $timeout \
            --retry $max_retries \
            --retry-delay $retry_delay \
            -o "$tmp_dir/$tmp_filename" \
            "${download_link}"; then
            success=true
            log 1 "下载成功"
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log 2 "下载失败，${retry_delay}秒后进行第$((retry_count + 1))次重试..."
                sleep $retry_delay
            else
                log 3 "下载失败，已达到最大重试次数"
                return 1
            fi
        fi
    done

    if [ "$success" = true ]; then
        local need_cleanup=true
        local install_status=0
        
        # 根据文件后缀处理
        case "${file_basename##*.}" in
            deb)
                log 1 "安装 $file_basename..."
                if sudo dpkg -i "$tmp_dir/$tmp_filename"; then
                    log 2 "$file_basename 安装成功"
                else
                    log 2 "首次安装失败，尝试修复依赖..."
                    if sudo apt-get install -f -y; then
                        log 2 "依赖修复成功，重试安装"
                        if sudo dpkg -i "$tmp_dir/$tmp_filename"; then
                            log 2 "安装成功"
                        else
                            log 3 "安装失败"
                            install_status=1
                        fi
                    else
                        log 3 "依赖修复失败"
                        install_status=1
                    fi
                fi
                ;;
            gz|tgz)
                if [[ "$file_basename" == *.tar.gz || "$file_basename" == *.tgz ]]; then
                    log 1 "下载的文件是压缩包: $file_basename，需要手动安装"
                    install_status=2
                    ARCHIVE_FILE="$tmp_dir/$tmp_filename"
                    need_cleanup=false  # 保留文件供后续使用
                    log 2 "文件已保存到: $ARCHIVE_FILE，请手动完成安装"
                fi
                ;;
            *)
                log 3 "不支持的文件类型: ${file_basename##*.}"
                install_status=1
                ;;
        esac
        
        # 根据需要清理文件
        if [ "$need_cleanup" = true ]; then
            log 1 "清理下载的文件: $tmp_dir/$tmp_filename"
            rm -f "$tmp_dir/$tmp_filename"
        fi
        
        return $install_status
    else
        log 3 "下载失败"
        return 1
    fi
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # 示例用法
  get_download_link "https://github.com/amir1376/ab-download-manager/releases" '.*\.deb\.md5$'
  install_package "$DOWNLOAD_URL"
fi