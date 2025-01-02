#!/bin/bash

# 保留第二段代码的基础设置
set -euo pipefail

# 全局常量定义（保留第二段的定义）
readonly VERSION="1.0.0"
readonly CONFIG_FILE="$HOME/.fontinstall.conf"
readonly LOG_FILE="$HOME/font_install.log"
readonly TEMP_DIR=$(mktemp -d /tmp/font_install_XXXXXX)
readonly MAX_PARALLEL=4

# 保留第二段代码的错误处理和颜色定义
[...]

# 修改 get_font_list 函数，整合第一段代码的字体分类
get_font_list() {
    local type="$1"
    declare -A fonts
    
    case "$type" in
        popular)
            fonts=(
                ["JetBrainsMono"]="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
                ["CascadiaCode"]="https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
                # ... 其他 popular_code_fonts 的内容
            )
            ;;
        monospace)
            fonts=(
                # ... monospace_code_fonts 的内容
            )
            ;;
        modern)
            fonts=(
                # ... modern_style_fonts 的内容
            )
            ;;
        chinese)
            fonts=(
                ["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
                ["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
                # ... 其他 chinese_fonts 的内容
            )
            ;;
        source)
            fonts=(
                # ... source_fonts 的内容
            )
            ;;
        special)
            fonts=(
                # ... special_fonts 的内容
            )
            ;;
        all)
            # 合并所有类别的字体
            for category in popular monospace modern chinese source special; do
                declare -A temp_fonts
                temp_fonts=($(get_font_list "$category"))
                fonts+=("${temp_fonts[@]}")
            done
            ;;
        *)
            log "ERROR" "未知的字体类别: $type"
            return 1
            ;;
    esac

    # 输出字体列表
    for name in "${!fonts[@]}"; do
        echo "$name=${fonts[$name]}"
    done
}

# 修改帮助信息，增加新的字体类别
show_help() {
    cat << EOF
Font Installer v${VERSION}

使用方法:
    ${0##*/} [选项] <命令>

命令:
    install [category]  安装字体，可选类别:
                       - popular   (流行的编程字体)
                       - monospace (等宽编程字体)
                       - modern    (现代风格字体)
                       - chinese   (中文字体)
                       - source    (Source系列字体)
                       - special   (特殊用途字体)
                       - all       (所有字体)
    uninstall [category] 卸载字体，类别同上
    list               列出可用字体
    clean              清理临时文件
    version           显示版本信息

选项:
    -h, --help       显示此帮助信息
    -d, --dir DIR    指定安装目录 (默认: $HOME/.fonts)
    -v, --verbose    显示详细输出
    -q, --quiet      静默模式
    -f, --force      强制安装（覆盖已存在的字体）

示例:
    ${0##*/} install popular        # 安装流行的编程字体
    ${0##*/} -d /usr/share/fonts install chinese  # 安装中文字体
    ${0##*/} --verbose install all    # 安装所有字体

EOF
}
#!/bin/bash

###################
# 基础设置
###################
set -euo pipefail

# 全局常量定义
readonly VERSION="1.0.0"
readonly CONFIG_FILE="$HOME/.fontinstall.conf"
readonly LOG_FILE="$HOME/font_install.log"
readonly TEMP_DIR=$(mktemp -d /tmp/font_install_XXXXXX)
readonly MAX_PARALLEL=4
readonly FONT_DIR="$HOME/.local/share/fonts"

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

###################
# 字体分类定义
###################
declare -A popular_code_fonts=(
    ["JetBrainsMono"]="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
    ["CascadiaCode"]="https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
    ["FiraCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.tar.xz"
    ["SourceCodePro"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/SourceCodePro.tar.xz"
    ["monaspace"]="https://github.com/githubnext/monaspace/releases/download/v1.101/monaspace-v1.101.zip"
    ["Hack"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.tar.xz"
)

declare -A monospace_code_fonts=(
    ["Inconsolata"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Inconsolata.tar.xz"
    ["DroidSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/DroidSansMono.tar.xz"
    ["UbuntuMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/UbuntuMono.tar.xz"
    ["DejaVuSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/DejaVuSansMono.tar.xz"
)

declare -A chinese_fonts=(
    ["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
    ["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
    ["SourceHanMono"]="https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc"
)

declare -A modern_style_fonts=(
    ["CommitMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CommitMono.tar.xz"
    ["Lilex"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Lilex.tar.xz"
    ["MartianMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/MartianMono.tar.xz"
)

declare -A source_fonts=(
    ["SourceCodePro-Regular.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Regular.otf"
    ["SourceCodePro-Bold.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Bold.otf"
    ["SourceSans3-Regular.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Regular.otf"
)

declare -A special_fonts=(
    ["OpenDyslexic"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/OpenDyslexic.tar.xz"
    ["HeavyData"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/HeavyData.tar.xz"
    ["Gohu"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Gohu.tar.xz"
)

# 字体类别映射
declare -A font_categories=(
    ["popular"]="popular_code_fonts"
    ["monospace"]="monospace_code_fonts"
    ["modern"]="modern_style_fonts"
    ["chinese"]="chinese_fonts"
    ["source"]="source_fonts"
    ["special"]="special_fonts"
)

###################
# 工具函数
###################

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="${COLORS[$level]:-${COLORS[INFO]}}"

    if [[ $QUIET -eq 0 ]] || [[ "$level" == "ERROR" ]]; then
        echo -e "${color}[$level] [$timestamp] $message${COLORS[RESET]}" | tee -a "$LOG_FILE"
    fi

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

# 清理函数
cleanup() {
    log "DEBUG" "清理临时文件..."
    rm -rf "$TEMP_DIR"
    [[ $VERBOSE -eq 1 ]] && log "DEBUG" "临时目录已删除: $TEMP_DIR"
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 检查依赖
check_dependencies() {
    local dependencies=("wget" "unzip" "tar" "fontconfig" "p7zip-full")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! check_command "$dep"; then
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
    
    return 0
}

# 初始化环境
init_environment() {
    log "INFO" "初始化环境..."

    mkdir -p "$FONT_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    if ! check_dependencies; then
        log "ERROR" "环境初始化失败"
        return 1
    fi

    log "INFO" "环境初始化完成"
    return 0
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local progress=$((current * width / total))
    
    if [[ $QUIET -eq 0 ]]; then
        printf "\r[%-${width}s] %d%%" \
               "$(printf '%*s' "$progress" '' | tr ' ' '#')" \
               $((current * 100 / total))
        [[ $current -eq $total ]] && echo
    fi
}

# 获取字体列表
get_font_list() {
    local type="$1"
    local array_name="${font_categories[$type]:-}"
    
    if [[ -z "$array_name" && "$type" != "all" ]]; then
        log "ERROR" "未知的字体类别: $type"
        return 1
    }

    if [[ "$type" == "all" ]]; then
        for category in "${!font_categories[@]}"; do
            get_font_list "$category"
        done
        return 0
    fi

    declare -n font_array="$array_name"
    for name in "${!font_array[@]}"; do
        echo "$name=${font_array[$name]}"
    done
}

# 参数解析
parse_args() {
    INSTALL_DIR="$FONT_DIR"
    VERBOSE=0
    QUIET=0
    FORCE=0
    COMMAND=""
    FONT_TYPE=""

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
            install|uninstall|list|clean|version)
                COMMAND="$1"
                shift
                if [[ "$COMMAND" == "install" || "$COMMAND" == "uninstall" ]] && [[ $# -gt 0 ]]; then
                    FONT_TYPE="$1"
                    shift
                fi
                ;;
            *)
                log "ERROR" "未知参数: '$1'"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$COMMAND" ]]; then
        log "ERROR" "需要指定命令"
        show_help
        exit 1
    fi

    if [[ "$COMMAND" == "install" || "$COMMAND" == "uninstall" ]] && [[ -z "$FONT_TYPE" ]]; then
        FONT_TYPE="all"
    fi

    export INSTALL_DIR VERBOSE QUIET FORCE COMMAND FONT_TYPE
}
###################
# 下载和安装函数
###################

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

# 解压文件
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
        application/x-tar|application/x-gtar)
            tar -xf "$file" -C "$target_dir" ;;
        application/x-xz)
            tar -xJf "$file" -C "$target_dir" ;;
        application/x-7z-compressed)
            7z x "$file" -o"$target_dir" >/dev/null ;;
        application/x-font-ttf|application/x-font-otf|application/octet-stream)
            cp "$file" "$target_dir/" ;;
        *)
            log "ERROR" "不支持的文件类型: $file_type"
            return 1 ;;
    esac

    log "INFO" "解压完成: $file -> $target_dir"
    return 0
}

# 安装单个字体文件
install_font() {
    local file="$1"
    local name=$(basename "$file")

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

# 更新字体缓存
update_font_cache() {
    log "INFO" "更新字体缓存..."
    if fc-cache -f "$INSTALL_DIR"; then
        log "INFO" "字体缓存更新完成"
        return 0
    else
        log "ERROR" "字体缓存更新失败"
        return 1
    fi
}

# 安装指定类别的字体
install_category() {
    local type="$1"
    log "INFO" "开始安装 $type 类型的字体"

    local download_dir="$TEMP_DIR/downloads"
    mkdir -p "$download_dir"

    local font_list=($(get_font_list "$type"))
    local total=${#font_list[@]}
    local current=0
    local success_count=0

    for font_info in "${font_list[@]}"; do
        local name=${font_info%%=*}
        local url=${font_info#*=}
        local download_file="$download_dir/${name}_$(basename "$url")"

        if download_with_retry "$url" "$download_file"; then
            if extract_archive "$download_file" "$TEMP_DIR/$name"; then
                local font_files=("$TEMP_DIR/$name"/*.{ttf,otf,ttc})
                if (( ${#font_files[@]} )); then
                    for file in "${font_files[@]}"; do
                        [[ -f "$file" ]] && install_font "$file" && ((success_count++))
                    done
                else
                    log "WARN" "未找到字体文件: $name"
                fi
            else
                log "ERROR" "解压失败: $name"
            fi
            rm -rf "$TEMP_DIR/$name"
        fi
        ((current++))
        show_progress "$current" "$total"
    done

    log "INFO" "字体安装完成: $success_count 个成功"
    return $((total - success_count))
}

# 添加卸载函数
uninstall_fonts() {
    local type="$1"
    local font_dir="$INSTALL_DIR"
    local count=0
    local removed=0
    
    log "INFO" "开始卸载 $type 类型的字体..."

    # 获取要卸载的字体列表
    local font_list=($(get_font_list "$type"))
    
    # 如果是卸载所有字体，直接清空目录
    if [[ "$type" == "all" ]]; then
        if [[ $FORCE -eq 1 ]] || confirm_action "确定要卸载所有字体吗？"; then
            local total=$(find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) | wc -l)
            rm -rf "$font_dir"/*
            log "INFO" "已删除所有字体文件: $total 个"
            update_font_cache
            return 0
        else
            log "INFO" "操作已取消"
            return 1
        fi
    fi

    # 对每个字体进行卸载
    for font_info in "${font_list[@]}"; do
        local name=${font_info%%=*}
        local url=${font_info#*=}
        local base_name=$(basename "$url")
        ((count++))

        # 查找匹配的字体文件
        local files=($(find "$font_dir" -type f \( -name "${name}*.ttf" -o -name "${name}*.otf" -o -name "${name}*.ttc" \)))
        
        if [[ ${#files[@]} -eq 0 ]]; then
            [[ $VERBOSE -eq 1 ]] && log "DEBUG" "未找到字体文件: $name"
            continue
        fi

        for file in "${files[@]}"; do
            if [[ -f "$file" ]]; then
                if [[ $FORCE -eq 1 ]] || confirm_action "是否删除字体文件: $(basename "$file")？"; then
                    if rm -f "$file"; then
                        ((removed++))
                        [[ $VERBOSE -eq 1 ]] && log "INFO" "已删除: $(basename "$file")"
                    else
                        log "ERROR" "删除失败: $(basename "$file")"
                    fi
                fi
            fi
        done
        
        show_progress "$count" "${#font_list[@]}"
    done

    log "INFO" "字体卸载完成: 删除了 $removed 个文件"
    
    if [[ $removed -gt 0 ]]; then
        update_font_cache
    fi

    return 0
}

# 添加确认操作函数
confirm_action() {
    local prompt="$1"
    local answer
    
    if [[ $FORCE -eq 1 ]]; then
        return 0
    fi

    if [[ $QUIET -eq 1 ]]; then
        return 1
    fi

    while true; do
        read -r -p "$prompt [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO]|"")
                return 1
                ;;
            *)
                echo "请输入 yes 或 no"
                ;;
        esac
    done
}

###################
# 主程序
###################
main() {
    parse_args "$@"

    case "$COMMAND" in
        version)
            echo "Font Installer v${VERSION}"
            ;;
        list)
            log "INFO" "可用的字体类别:"
            for category in "${!font_categories[@]}"; do
                echo "- $category"
                if [[ $VERBOSE -eq 1 ]]; then
                    get_font_list "$category" | sed 's/=.*//' | sed 's/^/  * /'
                fi
            done
            ;;
        clean)
            cleanup
            log "INFO" "清理完成"
            ;;
        install)
            if ! init_environment; then
                exit 1
            fi

            if [[ "$FONT_TYPE" == "all" ]]; then
                for category in "${!font_categories[@]}"; do
                    install_category "$category"
                done
            else
                install_category "$FONT_TYPE"
            fi

            update_font_cache
            ;;
        uninstall)
            if ! init_environment; then
                exit 1
            fi

            if [[ "$FONT_TYPE" == "all" ]]; then
                uninstall_fonts "all"
            else
                uninstall_fonts "$FONT_TYPE"
            fi
            ;;
        *)
            log "ERROR" "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 如果脚本被直接执行而不是被源引用，则运行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    else
        main "$@"
    fi
fi