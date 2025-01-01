#!/bin/bash

# 定义日志文件路径
LOG_FILE="$HOME/font_install.log"

# 确保日志文件存在并可写
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" || { echo "无法创建日志文件: $LOG_FILE"; exit 1; }
fi

# 日志函数（带颜色输出并保存到日志文件）
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # ANSI 转义序列定义颜色
    local color_reset="\033[0m"
    local color_info="\033[32m"  # 绿色
    local color_warn="\033[33m"  # 黄色
    local color_error="\033[31m" # 红色
    local color_log="\033[34m"   # 蓝色（可选）

    # 日志格式
    local log_entry="[$timestamp] [$level] $message"

    # 根据日志级别输出到终端（带颜色）和日志文件
    case $level in
        1) 
            echo -e "${color_info}[INFO] $log_entry${color_reset}" | tee -a "$LOG_FILE" ;;
        2) 
            echo -e "${color_warn}[WARN] $log_entry${color_reset}" | tee -a "$LOG_FILE" ;;
        3) 
            echo -e "${color_error}[ERROR] $log_entry${color_reset}" | tee -a "$LOG_FILE" >&2 ;;
        *) 
            echo -e "${color_log}[LOG] $log_entry${color_reset}" | tee -a "$LOG_FILE" ;;
    esac
}

# 下载文件的函数，支持三次重试
download_with_retry() {
    local url=$1
    local output_file=$2
    local retries=3
    local count=0

    while ((count < retries)); do
        log 1 "尝试下载文件: $url (尝试次数: $((count + 1)))"
        if wget -q --show-progress "$url" -O "$output_file"; then
            log 1 "成功下载文件: $output_file"
            return 0
        else
            log 2 "下载失败: $url"
            ((count++))
            sleep 2  # 等待 2 秒后重试
        fi
    done

    log 3 "下载失败: $url，超过最大重试次数 ($retries)"
    return 1
}

# 安装字体函数
install_fonts() {
    # 声明关联数组参数
    declare -n font_info=$1

    # 用户本地字体目录（如果没有权限安装到系统目录）
    local user_font_dir="$HOME/.fonts"
    local install_dir="/usr/share/fonts/truetype"

    # 默认使用系统目录，如果无权限，切换为用户目录
    if [ ! -w "$install_dir" ]; then
        log 2 "无权限写入系统字体目录，切换到用户字体目录: $user_font_dir"
        install_dir="$user_font_dir"
        mkdir -p "$install_dir"
    fi

    # 检查并安装必要的命令
    local dependencies=(file wget unzip tar unrar 7z fc-cache)
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log 2 "缺失命令: $cmd，尝试安装..."
            if ! sudo apt-get install -y "$cmd"; then
                log 3 "安装 $cmd 失败，请手动安装后重试！"
                return 1
            fi
        fi
    done

    # 定义临时目录
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # 脚本退出时清理临时目录
    trap 'rm -rf "$tmp_dir"' EXIT

    # 获取已安装字体列表
    log 1 "获取已安装字体列表..."
    local installed_fonts
    installed_fonts=$(fc-list | awk -F: '{print $1}' | xargs -I {} basename {})

    # 安装统计
    local total_installed=0
    local total_skipped=0

    # 遍历字体信息数组
    for font_name in "${!font_info[@]}"; do
        local font_url="${font_info[$font_name]}"
        local download_file="$tmp_dir/${font_name}_download"

        # 下载字体文件（带重试）
        if ! download_with_retry "$font_url" "$download_file"; then
            log 3 "跳过字体: $font_name，下载失败"
            continue
        fi

        # 检查文件类型
        local file_type
        file_type=$(file -b "$download_file")

        # 创建临时解压目录
        local extract_dir="$tmp_dir/${font_name}"
        mkdir -p "$extract_dir"

        # 解压逻辑
        if [[ "$file_type" == *"Zip archive"* ]]; then
            log 1 "解压 ZIP 文件: $font_name..."
            if ! unzip -q "$download_file" -d "$extract_dir"; then
                log 3 "解压失败: $font_name"
                continue
            fi
        elif [[ "$file_type" == *"gzip compressed"* ]]; then
            log 1 "解压 GZIP 文件: $font_name..."
            if ! tar -xzf "$download_file" -C "$extract_dir"; then
                log 3 "解压失败: $font_name"
                continue
            fi
        elif [[ "$file_type" == *"XZ compressed"* ]]; then
            log 1 "解压 XZ 文件: $font_name..."
            if ! tar -xJf "$download_file" -C "$extract_dir"; then
                log 3 "解压失败: $font_name"
                continue
            fi
        elif [[ "$file_type" == *"RAR archive"* ]]; then
            log 1 "解压 RAR 文件: $font_name..."
            if ! unrar x -o+ "$download_file" "$extract_dir/" >/dev/null; then
                log 3 "解压失败: $font_name"
                continue
            fi
        elif [[ "$file_type" == *"7-zip archive"* ]]; then
            log 1 "解压 7Z 文件: $font_name..."
            if ! 7z x "$download_file" -o"$extract_dir/" >/dev/null; then
                log 3 "解压失败: $font_name"
                continue
            fi
        else
            log 1 "非压缩文件，直接处理: $font_name"
            mv "$download_file" "$extract_dir/"
        fi

        # 查找字体文件并安装
        while IFS= read -r font_file; do
            local base_name
            base_name=$(basename "$font_file")

            if [[ "$font_file" =~ \.(ttf|otf|ttc)$ ]]; then
                log 1 "检测到字体文件: $base_name"
            else
                log 2 "跳过非字体文件: $base_name"
                continue
            fi

            # 检查字体是否已安装
            if echo "$installed_fonts" | grep -q "$base_name"; then
                log 2 "字体已安装，跳过: $base_name"
                ((total_skipped++))
            else
                if mv "$font_file" "$install_dir/"; then
                    log 1 "成功安装字体: $base_name"
                    ((total_installed++))
                else
                    log 3 "字体安装失败: $base_name"
                fi
            fi
        done < <(find "$extract_dir" -type f)

        # 清理临时解压目录
        rm -rf "$extract_dir"
    done

    # 更新字体缓存
    log 1 "更新字体缓存..."
    if ! fc-cache -f >/dev/null 2>&1; then
        log 3 "字体缓存更新失败"
        return 1
    fi

    # 输出统计
    log 1 "字体安装完成：已安装 ${total_installed} 个，跳过 ${total_skipped} 个"
    return 0
}

# 示例字体信息
declare -A fonts=(
    ["Roboto"]="https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf"
    ["OpenSans"]="https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-Regular.ttf"
    ["ExampleRar"]="https://example.com/path/to/font-file.rar"
    ["ExampleTarGz"]="https://example.com/path/to/font-file.tar.gz"
    ["ExampleTarXz"]="https://example.com/path/to/font-file.tar.xz"
    ["Example7z"]="https://example.com/path/to/font-file.7z"
)

# 调用安装函数
install_fonts fonts