#!/bin/bash

# 启用严格模式
set -euo pipefail

# 定义日志文件路径和颜色
LOG_FILE="$HOME/font_install.log"
declare -A COLORS=(
    ["INFO"]="\033[32m"   # 绿色
    ["WARN"]="\033[33m"   # 黄色
    ["ERROR"]="\033[31m"  # 红色
    ["DEBUG"]="\033[36m"  # 青色
    ["RESET"]="\033[0m"   # 重置颜色
)

# 错误处理函数
error_handler() {
    local line=$1
    local command=$2
    local code=$3
    log "ERROR" "脚本执行失败 [行 $line]: 命令 '$command' 返回错误码 $code"
    exit $code
}

trap 'error_handler ${LINENO} "${BASH_COMMAND}" $?' ERR

# 清理函数
cleanup() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        log "DEBUG" "清理临时目录: $dir"
    fi
}

# 日志记录函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="${COLORS[$level]:-${COLORS[INFO]}}"
    
    echo -e "${color}[$level] [$timestamp] $message${COLORS[RESET]}" | tee -a "$LOG_FILE"
    [[ "$level" == "ERROR" ]] && >&2 echo -e "${color}[$level] $message${COLORS[RESET]}"
}

# 初始化环境函数
init_environment() {
    # 确保日志目录存在
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    touch "$LOG_FILE" 2>/dev/null || { echo "无法创建日志文件: $LOG_FILE"; exit 1; }
    
    # 首先更新软件包列表
    if ! sudo apt-get update; then
        log "ERROR" "更新软件包列表失败"
        return 1
    }

    # 定义依赖映射
    declare -A pkg_map=(
        ["file"]="file"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["tar"]="tar"
        ["unrar"]="unrar"
        ["7z"]="p7zip-full"
        ["fc-cache"]="fontconfig"
    )

    # 收集缺失的包
    local missing_pkgs=()
    for cmd in "${!pkg_map[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_pkgs+=("${pkg_map[$cmd]}")
        fi
    done

    # 批量安装缺失的依赖
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        log "WARN" "安装缺失的依赖: ${missing_pkgs[*]}"
        if ! sudo apt-get install -y "${missing_pkgs[@]}"; then
            log "ERROR" "依赖安装失败"
            return 1
        fi
    fi

    return 0
}

# 下载函数（带重试）
download_with_retry() {
    local url=$1
    local output=$2
    local max_retries=3
    local retry_delay=2
    local timeout=30

    # 检查 URL 格式
    if [[ ! "$url" =~ ^https?:// ]]; then
        log "ERROR" "无效的URL格式: $url"
        return 1
    }

    for ((i=1; i<=max_retries; i++)); do
        log "INFO" "下载尝试 $i/$max_retries: $url"
        if wget -q --show-progress --timeout="$timeout" --tries=1 "$url" -O "$output"; then
            if [[ -s "$output" ]]; then
                log "DEBUG" "下载成功: $url"
                return 0
            else
                log "ERROR" "下载的文件为空"
                rm -f "$output"
            fi
        fi
        log "WARN" "下载失败，等待 ${retry_delay}s 后重试"
        sleep $retry_delay
        retry_delay=$((retry_delay * 2))
    done
    
    log "ERROR" "下载失败: $url"
    return 1
}

# 解压函数
extract_file() {
    local file=$1
    local dest=$2
    local file_type=$(file -b "$file")
    local success=true
    
    # 检查文件是否存在且可读
    if [[ ! -f "$file" || ! -r "$file" ]]; then
        log "ERROR" "文件不存在或无法读取: $file"
        return 1
    }
    
    log "DEBUG" "解压文件类型: $file_type"
    
    case "$file_type" in
        *"Zip archive"*)
            if ! unzip -q "$file" -d "$dest"; then
                log "ERROR" "ZIP解压失败"
                success=false
            fi
            ;;
        *"gzip compressed"*)
            if ! tar -xzf "$file" -C "$dest"; then
                log "ERROR" "GZIP解压失败"
                success=false
            fi
            ;;
        *"XZ compressed"*)
            if ! tar -xJf "$file" -C "$dest"; then
                log "ERROR" "XZ解压失败"
                success=false
            fi
            ;;
        *"RAR archive"*)
            if ! unrar x -o+ "$file" "$dest" >/dev/null; then
                log "ERROR" "RAR解压失败"
                success=false
            fi
            ;;
        *"7-zip archive"*)
            if ! 7z x "$file" -o"$dest" >/dev/null; then
                log "ERROR" "7Z解压失败"
                success=false
            fi
            ;;
        *"bzip2 compressed"*)
            if ! tar -xjf "$file" -C "$dest"; then
                log "ERROR" "BZIP2解压失败"
                success=false
            fi
            ;;
        *"POSIX tar archive"*)
            if ! tar -xf "$file" -C "$dest"; then
                log "ERROR" "TAR解压失败"
                success=false
            fi
            ;;
        *)
            if [[ "$file" =~ \.(ttf|otf|ttc|woff|woff2)$ ]]; then
                log "DEBUG" "单个字体文件，无需解压"
                cp "$file" "$dest/" || success=false
            else
                log "ERROR" "未知文件类型: $file_type"
                success=false
            fi
            ;;
    esac

    if $success; then
        log "DEBUG" "解压完成: $file -> $dest"
        return 0
    else
        return 1
    fi
}

# 安装字体文件
install_font_file() {
    local font_file=$1
    local install_dir=$2
    local -n existing_fonts=$3
    
    local base_name=$(basename "$font_file")
    
    # 检查文件是否存在且可读
    if [[ ! -f "$font_file" || ! -r "$font_file" ]]; then
        log "ERROR" "字体文件不存在或无法读取: $font_file"
        return 1
    }
    
    # 验证字体文件类型
    if ! file "$font_file" | grep -qiE "font|truetype|opentype"; then
        log "ERROR" "无效的字体文件: $font_file"
        return 1
    }
    
    # 检查重复
    if echo "$existing_fonts" | grep -q "$base_name"; then
        log "WARN" "字体已存在: $base_name"
        return 1
    }
    
    # 尝试安装
    if mv "$font_file" "$install_dir/"; then
        log "INFO" "已安装字体: $base_name"
        return 0
    else
        log "ERROR" "安装失败: $base_name"
        return 1
    fi
}

# 安装字体主函数
install_fonts() {
    declare -n fonts=$1
    local install_dir="${2:-/usr/share/fonts/truetype}"
    
    # 检查并创建字体目录
    if [[ ! -w "$install_dir" ]]; then
        install_dir="$HOME/.fonts"
        mkdir -p "$install_dir" || { log "ERROR" "无法创建字体目录"; return 1; }
        log "INFO" "使用用户字体目录: $install_dir"
    fi
    
    # 创建临时目录
    local tmp_dir
    tmp_dir=$(mktemp -d) || {
        log "ERROR" "无法创建临时目录"
        return 1
    }
    
    # 确保退出时清理临时目录
    trap 'cleanup "$tmp_dir"' EXIT
    
    local installed_fonts=$(fc-list | awk -F: '{print $1}' | xargs -I {} basename {})
    local total_installed=0
    local total_skipped=0
    
    for font_name in "${!fonts[@]}"; do
        local download_file="$tmp_dir/${font_name}_download"
        local extract_dir="$tmp_dir/${font_name}"
        mkdir -p "$extract_dir"
        
        if ! download_with_retry "${fonts[$font_name]}" "$download_file"; then
            continue
        fi
        
        local file_type=$(file -b "$download_file")
        if [[ "$file_type" =~ (TrueType|OpenType)\ font ]]; then
            if install_font_file "$download_file" "$install_dir" installed_fonts; then
                ((total_installed++))
            else
                ((total_skipped++))
            fi
        else
            if extract_file "$download_file" "$extract_dir"; then
                while IFS= read -r font_file; do
                    [[ "$font_file" =~ \.(ttf|otf|ttc|woff|woff2)$ ]] || continue
                    if install_font_file "$font_file" "$install_dir" installed_fonts; then
                        ((total_installed++))
                    else
                        ((total_skipped++))
                    fi
                done < <(find "$extract_dir" -type f)
            else
                log "ERROR" "解压失败: $font_name"
                continue
            fi
        fi
    done
    
    # 更新字体缓存
    if ! fc-cache -f; then
        log "ERROR" "更新字体缓存失败"
        return 1
    fi
    
    log "INFO" "字体安装完成: 安装 $total_installed 个，跳过 $total_skipped 个"
    return 0
}

# 主程序
main() {
    init_environment || exit 1

    # 常用编程 nerd 字体
    declare -A code_fonts_array=(
        ["JetBrainsMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz"
        ["Meslo"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Meslo.tar.xz"
    )

    # 思源字体简繁合集
    declare -A chinese_fonts_array=(
        ["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
        ["SourceHanSansTW"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansTW.zip"
        ["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
        ["SourceHanSerifTW"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/15_SourceHanSerifTW.zip"
    )

 # 增加交互提示
    echo "请选择要安装的字体类别:"
    echo "1. 编程字体"
    echo "2. 中文字体"
    echo "3. 全部字体"
    read -rp "输入选项 (1/2/3): " choice

    case "$choice" in
        1) install_fonts code_fonts_array ;;
        2) install_fonts chinese_fonts_array ;;
        3) 
            install_fonts code_fonts_array
            install_fonts chinese_fonts_array
            ;;
        *) log "ERROR" "无效的选项"; exit 1 ;;
    esac

    log "INFO" "所有字体安装完成"
}

# 执行主程序
main