#!/bin/bash

# 日志系统 - 支持多级别日志记录，输出到控制台（带颜色）和文件（无颜色）

# 定义颜色输出函数
red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[34m\033[01m$1\033[0m"; }
bold() { echo -e "\033[1m\033[01m$1\033[0m"; }

# 默认日志文件路径
DEFAULT_LOG_FILE="/tmp/logs/default.log"

# 控制台输出开关（默认开启）
CONSOLE_OUTPUT=true

# 设置日志文件路径
set_log_file() {
    local file_path="$1"
    if [[ -z "$file_path" ]]; then
        echo "$(red '错误：必须指定日志文件路径')"
        return 1
    fi
    # 检查文件后缀是否为.log
    if [[ "$file_path" != *.log ]]; then
        echo "$(red '错误：日志文件名必须以.log结尾')"
        return 1
    fi
    # 确保日志目录存在
    local dir_path
    dir_path=$(dirname "$file_path")
    mkdir -p "$dir_path"
    touch "$file_path"
    CURRENT_LOG_FILE="$file_path"
}

# 统一错误输出函数
log_error() {
    echo -e "$(red "错误：$1")"
}

# 日志记录函数
# 参数说明：
# 1. log [<文件路径>] [<日志级别>] <消息>
#    - <文件路径>（可选）：日志文件路径，必须以 .log 结尾。如果未提供，则使用默认路径。
#    - <日志级别>（可选）：日志级别，必须是 0（DEBUG）、1（INFO）、2（WARN）、3（ERROR）之一，默认为 1（INFO）。
#    - <消息>：日志内容，必须提供。
# 2. 参数数量要求：
#    - 1 个参数：表示日志内容，使用默认日志文件路径和默认级别（INFO）。
#    - 2 个参数：可以是（日志级别, 消息）或（日志文件路径, 消息）。
#    - 3 个参数：必须是（日志文件路径, 日志级别, 消息）。
log() {
    # 定义日志级别和颜色
    declare -A LOG_LEVELS=(
        [0]="DEBUG"
        [1]="INFO"
        [2]="WARN"
        [3]="ERROR"
    )
    declare -A COLORS=(
        [0]="\\033[0m"    # 默认颜色
        [1]="\\033[32m"   # 绿色
        [2]="\\033[33m"   # 黄色
        [3]="\\033[31m"   # 红色
    )

    # 参数解析
    local file_path=""
    local level=1
    local message=""
    
    case $# in
        1)
            message="$1"
            ;;
        2)
            if [[ "$1" =~ ^[0-3]$ ]]; then
                level="$1"
                message="$2"
            else
                log_error "日志级别无效（应为0-3）或参数格式错误"
                echo "正确用法: log <日志级别> <消息> 或 log <日志文件路径> <消息>"
                return 1
            fi
            ;;
        3)
            file_path="$1"
            if [[ ! "$file_path" == *.log ]]; then
                log_error "日志文件名必须以.log结尾"
                echo "正确用法: log <日志文件路径> <日志级别> <消息>"
                return 1
            fi
            if [[ ! "$2" =~ ^[0-3]$ ]]; then
                log_error "日志级别无效（应为0-3）"
                echo "正确用法: log <日志文件路径> <日志级别> <消息>"
                return 1
            fi
            level="$2"
            message="$3"
            ;;
        *)
            log_error "参数数量错误（应为1-3个）"
            echo "正确用法: log [<日志文件路径>] [<日志级别>] <消息>"
            return 1
            ;;
    esac

    # 设置日志文件路径
    if [ -n "$file_path" ]; then
        set_log_file "$file_path"
    elif [ -z "$CURRENT_LOG_FILE" ]; then
        set_log_file "$DEFAULT_LOG_FILE"
    fi
    
    # 确保日志消息不为空
    if [ -z "$message" ]; then
        log_error "日志消息不能为空"
        echo "正确用法: log [<日志文件路径>] [<日志级别>] <消息>"
        return 1
    fi

    # 获取时间戳和日志级别
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_text="${LOG_LEVELS[$level]}"
    local color="${COLORS[$level]}"

    # 输出到控制台（带颜色）
    if $CONSOLE_OUTPUT; then
        echo -e "${color}[$timestamp] [$level_text] $message\\033[0m"
    fi

    # 写入日志文件（纯文本）
    echo "[$timestamp] [$level_text] $message" >> "$CURRENT_LOG_FILE"
}

# 示例
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mkdir -p "/tmp/logs"

    # 设置日志文件并记录日志
    log "/tmp/logs/example.log" 0 "这是第一次测试"
    log 1 "这是INFO级别的日志"
    log 2 "这是WARN级别的日志"
    log 3 "这是ERROR级别的日志"

    # 测试默认日志文件
    log "没有指定日志文件路径时，使用默认路径"

    # 测试关闭控制台输出
    CONSOLE_OUTPUT=false
    log 1 "这条日志不会显示在控制台"
fi