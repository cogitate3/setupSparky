#!/bin/bash

# 全局变量定义
declare -g CURRENT_LOG_FILE=""
declare -g DEBUG_MODE=0  # 调试模式开关

# 错误码定义
declare -r E_SUCCESS=0        # 成功
declare -r E_PARAM_ERROR=1    # 参数错误
declare -r E_FILE_ERROR=2     # 文件操作错误
declare -r E_PERMISSION_ERROR=3 # 权限错误
declare -r E_UNKNOWN_ERROR=99  # 未知错误

# Debug函数
debug() {
    if [ "${DEBUG_MODE}" -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# 参数验证函数
validate_params() {
    local file_path="$1"
    local level="$2"
    
    # 验证文件路径
    if [ -n "$file_path" ]; then
        if [[ ! "$file_path" == *.log ]]; then
            echo "错误: 日志文件必须以.log结尾" >&2
            return $E_PARAM_ERROR
        fi
        
        # 检查目录是否可写
        local dir_path=$(dirname "$file_path")
        if [ ! -w "$dir_path" ] && [ -d "$dir_path" ]; then
            echo "错误: 目录 $dir_path 不可写" >&2
            return $E_PERMISSION_ERROR
        fi
    fi
    
    # 验证日志级别
    if [ -n "$level" ]; then
        if [[ ! "$level" =~ ^[0-3]$ ]]; then
            echo "错误: 日志级别必须是0-3之间的数字" >&2
            return $E_PARAM_ERROR
        fi
    fi
    
    return $E_SUCCESS
}

# 增强的set_log_file函数
set_log_file() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        echo "错误: 文件路径不能为空" >&2
        return $E_PARAM_ERROR
    fi
    
    # 验证参数
    validate_params "$file_path" || return $?
    
    local dir_path=$(dirname "$file_path")
    
    # 创建目录（如果不存在）
    if [ ! -d "$dir_path" ]; then
        debug "创建目录: $dir_path"
        if ! mkdir -p "$dir_path" 2>/dev/null; then
            echo "错误: 无法创建目录 $dir_path" >&2
            return $E_PERMISSION_ERROR
        fi
    fi
    
    # 检查文件是否存在且可写
    if [ -f "$file_path" ] && [ ! -w "$file_path" ]; then
        echo "错误: 文件 $file_path 不可写" >&2
        return $E_PERMISSION_ERROR
    fi
    
    # 尝试创建或打开文件
    if ! touch "$file_path" 2>/dev/null; then
        echo "错误: 无法创建或访问文件 $file_path" >&2
        return $E_FILE_ERROR
    }
    
    CURRENT_LOG_FILE="$file_path"
    debug "日志文件设置为: $CURRENT_LOG_FILE"
    return $E_SUCCESS
}

# 增强的log函数
log() {
    local status=$E_SUCCESS
    
    # 定义颜色代码的关联数组
    declare -A COLORS=(
        ["nocolour"]="\\033[0m"
        ["green"]="\\033[32m"
        ["yellow"]="\\033[33m"
        ["red"]="\\033[31m"
    )
    
    # 定义日志级别
    declare -A LOG_LEVELS=(
        [0]="DEBUG"
        [1]="INFO"
        [2]="WARN"
        [3]="ERROR"
    )
    
    # 定义级别颜色
    declare -A LEVEL_COLORS=(
        [0]="nocolour"
        [1]="green"
        [2]="yellow"
        [3]="red"
    )
    
    local file_path=""
    local level=1
    local message=""
    
    # 参数解析
    case $# in
        1)
            if [[ "$1" == *.log ]]; then
                file_path="$1"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                level="$1"
            else
                message="$1"
            fi
            ;;
        2)
            if [[ "$1" == *.log ]]; then
                file_path="$1"
                message="$2"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                level="$1"
                message="$2"
            else
                echo "错误: 参数格式不正确" >&2
                return $E_PARAM_ERROR
            fi
            ;;
        3)
            file_path="$1"
            level="$2"
            message="$3"
            ;;
        *)
            echo "错误: 参数数量必须是1-3个" >&2
            return $E_PARAM_ERROR
            ;;
    esac
    
    # 验证参数
    validate_params "$file_path" "$level" || return $?
    
    # 检查消息内容
    if [ -z "$message" ]; then
        echo "错误: 日志消息不能为空" >&2
        return $E_PARAM_ERROR
    fi
    
    # 设置日志文件
    if [ -n "$file_path" ]; then
        set_log_file "$file_path" || return $?
    elif [ -z "$CURRENT_LOG_FILE" ]; then
        echo "错误: 未设置日志文件" >&2
        return $E_PARAM_ERROR
    fi
    
    # 获取时间戳
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S') || {
        echo "错误: 无法获取时间戳" >&2
        return $E_UNKNOWN_ERROR
    }
    
    # 获取日志级别文本和颜色
    local level_text="${LOG_LEVELS[$level]}"
    local color="${LEVEL_COLORS[$level]}"
    local color_code="${COLORS[$color]}"
    local nc="${COLORS[nocolour]}"
    
    # 输出到控制台
    echo -e "[$timestamp] [$color_code$level_text$nc] $color_code$message$nc"
    
    # 写入日志文件
    if ! echo "[$timestamp] [$level_text] $message" >> "$CURRENT_LOG_FILE" 2>/dev/null; then
        echo "错误: 无法写入日志文件 $CURRENT_LOG_FILE" >&2
        return $E_FILE_ERROR
    fi
    
    return $E_SUCCESS
}

# 测试函数
test_log() {
    # 开启调试模式
    DEBUG_MODE=1
    
    echo "=== 开始测试日志系统 ==="
    
    # 测试无效参数
    log || echo "测试1通过: 捕获到无参数错误"
    
    # 测试无效日志级别
    log 5 "测试消息" || echo "测试2通过: 捕获到无效日志级别错误"
    
    # 测试无效文件路径
    log "/invalid/path/test.txt" "测试消息" || echo "测试3通过: 捕获到无效文件扩展名错误"
    
    # 测试正常日志记录
    log "/tmp/test.log" 1 "这是一条测试消息" && echo "测试4通过: 成功写入日志"
    
    echo "=== 测试完成 ==="
}

# 如果脚本被直接运行，则执行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_log
fi