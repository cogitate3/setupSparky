#!/bin/bash

# 将此文件保存为 log.sh

# 颜色定义
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_NC='\033[0m'

# 配置文件路径
LOG_CONFIG_FILE="$HOME/.log_config"

# 函数：获取当前时间
_log_get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# 函数：检查并创建日志目录
_log_check_path() {
    local log_path="$1"
    local log_dir=$(dirname "$log_path")
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${LOG_RED}错误: 无法创建日志目录 $log_dir${LOG_NC}" >&2
            return 1
        fi
    fi
    
    if [ ! -w "$log_dir" ]; then
        echo -e "${LOG_RED}错误: 没有日志目录的写入权限 $log_dir${LOG_NC}" >&2
        return 1
    fi
    
    if [ -f "$log_path" ] && [ ! -w "$log_path" ]; then
        echo -e "${LOG_RED}错误: 没有日志文件的写入权限 $log_path${LOG_NC}" >&2
        return 1
    fi
    
    return 0
}

# 函数：保存日志路径
_log_save_path() {
    echo "$1" > "$LOG_CONFIG_FILE"
}

# 函数：获取保存的日志路径
_log_get_saved_path() {
    if [ -f "$LOG_CONFIG_FILE" ]; then
        cat "$LOG_CONFIG_FILE"
    else
        echo ""
    fi
}

# 主日志函数
log() {
    local log_path=""
    local level=1
    local message=""
    
    # 参数解析
    case $# in
        1)  # 只有消息
            log_path=$(_log_get_saved_path)
            if [ -z "$log_path" ]; then
                echo -e "${LOG_RED}错误: 未设置日志路径${LOG_NC}" >&2
                return 1
            fi
            message="$1"
            ;;
        2)  # 路径+消息 或者 级别+消息
            if [[ "$1" =~ ^[1-4]$ ]]; then
                log_path=$(_log_get_saved_path)
                if [ -z "$log_path" ]; then
                    echo -e "${LOG_RED}错误: 未设置日志路径${LOG_NC}" >&2
                    return 1
                fi
                level="$1"
                message="$2"
            else
                log_path="$1"
                message="$2"
                _log_save_path "$log_path"
            fi
            ;;
        3)  # 完整参数
            log_path="$1"
            level="$2"
            message="$3"
            _log_save_path "$log_path"
            ;;
        *)  
            echo -e "${LOG_RED}使用方法: log [log_path] [level] message${LOG_NC}" >&2
            echo "level: 1=INFO(默认) 2=IMPORTANT 3=WARN 4=ERROR" >&2
            return 1
            ;;
    esac
    
    # 检查日志路径
    _log_check_path "$log_path" || return 1
    
    # 获取时间戳
    local timestamp=$(_log_get_timestamp)
    local level_str=""
    local color=""
    
    # 设置日志级别和颜色
    case $level in
        1|"") 
            level_str="INFO"
            color=$LOG_GREEN
            ;;
        2)  
            level_str="IMPORTANT"
            color=$LOG_BLUE
            ;;
        3)  
            level_str="WARN"
            color=$LOG_YELLOW
            ;;
        4)  
            level_str="ERROR"
            color=$LOG_RED
            ;;
        *)  
            echo -e "${LOG_RED}错误: 无效的日志级别 $level${LOG_NC}" >&2
            return 1
            ;;
    esac
    
    # 构建日志内容
    local log_content="[$timestamp] [$level_str] $message"
    
    # 输出到终端（带颜色）
    echo -e "${color}${log_content}${LOG_NC}"
    
    # 写入日志文件（不带颜色）
    echo "$log_content" >> "$log_path"
}