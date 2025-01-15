#!/bin/bash

# 日志相关配置，引入log函数,set_log_file函数，logger函数
source 001log2File.sh
source 002get_assets_links.sh
# log "./logs/0032.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息
# echo 日志记录在"./logs/0032.log"

# 002getLinks.sh中有一个全局变量DOWNLOAD_LINKS=()，保存了找到的所有最新版的资源下载链接

get_download_link() {
  # 检查参数
  if [ $# -lt 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"
  get_assets_links "$url" >/dev/null 2>&1
  
  # 访问参数1的页面，找到规律，写一个正则表达式匹配规则，作为第二个参数，比如".*linux-[^/]*\.deb$"
  # 用chatgpt生成匹配规则
  local regex="$2"  
  # 如果参数2为空，则输出找到的最新版本号
  # 如果参数2不为空，参数2为正则表达式，函数输出匹配的下载链接；
  # 输入参数2时，不要加两边的双引号
  if [ -z "$regex" ]; then
    get_assets_links "$url" >/dev/null 2>&1
    # log 1 "未提供匹配规则，输出获取的远程最新版本号: $LATEST_VERSION "
    # log 1 "LATEST_VERSION 这个变量的值来自 get_assets_links 函数"
    # log 1 "获得全局变量 LATEST_VERSION 的值必须执行一次这个函数"

    return 0
  fi

  # 检查 DOWNLOAD_LINKS 是否为空
  if [ -z "$DOWNLOAD_LINKS" ]; then
    log 3 "未找到资源链接，匹配代码无法运行"
    return 1
  fi

  # 声明一个数组来存储匹配的链接
  declare -a MATCHED_LINKS=()

  # 遍历数组中的每个链接
  for link in "${DOWNLOAD_LINKS[@]}"; do
      log 1 "Checking link: $link" >/dev/null 2>&1 # Log each link being checked
      if [[ "$link" =~ $regex ]]; then
      # =~ 是正则表达式匹配操作符
      # 左边是要测试的字符串
      # 右边是正则表达式模式
          MATCHED_LINKS+=("$link")
          # += 是数组追加操作符
          # 将新元素添加到数组末尾
          # 保持原有元素不变
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
  log 1 "Found matching download link，适配的最新版的下载链接是: "
  log 1 "$DOWNLOAD_URL"

  return 0
}

install_package() {
    local download_link="$1"
    local max_retries=3
    local retry_delay=5
    local timeout=30
    local retry_count=0
    local success=false
    
    # 下载文件:
    # -f: 失败时不输出错误页面
    # -S: 显示错误信息
    # -L: 跟随重定向
    # --progress-bar: 显示下载进度条
    # --fail-early: 在错误时尽早失败

    local tmp_dir="/tmp/downloads"
    mkdir -p "$tmp_dir"
    
    log 1 "开始下载: ${download_link}..."
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -fSL --progress-bar --fail-early \
            --connect-timeout $timeout \
            --retry $max_retries \
            --retry-delay $retry_delay \
            -o "$tmp_dir/$(basename "$download_link")" \
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
        # 提取文件名
        local filename=$(basename "$download_link")
        local need_cleanup=true
        local install_status=0
        
        # ${filename##*.} extracts the file extension:
        # ## removes the longest matching pattern (everything up to the last dot)
        # Example: for "package.tar.gz", this gives "gz"
        case "${filename##*.}" in
            deb)
                log 1 "安装 $filename..."
                if sudo dpkg -i "$tmp_dir/$filename"; then # dpkg -i 不需要联网
                    log 2 "$filename 安装成功"
                else
                    log 2 "首次安装失败，尝试修复依赖..."
                    if sudo apt-get install -f -y; then # apt-get install -f -y 需要联网
                        log 2 "依赖修复成功，重试安装"
                        if sudo dpkg -i "$tmp_dir/$filename"; then
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
                if [[ "$filename" == *.tar.gz || "$filename" == *.tgz ]]; then
                    log 1 "下载的文件是压缩包: $filename，无法使用apt或者dpkg安装，需要手动安装"
                    install_status=2
                    ARCHIVE_FILE="$tmp_dir/$filename"
                    need_cleanup=false  # 保留文件供后续使用
                    install_status=2    # 需要手动安装
                    log 2 "文件已保存到: $ARCHIVE_FILE，请手动完成安装"
                    return $install_status
                fi
                ;;
            *)
                log 3 "不支持的文件类型: ${filename##*.}"
                install_status=1
                ;;
        esac
        
        # 根据需要清理文件
        if [ "$need_cleanup" = true ]; then
            log 1 "清理下载的文件..."
            rm -f "$tmp_dir/$filename"
        fi
        
        return $install_status
    else
        log 3 "下载失败"
        install_status=1
        return $install_status
    fi
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # 示例用法
  get_download_link "https://github.com/amir1376/ab-download-manager/releases" .*\.deb\.md5$
  install_package ${DOWNLOAD_URL}
fi
