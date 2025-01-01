#!/bin/bash

# 引入新的日志系统
# 日志默认文件路径
DEFAULT_LOG_FILE="/tmp/logs/system_setup.log"
CURRENT_LOG_FILE="$DEFAULT_LOG_FILE"
CONSOLE_OUTPUT=true

# 定义颜色输出函数（为了兼容已有的日志系统）
red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[34m\033[01m$1\033[0m"; }
bold() { echo -e "\033[1m\033[01m$1\033[0m"; }

# 设置日志文件路径
set_log_file() {
    local file_path="$1"
    if [[ -z "$file_path" ]]; then
        echo "$(red '错误：必须指定日志文件路径')"
        return 1
    fi
    if [[ "$file_path" != *.log ]]; then
        echo "$(red '错误：日志文件名必须以.log结尾')"
        return 1
    fi
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
log() {
    declare -A LOG_LEVELS=(
        [0]="DEBUG"
        [1]="INFO"
        [2]="WARN"
        [3]="ERROR"
    )
    declare -A COLORS=(
        [0]="\\033[0m"
        [1]="\\033[32m"
        [2]="\\033[33m"
        [3]="\\033[31m"
    )

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

    if [ -n "$file_path" ]; then
        set_log_file "$file_path"
    elif [ -z "$CURRENT_LOG_FILE" ]; then
        set_log_file "$DEFAULT_LOG_FILE"
    fi
    
    if [ -z "$message" ]; then
        log_error "日志消息不能为空"
        echo "正确用法: log [<日志文件路径>] [<日志级别>] <消息>"
        return 1
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_text="${LOG_LEVELS[$level]}"
    local color="${COLORS[$level]}"

    if $CONSOLE_OUTPUT; then
        echo -e "${color}[$timestamp] [$level_text] $message\\033[0m"
    fi

    echo "[$timestamp] [$level_text] $message" >> "$CURRENT_LOG_FILE"
}

# 全局变量
SUDO_CMD=""
OS_TYPE=""
PACKAGE_MANAGER=""
PACKAGE_INSTALL=""
ARCH_TYPE=""

# 检查权限
check_root() {
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        SUDO_CMD="sudo"
        log 1 "检测到非 root 用户，将使用 sudo 执行命令"
    else
        log 1 "已以 root 用户权限运行"
    fi
}

# 检测系统架构
detect_architecture() {
    case "$(uname -m)" in
        'i386' | 'i686') ARCH_TYPE='x32' ;;
        'amd64' | 'x86_64') ARCH_TYPE='x64' ;;
        'armv8' | 'aarch64') ARCH_TYPE='arm64' ;;
        'armv7' | 'armv7l') ARCH_TYPE='arm32-v7' ;;
        'armv6l') ARCH_TYPE='arm32-v6' ;;
        *) ARCH_TYPE='unknown' ;;
    esac
    log 1 "系统架构检测结果：$ARCH_TYPE"
}

# 检测操作系统
detect_os() {
    local os_release_file="/etc/os-release"
    if [[ -f $os_release_file ]]; then
        source $os_release_file
        case "$ID" in
            debian|ubuntu|linuxmint|elementary|pop|zorin|mx|sparkylinux)
                OS_TYPE="$ID"
                PACKAGE_MANAGER="apt"
                PACKAGE_INSTALL="$SUDO_CMD apt install -y"
                log 1 "检测到基于 Debian 的系统（$ID）"
                ;;
            fedora|centos|rhel)
                OS_TYPE="$ID"
                PACKAGE_MANAGER="dnf"
                PACKAGE_INSTALL="$SUDO_CMD dnf install -y"
                log 1 "检测到基于 RHEL 的系统（$ID）"
                ;;
            arch|manjaro|endeavouros)
                OS_TYPE="$ID"
                PACKAGE_MANAGER="pacman"
                PACKAGE_INSTALL="$SUDO_CMD pacman -S --noconfirm"
                log 1 "检测到基于 Arch 的系统（$ID）"
                ;;
            opensuse*|suse)
                OS_TYPE="$ID"
                PACKAGE_MANAGER="zypper"
                PACKAGE_INSTALL="$SUDO_CMD zypper install -y --no-recommends"
                log 1 "检测到基于 OpenSUSE 的系统（$ID）"
                ;;
            *)
                log 2 "未识别的系统类型：$ID"
                OS_TYPE="unknown"
                PACKAGE_MANAGER="unknown"
                PACKAGE_INSTALL=""
                ;;
        esac
    else
        log 3 "无法检测系统类型，文件 /etc/os-release 不存在"
        OS_TYPE="unknown"
        PACKAGE_INSTALL=""
    fi
}

# 更新系统
update_system() {
    log 1 "开始更新系统包..."
    case $PACKAGE_MANAGER in
        apt) $SUDO_CMD apt update -qq ;;
        dnf) $SUDO_CMD dnf update -y -q ;;
        pacman) $SUDO_CMD pacman -Sy --noconfirm ;;
        zypper) $SUDO_CMD zypper refresh -q ;;
        *)
            log 3 "不支持的包管理器：$PACKAGE_MANAGER"
            return 1
            ;;
    esac
    log 1 "系统更新完成"
}

# 安装必要的软件包
install_requirements() {
    local packages="curl wget jq unzip"
    log 1 "开始安装必要的软件包：$packages"
    if [[ -z "$PACKAGE_INSTALL" ]]; then
        log 3 "错误：未定义安装命令，无法安装软件包"
        exit 1
    fi
    $PACKAGE_INSTALL $packages || {
        log 3 "软件包安装失败"
        exit 1
    }
    log 1 "必要的软件包已成功安装"
}

# 主函数
main() {
    check_root
    detect_architecture
    detect_os

    if [[ "$OS_TYPE" == "unknown" ]]; then
        log 3 "不支持的操作系统，脚本退出"
        exit 1
    fi

    update_system
    install_requirements

    log 1 "系统准备工作已完成"
}

# 运行主函数
main