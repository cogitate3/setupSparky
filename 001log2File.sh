#!/bin/bash

# 这个脚本创建了一个灵活的日志记录系统，可以将日志输出到文件和控制台

# fonts color,简单快速输出颜色字
# Usage:red "字母"
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}

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
    local level=1       # 日志级别（0-3），默认为DEBUG(0)
    local message=''    # 日志消息内容

    # 根据传入的参数数量解析参数
    case $# in
        1)  # 一个参数：可能是 (文件路径) 或 (日志级别) 或 (消息)
            if [[ "$1" == *.log ]]; then
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
            if [[ "$1" == *.log ]]; then
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
            if [[ ! "$1" == *.log ]]; then
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
    mkdir -p "/tmp/logs"

    # 演示各种日志记录方式
    log "/tmp/logs/test.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息
    log "这是一条默认消息（DEBUG，默认颜色）"                         # 最简单的用法
    log 1 "这是一条INFO消息（绿色）"                             # 指定日志级别
    log 2 "这是一条WARN消息（黄色）"                                  # 警告消息（黄色）
    log 3 "这是一条ERROR消息（红色）"                                # 错误消息（红色）
    log "/tmp/logs/test2.log" 1 "这是一条INFO消息（新文件）"   # 切换文件并记录INFO消息
    log "/tmp/logs/test2.log" 2 "这是一条WARN消息（新文件）"  # 切换文件并记录WARN消息
    log "/tmp/logs/test2.log" 3 "这是一条ERROR消息（新文件）" # 切换文件并记录ERROR消息

    # 测试不同日志级别
    log "/tmp/logs/test.log" 0 "This is a DEBUG message"
    log "/tmp/logs/test.log" 1 "This is an INFO message"
    log "/tmp/logs/test.log" 2 "This is a WARN message"
    log "/tmp/logs/test.log" 3 "This is an ERROR message"

    # 测试文件扩展名验证
    log "/tmp/logs/test.txt" "这个应该失败，因为不是.log文件"
    log "/tmp/logs/test3.log" "这个应该成功，因为是.log文件"

    # 测试不同日志级别
    log "/tmp/logs/test3.log" 0 "这是DEBUG消息"
    log "/tmp/logs/test3.log" 1 "这是INFO消息"
    log "/tmp/logs/test3.log" 2 "这是WARN消息"
    log "/tmp/logs/test3.log" 3 "这是ERROR消息"
    log "pi等于3.1415926535897932384626433832795"
fi

