#!/bin/bash

# 引入日志功能和全局变量函数
source 001log2File.sh  # 用于日志记录
source 002get_assets_links.sh  # 用于获取资源下载链接

# 002get_assets_links.sh 中定义了全局变量：
# - LATEST_VERSION: 最新版本号
# - ASSETS_LINKS: 最新版本所有资源下载链接的数组

# 定义全局变量
DOWNLOAD_URL=""  # 用于存储匹配到的唯一下载链接

# 函数: 获取匹配的下载链接
get_download_link() {
  if [ $# -lt 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"  # GitHub release 页面 URL
  local regex="$2"  # 正则表达式匹配规则

  # 调用 get_assets_links 函数以获取资源链接
  get_assets_links "$url" >/dev/null 2>&1  # 使用 GitHub API 获取资源链接

  # 确保 ASSETS_LINKS 数组不为空
  if [ -z "$ASSETS_LINKS" ]; then
    log 3 "未找到资源链接，请检查 URL 或网络连接"
    return 1
  fi

  # 遍历所有链接，找到第一个匹配的链接
  for link in "${ASSETS_LINKS[@]}"; do
    if [[ "$link" =~ $regex ]]; then
      DOWNLOAD_URL="$link"  # 将匹配的链接存入全局变量
      log 1 "匹配到的下载链接: $DOWNLOAD_URL"
      return 0
    fi
  done

  # 如果未找到匹配的链接，则返回错误
  log 3 "未找到符合正则表达式的下载链接，请检查正则表达式"
  return 1
}

# 函数: 下载并安装包文件
install_package() {
  local download_link="$1"  # 下载链接
  local tmp_dir="/tmp/downloads"  # 存储下载文件的临时目录
  mkdir -p "$tmp_dir"  # 确保目录存在

  local filename=$(basename "$download_link")  # 提取文件名
  local filepath="$tmp_dir/$filename"  # 完整路径

  log 1 "开始下载: ${download_link}..."
  local max_retries=3
  local retry_delay=5
  local timeout=30
  local retry_count=0
  local success=false
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -fSL --progress-bar --fail-early \
            --connect-timeout $timeout \
            --retry $max_retries \
            --retry-delay $retry_delay \
            -o "$tmp_dir/$(basename "$download_link")" \
            "${download_link}"; then
            success=true
            log 1 "下载成功: $filepath"
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

    # 根据文件扩展名选择安装方法
    case "${filename##*.}" in
      deb)
        log 1 "安装 $filename..."
        if sudo dpkg -i "$filepath"; then
          log 1 "$filename 安装成功"
        else
          log 2 "安装失败，尝试修复依赖..."
          if sudo apt-get install -f -y; then
            log 2 "依赖修复成功，重试安装..."
            if sudo dpkg -i "$filepath"; then
              log 1 "安装成功"
            else
              log 3 "安装失败"
              return 1
            fi
          else
            log 3 "修复依赖失败"
            return 1
          fi
        fi
        ;;
      gz|tgz)
        log 1 "文件是压缩包: $filename，请手动解压和安装"
        log 2 "已将文件保存到: $filepath"
        return 2  # 提示用户手动处理
        ;;
      *)
        log 3 "不支持的文件类型: ${filename##*.}"
        return 1
        ;;
    esac

    # 清理下载的文件
    log 1 "清理临时文件: $filepath"
    rm -f "$filepath"
  else
    log 3 "下载失败: $download_link"
    return 1
  fi
}

# 如果脚本被直接运行（不是被 source），执行以下示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # 示例：获取匹配的下载链接并安装
  get_download_link "https://github.com/amir1376/ab-download-manager/releases" ".*linux-[^/]*\.deb$"
  if [ $? -eq 0 ]; then
    install_package "$DOWNLOAD_URL"
  else
    log 3 "获取下载链接失败，无法继续安装"
  fi
fi