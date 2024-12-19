#!/bin/bash

# 这个脚本创建了一个灵活的日志记录系统，可以将日志输出到文件和控制台
# This script creates a flexible logging system that can output logs to both file and console

set_log_file() {
    local file_path="$1"
    if [ -n "$file_path" ]; then  # 检查是否提供了文件路径
        # 检查文件名是否以.log结尾
        if [[ "$file_path" != *.log ]]; then
            echo -e "${red}错误：log文件名必须以.log结尾${nc}"
            return 1
        fi

        # 确保日志文件所在的目录存在 
        local dir_path=$(dirname "$file_path")
        if [ ! -d "$dir_path" ]; then
            mkdir -p "$dir_path"
        fi
        touch "$file_path"
        CURRENT_LOG_FILE="$file_path"
        return 0
    fi
    return 1
}

log() {
    # 定义颜色代码的关联数组，用于控制台输出的颜色
    declare -A COLORS=(
        ["nocolour"]="\\033[0m"    # 重置颜色
        ["green"]="\\033[32m"      # 绿色
        ["yellow"]="\\033[33m"     # 黄色
        ["red"]="\\033[31m"        # 红色
    )

    # 定义日志级别的关联数组
    declare -A LOG_LEVELS=(
        [0]="DEBUG"  # 调试信息
        [1]="INFO"   # 一般信息
        [2]="WARN"   # 警告信息
        [3]="ERROR"  # 错误信息
    )

    # 定义日志级别对应的颜色
    declare -A LEVEL_COLORS=(
        [0]="nocolour"  # DEBUG - 默认颜色
        [1]="green"     # INFO - 绿色
        [2]="yellow"    # WARN - 黄色
        [3]="red"       # ERROR - 红色
    )

    # 存储当前日志文件的路径
    CURRENT_LOG_FILE=${file_path}

    # 初始化局部变量
    CURRENT_LOG_FILE=${file_path} # 日志文件路径
    local level=0       # 日志级别（0-3），默认为DEBUG(0)
    local message=''    # 日志消息内容

    # 根据传入的参数数量解析参数
    case $# in
        1)  # 一个参数：可能是 (文件路径) 或 (日志级别) 或 (消息)
            if [[ "$1" =~ \.log$ ]]; then
                # 以.log结尾，判断为文件路径
                file_path="$1"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                # 是0-3的数字，判断为日志级别
                level="$1"
            else
                # 都不是，判断为消息
                message="$1"
            fi
            ;;
        2)  # 两个参数：可能是 (文件路径,消息) 或 (日志级别,消息)
            if [[ "$1" =~ \.log$ ]]; then
                # 第一个参数以.log结尾，判断为文件路径
                file_path="$1"
                message="$2"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                # 第一个参数是0-3的数字，判断为日志级别
                level="$1"
                message="$2"
            else
                # 参数格式错误
                echo -e "${COLORS[red]}错误：第一个参数必须是日志文件路径（.log结尾）或日志级别（0-3）${COLORS[nocolour]}"
                return 1
            fi
            ;;
        3)  # 三个参数：(文件路径,日志级别,消息)
            file_path="$1"
            if [[ ! "$1" =~ \.log$ ]]; then
                echo -e "${COLORS[red]}错误：文件路径必须以.log结尾${COLORS[nocolour]}"
                return 1
            fi
            if [[ ! "$2" =~ ^[0-3]$ ]]; then
                echo -e "${COLORS[red]}错误：日志级别必须是0-3的数字${COLORS[nocolour]}"
                return 1
            fi
            level="$2"
            message="$3"
            ;;
        *)  # 参数数量错误
            echo -e "${COLORS[red]}错误：参数数量必须是1-3个${COLORS[nocolour]}"
            return 1
            ;;
    esac

    # 如果提供了文件路径，则设置日志文件
    if [ -n "$file_path" ]; then
        set_log_file "$file_path"
    elif set_log_file "$CURRENT_LOG_FILE"; then
        echo -e "${COLORS[red]}错误：必须提供日志文件路径${COLORS[nocolour]}"
        return 1
    fi

    # 如果没有消息内容，则返回错误
    if [ -z "$message" ]; then
        echo -e "${COLORS[red]}错误：必须提供日志消息内容${COLORS[nocolour]}"
        return 1
    fi

    # 获取当前时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 获取日志级别文本
    local level_text="${LOG_LEVELS[$level]}"

    # 获取颜色代码
    local color="${LEVEL_COLORS[$level]}"
    local color_code="${COLORS[$color]}"
    local nc="${COLORS[nocolour]}"

    # 输出到控制台（带颜色）
    echo -e "[$timestamp] [$color_code$level_text$nc] $color_code$message$nc"
    
    # 写入日志文件（纯文本，不带颜色）
    if [ -n "$file_path" ]; then
        echo "[$timestamp] [$level_text] $message" >> "$file_path"
    fi
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 创建日志目录
    mkdir -p "./logs"

    # 演示各种日志记录方式
    log "./logs/test.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息
    log "这是一条默认消息（DEBUG，默认颜色）"                         # 最简单的用法
    log 1 "这是一条INFO消息（绿色）"                             # 指定日志级别
    log 2 "这是一条WARN消息（黄色）"                                  # 警告消息（黄色）
    log 3 "这是一条ERROR消息（红色）"                                # 错误消息（红色）
    log "./logs/test2.log" 1 "这是一条INFO消息（新文件）"   # 切换文件并记录INFO消息
    log "./logs/test2.log" 2 "这是一条WARN消息（新文件）"  # 切换文件并记录WARN消息
    log "./logs/test2.log" 3 "这是一条ERROR消息（新文件）" # 切换文件并记录ERROR消息

    # 测试不同日志级别
    log "./logs/test.log" 0 "This is a DEBUG message"
    log "./logs/test.log" 1 "This is an INFO message"
    log "./logs/test.log" 2 "This is a WARN message"
    log "./logs/test.log" 3 "This is an ERROR message"

    # 测试文件扩展名验证
    log "./logs/test.txt" "这个应该失败，因为不是.log文件"
    log "./logs/test3.log" "这个应该成功，因为是.log文件"

    # 测试不同日志级别
    log "./logs/test3.log" 0 "这是DEBUG消息"
    log "./logs/test3.log" 1 "这是INFO消息"
    log "./logs/test3.log" 2 "这是WARN消息"
    log "./logs/test3.log" 3 "这是ERROR消息"
    log "pi等于3.1415926535897932384626433832795"
fi

# ---another Custom Logger
LOG_FILE="/tmp/ab-dm-installer.log"
logger1() {
  # 获取当前的日期和时间，并将其格式化为"年/月/日 时:分:秒"的形式
  timestamp=$(date +"%Y/%m/%d %H:%M:%S") 
  # 将命令放在小括号中会在一个子 shell 中执行这些命令。
  #这意味着在括号内的变量修改不会影响到外部的 shell。

  # 检查传入的第一个参数是否为"error"
  if [[ "$1" == "error" ]]; then
    # 如果是"error"，则用红色显示错误信息
    # 在控制台输出错误信息，并附加到日志文件中
    # shellcheck disable=SC2145
    echo -e "${timestamp} -- "$0" [Error]: \033[0;31m$@\033[0m" | tee -a ${LOG_FILE}
  else
    # $0表示当前脚本的文件名
    # 如果不是"error"，则用默认颜色显示信息
    # 在控制台输出信息，并附加到日志文件中
    # shellcheck disable=SC2145
    echo -e "${timestamp} -- "$0" [Info]: $@" | tee -a ${LOG_FILE}
  fi
}

# ---再来一个日志记录函数

logger2() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 根据日志级别过滤
    case $LOG_LEVEL in
        "DEBUG") log_priority=0 ;;
        "INFO")  log_priority=1 ;;
        "WARN")  log_priority=2 ;;
        "ERROR") log_priority=3 ;;
    esac
    
    case $level in
        "DEBUG") current_priority=0 ;;
        "INFO")  current_priority=1 ;;
        "WARN")  current_priority=2 ;;
        "ERROR") current_priority=3 ;;
        *)       current_priority=1 ;;
    esac
    
    # 只记录优先级大于等于设置的日志级别的消息
    if [ $current_priority -ge $log_priority ]; then
        # 同时输出到控制台和日志文件
        echo "[$timestamp] [$level] $message"
        echo "[$timestamp] [$level] $message" | sudo tee -a $LOG_FILE > /dev/null
    fi
}

# 初始化日志文件
init_log() {
    # 创建日志文件（如果不存在）
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi
    logger2 "INFO" "=== afterLinuxInstall 安装脚本开始执行 ==="
    logger2 "INFO" "系统信息: $(uname -a)"
}