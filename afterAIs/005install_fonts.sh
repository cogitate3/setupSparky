#!/bin/bash

# 启用严格模式
set -euo pipefail

# 全局常量定义
readonly VERSION="1.0.0"
readonly CONFIG_FILE="$HOME/.fontinstall.conf"
readonly LOG_FILE="$HOME/font_install.log"
readonly TEMP_DIR="/tmp/font_install_$$"
readonly MAX_PARALLEL=4

# 保存原始 IFS 并设置新的 IFS
OLD_IFS="$IFS"
IFS=$'\n\t'

# 定义退出时的清理操作
trap 'cleanup' EXIT
trap 'error_handler ${LINENO} "${BASH_COMMAND}" $?' ERR
trap 'IFS="$OLD_IFS"' EXIT

# 颜色定义
declare -A COLORS=(
    ["INFO"]="\033[32m"    # 绿色
    ["WARN"]="\033[33m"    # 黄色
    ["ERROR"]="\033[31m"   # 红色
    ["DEBUG"]="\033[36m"   # 青色
    ["RESET"]="\033[0m"    # 重置颜色
)

# 显示帮助信息
show_help() {
    cat << EOF
Font Installer v${VERSION}

使用方法:
    ${0##*/} [选项] <命令>

命令:
    install [type]    安装字体 (type: code|chinese|all)
    list              列出可用字体
    clean             清理临时文件
    version           显示版本信息

选项:
    -h, --help       显示此帮助信息
    -d, --dir DIR    指定安装目录 (默认: $HOME/.fonts)
    -v, --verbose    显示详细输出
    -q, --quiet      静默模式
    -f, --force      强制安装（覆盖已存在的字体）

示例:
    ${0##*/} install code          # 安装编程字体
    ${0##*/} -d /usr/share/fonts install chinese  # 指定目录安装中文字体
    ${0##*/} --verbose install all    # 显示详细信息并安装所有字体

EOF
}

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="${COLORS[$level]:-${COLORS[INFO]}}"

    # 根据详细度级别决定是否输出日志
    if [[ $QUIET -eq 0 ]] || [[ "$level" == "ERROR" ]]; then
        # 输出到终端并写入日志文件
        echo -e "${color}[$level] [$timestamp] $message${COLORS[RESET]}" | tee -a "$LOG_FILE"
    fi

    # 错误消息总是输出到标准错误
    [[ "$level" == "ERROR" ]] && >&2 echo -e "${color}[$level] $message${COLORS[RESET]}"
}

# 错误处理函数
error_handler() {
    local line=$1
    local command=$2
    local code=$3
    log "ERROR" "脚本执行失败 [行 $line]: 命令 '$command' 返回错误码 $code"
    exit $code
}

# 参数解析函数
parse_args() {
    # 默认值设置
    INSTALL_DIR="$HOME/.fonts"
    VERBOSE=0
    QUIET=0
    FORCE=0
    COMMAND=""
    FONT_TYPE=""

    # 解析命名参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            install|list|clean|version)
                COMMAND="$1"
                shift
                # 检查是否有子命令参数
                if [[ "$COMMAND" == "install" && $# -gt 0 ]]; then
                    FONT_TYPE="$1"
                    shift
                fi
                ;;
            *)
                echo "错误：未知参数 '$1'"
                show_help
                exit 1
                ;;
        esac
    done

    # 验证必要参数
    if [[ -z "$COMMAND" ]]; then
        echo "错误：需要指定命令"
        show_help
        exit 1
    fi

    # 验证install命令的字体类型
    if [[ "$COMMAND" == "install" && -z "$FONT_TYPE" ]]; then
        FONT_TYPE="all"  # 默认安装所有字体
    fi

    # 导出全局变量
    export INSTALL_DIR VERBOSE QUIET FORCE COMMAND FONT_TYPE
}

# 初始化环境函数
init_environment() {
    log "INFO" "初始化环境..."

    # 创建必要的目录
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$INSTALL_DIR"

    # 检查并安装依赖
    local dependencies=("wget" "unzip" "tar" "fontconfig")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "WARN" "安装缺失的依赖: ${missing_deps[*]}"
        if ! sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"; then
            log "ERROR" "依赖安装失败"
            return 1
        fi
    fi

    log "INFO" "环境初始化完成"
    return 0
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local progress=$((current * width / total))
    
    if [[ $QUIET -eq 0 ]]; then
        printf "\r[%-${width}s] %d%%" \
               "$(printf '%*s' "$progress" '' | tr ' ' '#')" \
               $((current * 100 / total))
    fi
}

# 下载函数
download_with_retry() {
    local url="$1"
    local output_file="$2"
    local max_retries=3
    local retry_delay=2

    for ((i=1; i<=max_retries; i++)); do
        [[ $VERBOSE -eq 1 ]] && log "INFO" "下载尝试 $i/$max_retries: $url"
        
        if wget -q --show-progress --timeout=30 -O "$output_file" "$url"; then
            [[ $VERBOSE -eq 1 ]] && log "INFO" "下载成功: $output_file"
            return 0
        else
            log "WARN" "下载失败，等待 ${retry_delay} 秒后重试..."
            sleep "$retry_delay"
        fi
    done

    log "ERROR" "下载失败，已达到最大重试次数: $url"
    return 1
}

# 解压文件函数
extract_archive() {
    local file="$1"
    local target_dir="$2"

    mkdir -p "$target_dir" || {
        log "ERROR" "无法创建解压目标目录: $target_dir"
        return 1
    }

    local file_type=$(file -b --mime-type "$file")
    log "DEBUG" "文件类型: $file_type"

    case "$file_type" in
        application/zip)
            unzip -q "$file" -d "$target_dir" ;;
        application/x-tar)
            tar -xf "$file" -C "$target_dir" ;;
        application/x-xz)
            tar -xJf "$file" -C "$target_dir" ;;
        application/x-rar)
            unrar x -o+ "$file" "$target_dir" >/dev/null ;;
        application/x-7z-compressed)
            7z x "$file" -o"$target_dir" >/dev/null ;;
        *)
            log "ERROR" "不支持的文件类型: $file_type"
            return 1 ;;
    esac

    log "INFO" "解压完成: $file -> $target_dir"
    return 0
}

# 获取字体列表
get_font_list() {
    local type="$1"
    declare -A fonts

    case "$type" in
        code)
            fonts["JetBrainsMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz"
            fonts["CascadiaCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.tar.xz"
            ;;
        chinese)
            fonts["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
            fonts["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
            ;;
        all)
            get_font_list "code"
            get_font_list "chinese"
            ;;
        *)
            log "ERROR" "未知的字体类型: $type"
            return 1
            ;;
    esac

    for name in "${!fonts[@]}"; do
        echo "$name ${fonts[$name]}"
    done
}

# 安装字体函数
install_font() {
    local file="$1"
    local name="$(basename "$file")"

    if [[ -f "$INSTALL_DIR/$name" && $FORCE -eq 0 ]]; then
        [[ $VERBOSE -eq 1 ]] && log "INFO" "字体已存在，跳过: $name"
        return 0
    fi

    if cp "$file" "$INSTALL_DIR/"; then
        [[ $VERBOSE -eq 1 ]] && log "INFO" "安装成功: $name"
        return 0
    else
        log "ERROR" "安装失败: $name"
        return 1
    fi
}

# 主安装流程
main_install() {
    local type="$FONT_TYPE"
    
    log "INFO" "开始安装 $type 类型的字体到 $INSTALL_DIR"

    # 创建临时下载目录
    local download_dir="$TEMP_DIR/downloads"
    mkdir -p "$download_dir"

    # 获取字体列表并下载
    local font_list=($(get_font_list "$type"))
    local total=${#font_list[@]}
    local current=0

    for font_info in "${font_list[@]}"; do
        local name=${font_info%% *}
        local url=${font_info#* }
        local download_file="$download_dir/$name"

        if download_with_retry "$url" "$download_file"; then
            if extract_archive "$download_file" "$TEMP_DIR/$name"; then
                find "$TEMP_DIR/$name" -type f \( -name "*.ttf" -o -name "*.otf" \) \
                    -exec install_font {} \;
            fi
        fi

        show_progress "$((++current))" "$total"
    done

    echo # 换行

    # 更新字体缓存
    log "INFO" "更新字体缓存..."
    fc-cache -f "$INSTALL_DIR"
    log "INFO" "字体安装完成"
}

# 清理函数
cleanup() {
    [[ $VERBOSE -eq 1 ]] && log "DEBUG" "清理临时文件..."
    rm -rf "$TEMP_DIR"
}

# 列出字体函数
list_fonts() {
    echo "可用的字体列表："
    echo "编程字体："
    get_font_list "code" | sed 's/^/  - /'
    echo "中文字体："
    get_font_list "chinese" | sed 's/^/  - /'
}

# 主函数
main() {
    parse_args "$@"
    
    case "$COMMAND" in
        install)
            init_environment && main_install
            ;;
        list)
            list_fonts
            ;;
        clean)
            cleanup
            ;;
        version)
            echo "Font Installer v$VERSION"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 执行主程序
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"