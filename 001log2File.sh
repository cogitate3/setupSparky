#!/bin/bash
#
# 改进后的日志脚本：默认日志级别改为 INFO(1)，对应绿色输出

# 使用关联数组管理颜色，统一在脚本Global范围定义
declare -A COLORS=(
    ["reset"]="\033[0m"    # 重置颜色
    ["red"]="\033[31m"     # 红色
    ["green"]="\033[32m"   # 绿色
    ["yellow"]="\033[33m"  # 黄色
    ["blue"]="\033[34m"    # 蓝色
    ["bold"]="\033[1m"     # 粗体
)

# 当前脚本内全局使用的日志文件，若未设置则为空
CURRENT_LOG_FILE=""

##############################################################################
# 设置日志文件的函数：检查文件格式、创建父目录、触摸文件并更新全局 CURRENT_LOG_FILE
##############################################################################
set_log_file() {
    local file_path="$1"
    if [ -n "$file_path" ]; then
        # 检查文件名是否以 .log 结尾
        if [[ "$file_path" != *.log ]]; then
            echo -e "${COLORS["red"]}错误：日志文件名必须以 .log 结尾${COLORS["reset"]}"
            return 1
        fi
        # 确保日志文件所在的目录存在
        local dir_path
        dir_path="$(dirname "$file_path")"
        if [ ! -d "$dir_path" ]; then
            mkdir -p "$dir_path"
        fi

        # 创建空的日志文件（如不存在）
        touch "$file_path" 2>/dev/null || {
            echo -e "${COLORS["red"]}错误：无法创建日志文件：$file_path${COLORS["reset"]}"
            return 1
        }

        # 更新全局变量
        CURRENT_LOG_FILE="$file_path"
        return 0
    fi

    echo -e "${COLORS["red"]}错误：未指定日志文件的路径${COLORS["reset"]}"
    return 1
}

##############################################################################
# 核心日志记录函数：可同时输出到控制台（带颜色）和日志文件（纯文本）。
# 参数（共1~3个，使用灵活）：
#   1) file_path (.log结尾) [可选]
#   2) level (0~3，只在指定时生效) [可选]
#   3) message (必需)
# 若只有一个参数，可能是日志文件或日志级别或消息；脚本会自动判断
##############################################################################
log() {
    # 定义日志级别与对应文本
    declare -A LOG_LEVELS=(
        [0]="DEBUG"   # 调试信息
        [1]="INFO"    # 一般信息
        [2]="WARN"    # 警告信息
        [3]="ERROR"   # 错误信息
    )

    # 定义日志级别对应的颜色
    declare -A LEVEL_COLORS=(
        [0]="reset"   # DEBUG - 默认颜色
        [1]="green"   # INFO - 绿色
        [2]="yellow"  # WARN - 黄色
        [3]="red"     # ERROR - 红色
    )

    # 将默认 level 改为 1 (INFO)，对应绿色
    local file_path=""
    local level=1
    local message=""

    case $# in
        1)
            if [[ "$1" == *.log ]]; then
                # 只有一个参数，且是 .log 结尾 => 文件路径
                file_path="$1"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                # 只有一个参数，且是数字 0-3 => 日志级别
                level="$1"
            else
                # 只有一个参数，既不是 .log 也不是级别 => 日志消息
                message="$1"
            fi
            ;;
        2)
            # 两个参数 => 可能是 (file_path, message) 或 (level, message)
            if [[ "$1" == *.log ]]; then
                file_path="$1"
                message="$2"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                level="$1"
                message="$2"
            else
                echo -e "${COLORS["red"]}错误：第一个参数必须是 .log 文件或日志级别(0~3)${COLORS["reset"]}"
                return 1
            fi
            ;;
        3)
            # 三个参数 => (file_path, level, message)
            file_path="$1"
            if [[ ! "$file_path" == *.log ]]; then
                echo -e "${COLORS["red"]}错误：文件路径必须以 .log 结尾${COLORS["reset"]}"
                return 1
            fi
            if [[ ! "$2" =~ ^[0-3]$ ]]; then
                echo -e "${COLORS["red"]}错误：日志级别必须是0-3的数字${COLORS["reset"]}"
                return 1
            fi
            level="$2"
            message="$3"
            ;;
        *)
            echo -e "${COLORS["red"]}错误：参数数量必须是1-3个${COLORS["reset"]}"
            return 1
            ;;
    esac

    # 如果取得了 file_path，就尝试设置日志文件
    if [ -n "$file_path" ]; then
        set_log_file "$file_path" || return 1
    fi

    # 如果没显式传入 file_path 且全局也没设置过，就报错
    if [ -z "$file_path" ] && [ -z "$CURRENT_LOG_FILE" ]; then
        echo -e "${COLORS["red"]}错误：没有指定日志文件路径${COLORS["reset"]}"
        return 1
    fi

    # 如果没有传入消息，则警告
    if [ -z "$message" ]; then
        echo -e "${COLORS["red"]}错误：日志消息内容不能为空${COLORS["reset"]}"
        return 1
    fi

    # 取最终要写入的文件
    local final_log_file="${CURRENT_LOG_FILE}"

    # 获取当前时间戳
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # 获取日志级别文本和对应颜色
    local level_text="${LOG_LEVELS[$level]}"
    local color="${LEVEL_COLORS[$level]}"

    # 终端输出（带颜色）
    echo -e "[${timestamp}] [${COLORS[$color]}${level_text}${COLORS["reset"]}] ${COLORS[$color]}${message}${COLORS["reset"]}"

    # 文件输出（纯文本）
    echo "[${timestamp}] [${level_text}] ${message}" >> "$final_log_file"
}

##############################################################################
# 如果脚本被直接执行（而非被 source），则演示一些示例用法
##############################################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mkdir -p "/tmp/logs"

    # 1) 仅传一个消息 => 默认使用 level=1 (INFO) => 绿色
    log "这条消息将以绿色输出，并提示没指定日志文件，但不会报错"

    # 2) 设置日志文件 + 输出消息
    log "/tmp/logs/test.log" "这是一条写入 /tmp/logs/test.log 的默认 INFO (绿色) 消息"

    # 3) 使用日志级别 2 (WARN) 输出
    log 2 "这是 WARN 级别 (黄色)"

    # 4) 三参数方式 => 文件 + level + message
    log "/tmp/logs/test2.log" 3 "ERROR 级别 (红色)"

    # 5) 只传文件 + 消息 => 文件 + 默认INFO
    log "/tmp/logs/test3.log" "默认INFO消息 (绿色)"

    # 等等，可以自行扩展更多测试...
fi