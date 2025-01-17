#!/bin/bash
###############################################################################
# 脚本名称：setup_tgpt.sh
# 作用：安装/卸载 chatGPT 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 源代码：https://github.com/0xacx/chatGPT-shell-cli
# 版本：1.3
# 用法：
#   安装: ./setup_tgpt.sh install
#   卸载: ./setup_tgpt.sh uninstall
###############################################################################

# 全局常量
INSTALL_PATH="/usr/local/bin"
GITHUB_API_URL="https://api.github.com/repos/aandrew-me/tgpt/releases/latest"

# 颜色代码
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 错误处理
set -e
trap cleanup EXIT

# source 检测函数
is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then 
        case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
    else  # bash
        case ${BASH_SOURCE[0]} in */bash)
            return 1;;
        *)
            # If $0 is a script name and not "bash", we're running directly
            if [ "${0##*/}" != "bash" ] && [ "${0##*/}" != "sh" ]; then
                return 1
            fi
            return 0;;
        esac
    fi
    return 1
}

# 清理函数
cleanup() {
    local exit_code=$?
    [ -e /tmp/tgpt ] && rm -f /tmp/tgpt
    if [ $exit_code -ne 0 ]; then
        echo "Installation failed with error code: $exit_code"
        echo "Please check the error messages above"
    fi
}

# 日志函数
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_warning() { echo "[WARNING] $1" >&2; }

# 显示使用帮助
show_help() {
    cat << EOF
Usage: $0 [OPTION]

Options:
    install     Install or update tgpt (default)
    uninstall   Remove tgpt
    -h, --help  Show this help message

Examples:
    $0              # Install or update tgpt
    $0 install      # Same as above
    $0 uninstall    # Remove tgpt
EOF
}

# 获取远程最新版本
get_remote_version() {
    local version
    version=$(curl -s "$GITHUB_API_URL" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$version" ]; then
        log_error "Failed to fetch remote version"
        exit 1
    fi
    echo "$version"
}

# 获取本地版本
get_local_version() {
    # 检查tgpt是否已安装
    if ! command -v tgpt >/dev/null 2>&1; then
        echo "none"
        return
    fi

    # 通过 tgpt --version 获取版本号
    local version_output
    version_output=$(tgpt --version 2>/dev/null)
    if [ $? -eq 0 ] && [[ $version_output =~ tgpt[[:space:]]+(([0-9]+\.){2}[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "none"
    fi
}

# 卸载函数
uninstall() {
    if [ -f "$INSTALL_PATH/tgpt" ]; then
        log_info "Uninstalling tgpt..."
        # 获取当前版本用于显示
        local current_version=$(get_local_version)
        if [ "$current_version" != "none" ]; then
            log_info "Removing tgpt version $current_version"
        fi
        
        if [ ! -w "$INSTALL_PATH" ]; then
            sudo rm -f "$INSTALL_PATH/tgpt"
        else
            rm -f "$INSTALL_PATH/tgpt"
        fi
        log_info "tgpt has been uninstalled successfully"
    else
        log_error "tgpt is not installed"
        exit 1
    fi
}

# 安装函数
install() {
    # 检查curl
    if ! command -V curl > /dev/null 2>&1; then
        log_error "curl not installed, please install it and try again"
        exit 1
    fi

    # 检查系统架构
    case $(uname -m) in
        x86_64) ARCH="amd64" ;;
        i386|i686) ARCH="i386" ;;
        arm64|aarch64) ARCH="arm64" ;;
        arm|armv7l) ARCH="armv7l" ;;
        *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    # 检查操作系统
    if [[ $(uname -s) == "Darwin" ]]; then
        OS="mac"
    else
        OS="linux"
    fi

    log_info "Operating System: ${OS}"
    log_info "Architecture: ${ARCH}"

    # 获取版本信息
    local remote_version=$(get_remote_version)
    local local_version=$(get_local_version)

    if [ "$local_version" = "none" ]; then
        log_info "Installing tgpt version $remote_version..."
    else
        if [ "$local_version" = "$remote_version" ]; then
            log_info "Already at latest version ($local_version)"
            exit 0
        else
            log_info "Updating tgpt from version $local_version to $remote_version..."
        fi
    fi

    # 设置下载URL
    local URL="https://github.com/aandrew-me/tgpt/releases/latest/download/tgpt-${OS}-${ARCH}"
    
    # 下载
    log_info "Downloading from: $URL"
    if ! curl -SL --progress-bar "$URL" -o /tmp/tgpt; then
        log_error "Download failed"
        exit 1
    fi

    # 检查下载的文件
    if [ ! -f "/tmp/tgpt" ]; then
        log_error "Downloaded file not found"
        exit 1
    fi

    # 检查文件大小
    local size=$(stat -f%z "/tmp/tgpt" 2>/dev/null || stat -c%s "/tmp/tgpt" 2>/dev/null)
    if [ "$size" -lt 1000 ]; then  # 假设正常文件至少1KB
        log_error "Downloaded file is too small, possibly corrupted"
        exit 1
    fi

    # 检查安装目录
    if [ ! -d "$INSTALL_PATH" ]; then
        sudo mkdir -p "$INSTALL_PATH"
    fi

    # 安装
    if [[ "$INSTALL_PATH" == "/usr/local/bin" ]] || [[ "$INSTALL_PATH" == "/usr/bin" ]]; then
        # 系统目录安装 - 需要 root 权限
        if ! sudo mv /tmp/tgpt "$INSTALL_PATH/tgpt"; then
            log_error "Failed to move tgpt to $INSTALL_PATH"
            exit 1
        fi
        # 设置标准权限 (755 = rwxr-xr-x)
        if ! sudo chmod 755 "$INSTALL_PATH/tgpt"; then
            log_error "Failed to set permissions for tgpt"
            exit 1
        fi
        # 确保所有权正确
        if ! sudo chown root:root "$INSTALL_PATH/tgpt"; then
            log_error "Failed to set ownership for tgpt"
            exit 1
        fi
    else
        # 用户目录安装
        if ! mv /tmp/tgpt "$INSTALL_PATH/tgpt"; then
            log_error "Failed to move tgpt to $INSTALL_PATH"
            exit 1
        fi
        # 设置用户执行权限 (700 = rwx------)
        if ! chmod 700 "$INSTALL_PATH/tgpt"; then
            log_error "Failed to set permissions for tgpt"
            exit 1
        fi
    fi

    # 验证安装
    local new_version=$(get_local_version)
    if [ "$new_version" = "none" ]; then
        log_error "Installation verification failed"
        exit 1
    fi

    log_info "Installation completed successfully!"
    log_info "Version: $new_version"
    
    # 显示使用说明（绿色）
    printf "\n${GREEN}Usage Examples:
    tgpt \"Your question here\"     Ask a question
    tgpt --chat                   Start chat mode
    tgpt --image \"description\"    Generate an image
    tgpt -h                       Show more options

For more information, visit: https://github.com/aandrew-me/tgpt${NC}\n"
}

# 主函数
steup_tgpt() {
    case "${1:-install}" in
        install|"")
            install
            ;;
        uninstall)
            uninstall
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# 只有当脚本直接运行时才执行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    steup_tgpt "$@"
fi