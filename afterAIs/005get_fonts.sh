#!/bin/bash

# 启用 Bash 的严格模式，提高脚本的健壮性：
# -e: 如果任何命令返回非零状态（失败），立即退出脚本
# -u: 当使用未定义的变量时报错并退出，而不是默认将其视为空值
# -o pipefail: 使管道命令返回最后一个非零状态，而不是最后一个命令的状态
#             例如：false | true 默认返回 true，启用后返回 false 的状态
set -euo pipefail 

# 保存原始 IFS 并设置新的 IFS
# IFS (Internal Field Separator) 是 Bash 用来分割字符串的分隔符：
# - 默认值是空格、制表符和换行符 (空格 tab \n)
# - 这里将其改为只使用换行符和制表符，不使用空格分割
# - 这样可以安全地处理文件名或变量中包含空格的情况
# 示例：
# - 默认 IFS 时：  "a b c" 会被分割为 "a" "b" "c"
# - 修改后的 IFS： "a b c" 会被保持为 "a b c"
OLD_IFS="$IFS"      # 保存原始的 IFS 值
IFS=$'\n\t'         # 设置新的 IFS 为换行符和制表符

# trap 命令用于在脚本接收到信号时执行指定的命令：
# - EXIT：在脚本退出时执行（包括正常退出和错误退出）
# - INT：在接收到中断信号时执行（通常是 Ctrl+C）
# - TERM：在接收到终止信号时执行
# - ERR：在命令执行出错时执行
#
# 语法：trap 'commands' signals
# 示例：
# - trap 'rm -f tmpfile' EXIT  # 退出时删除临时文件
# - trap 'echo "已中断"' INT   # 按 Ctrl+C 时显示消息
#
# 这里设置了两个 trap：
# 1. 在脚本退出时恢复原始的 IFS 值
# 2. 在命令出错时显示错误信息和行号
trap 'IFS="$OLD_IFS"' EXIT
trap 'error_handler ${LINENO} "${BASH_COMMAND}" $?' ERR

# 日志文件路径
LOG_FILE="$HOME/font_install.log"

# 定义日志颜色
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

# 日志记录函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="${COLORS[$level]:-${COLORS[INFO]}}"

    # 打印到控制台并写入日志文件
    echo -e "${color}[$level] [$timestamp] $message${COLORS[RESET]}" | tee -a "$LOG_FILE"
    [[ "$level" == "ERROR" ]] && >&2 echo -e "${color}[$level] $message${COLORS[RESET]}"
}

# 初始化环境
init_environment() {
    log "INFO" "初始化环境..."

    # 检查日志目录权限
    if [[ ! -w "$HOME" ]]; then
        echo "无法写入日志文件目录: $HOME"
        exit 1
    fi

    # 确保日志文件可写
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE" || { echo "无法创建日志文件: $LOG_FILE"; exit 1; }

    # 更新软件包列表
    if ! sudo apt-get update; then
        log "ERROR" "更新软件包列表失败"
        return 1
    fi

    # 检查依赖
    declare -A pkg_map=(
        ["file"]="file"       # 检测文件类型
        ["wget"]="wget"       # 下载工具
        ["unzip"]="unzip"     # 解压 ZIP 文件
        ["tar"]="tar"         # 解压 tar 文件
        ["unrar"]="unrar"     # 解压 RAR 文件
        ["7z"]="p7zip-full"   # 解压 7Z 文件
        ["fc-cache"]="fontconfig"  # 刷新字体缓存
    )

    # 安装依赖
    local missing_pkgs=()
    for cmd in "${!pkg_map[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_pkgs+=("${pkg_map[$cmd]}")
        fi
    done
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        log "WARN" "安装缺失的依赖: ${missing_pkgs[*]}"
        if ! sudo apt-get install -y "${missing_pkgs[@]}"; then
            log "ERROR" "依赖安装失败"
            return 1
        fi
    fi

    log "INFO" "环境初始化完成"
    return 0
}

# 下载函数
download_with_retry() {
    local url="$1"
    local output_file="$2"
    local max_retries=3
    local retry_delay=2
    local timeout=30

    if [[ ! "$url" =~ ^https?:// ]]; then
        log "ERROR" "无效的 URL: $url"
        return 1
    fi

    for ((i=1; i<=max_retries; i++)); do
        log "INFO" "下载尝试 $i/$max_retries: $url"

        if wget -q --show-progress --timeout="$timeout" -O "$output_file" "$url"; then
            log "INFO" "下载成功: $output_file"
            return 0
        else
            log "WARN" "下载失败，等待 ${retry_delay} 秒后重试..."
            sleep "$retry_delay"
        fi
    done

    log "ERROR" "下载失败，已达到最大重试次数: $url"
    return 1
}

# 解压函数
extract_archive() {
    local file="$1"
    local extract_dir="$2"

    mkdir -p "$extract_dir" || {
        log "ERROR" "无法创建解压目录: $extract_dir"
        return 1
    }

    local file_type=$(file -b "$file")
    log "DEBUG" "解压文件类型: $file_type"

    case "$file_type" in
        *"Zip archive"*)
            unzip -q "$file" -d "$extract_dir" || {
                log "ERROR" "ZIP解压失败"
                return 1
            }
            ;;
        *"gzip compressed"*)
            tar -xzf "$file" -C "$extract_dir" || {
                log "ERROR" "GZIP解压失败"
                return 1
            }
            ;;
        *"XZ compressed"*)
            tar -xJf "$file" -C "$extract_dir" || {
                log "ERROR" "XZ解压失败"
                return 1
            }
            ;;
        *"RAR archive"*)
            unrar x -o+ "$file" "$extract_dir" >/dev/null || {
                log "ERROR" "RAR解压失败"
                return 1
            }
            ;;
        *"7-zip archive"*)
            7z x "$file" -o"$extract_dir" >/dev/null || {
                log "ERROR" "7Z解压失败"
                return 1
            }
            ;;
        *)
            log "ERROR" "未知文件类型: $file_type"
            return 1
            ;;
    esac

    log "DEBUG" "解压完成: $file -> $extract_dir"
    return 0
}

# 安装单个字体文件
install_font_file() {
    local font_file=$1
    local install_dir=$2
    local base_name=$(basename "$font_file")

    # 检查文件是否已存在
    if fc-list | grep -q "$base_name"; then
        log "INFO" "发现已安装字体: $base_name，将覆盖安装"
        # 移除已存在的字体文件
        find "$install_dir" -name "$base_name" -type f -delete
    fi

    # 安装字体
    if cp "$font_file" "$install_dir/"; then
        log "INFO" "字体: $base_name 安装成功"
        return 0
    else
        log "ERROR" "安装失败: $base_name"
        return 1
    fi
}

# 清理函数
cleanup() {
  local tmp_dir="$1"
  if [[ -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
    log "INFO" "已清理临时目录: $tmp_dir"
  fi
}

# 安装字体主函数
install_fonts() {
    declare -n fonts=$1
    local install_dir="${2:-/usr/share/fonts/truetype}"
    local tmp_dir
    local total_installed=0
    local total_skipped=0
    local total_fonts=${#fonts[@]}

    # 检查数组是否为空
    if [[ ${#fonts[@]} -eq 0 ]]; then
        log "ERROR" "字体数组为空"
        return 1
    fi

    [[ -w "$install_dir" ]] || install_dir="$HOME/.fonts"
    mkdir -p "$install_dir" || { log "ERROR" "无法创建字体目录: $install_dir"; return 1; }

    log "INFO" "开始安装 $total_fonts 个字体..."

    for font_name in "${!fonts[@]}"; do
        # 创建临时目录，并处理错误，在循环内创建，每个字体一个临时目录
        tmp_dir=$(mktemp -d) || { log "ERROR" "无法创建临时目录"; return 1; }
        local download_file="$tmp_dir/${font_name}_download"
        local extract_dir="$tmp_dir/${font_name}"
        mkdir -p "$extract_dir" || continue

        log "INFO" "正在处理: $font_name (${fonts[$font_name]})"

        if ! download_with_retry "${fonts[$font_name]}" "$download_file"; then
            log "ERROR" "字体下载失败: $font_name"
            ((total_skipped++))
            cleanup "$tmp_dir" # 清理当前字体的临时目录
            continue
        fi

        if extract_archive "$download_file" "$extract_dir"; then
            local font_count=0
            while IFS= read -r font_file; do
                if install_font_file "$font_file" "$install_dir"; then
                    ((total_installed++))
                    ((font_count++))
                else
                    ((total_skipped++))
                fi
            done < <(find "$extract_dir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \))
            
            log "INFO" "字体包 $font_name 中安装了 $font_count 个字体"
        else
            log "ERROR" "解压失败: $font_name"
            ((total_skipped++))
            cleanup "$tmp_dir" # 清理当前字体的临时目录
            continue
        fi
        cleanup "$tmp_dir" # 清理当前字体的临时目录
    done

    if ! fc-cache -f; then
        log "ERROR" "更新字体缓存失败"
        return 1
    fi

    log "INFO" "字体安装完成: 总计 $total_fonts 个字体包, 成功安装 $total_installed 个字体文件, 跳过 $total_skipped 个"
    return 0
}

# 主程序

main_fonts() {
    init_environment || exit 1

    # 常用编程nerd字体
    declare -A code_fonts_array
    code_fonts_array["JetBrainsMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz"
    code_fonts_array["CascadiaCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.tar.xz"
    code_fonts_array["FiraCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.tar.xz"
    code_fonts_array["SauceCodePro"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/SourceCodePro.tar.xz"
    code_fonts_array["Meslo"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Meslo.tar.xz" 

    # 思源字体简繁合集
    declare -A chinese_fonts_array
    chinese_fonts_array["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
    chinese_fonts_array["SourceHanSansTW"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansTW.zip"
    chinese_fonts_array["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
    chinese_fonts_array["SourceHanSerifTW"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/15_SourceHanSerifTW.zip"

    echo "请选择要安装的字体类别:"
    echo "1. 编程字体"
    echo "2. 中文字体"
    echo "3. 全部安装"
    read -p "请输入选择 (1-3): " choice

    local install_status=0
    case "$choice" in
        1) install_fonts code_fonts_array || install_status=$? ;;
        2) install_fonts chinese_fonts_array || install_status=$? ;;
        3) 
            install_fonts code_fonts_array || install_status=$?
            install_fonts chinese_fonts_array || install_status=$?
            ;;
        *) 
            log "ERROR" "无效的选择: $choice"
            exit 1
            ;;
    esac

    if [[ $install_status -eq 0 ]]; then
        log "INFO" "字体安装完成"
        echo "字体安装完成，请查看日志文件: $LOG_FILE"
        echo "已安装的字体列表:"

        echo "=== 编程字体 ==="
        if fc-list | grep -iE "JetBrains|Cascadia|FiraCode|SourceCodePro|Meslo" > /dev/null; then
            fc-list | grep -iE "JetBrains|Cascadia|FiraCode|SourceCodePro|Meslo" | while IFS=: read -r file name style; do
                echo "文件: ${file}"
                echo "名称: ${name}"
                echo "---"
            done
        else
            log "WARNING" "未找到任何匹配的编程字体"
        fi

        echo -e "\n=== 思源字体 ==="
        if fc-list | grep -i "SourceHan" > /dev/null; then
            fc-list | grep -i "SourceHan" | while IFS=: read -r file name style; do
                echo "文件: ${file}"
                echo "名称: ${name}"
                echo "---"
            done
        else
            log "WARNING" "未找到任何匹配的思源字体"
        fi

    else
        log "ERROR" "字体安装过程中出现错误 ($install_status)"
        exit $install_status
    fi
}

# 只有直接执行时才调用main，被 source 时不执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_fonts
fi

