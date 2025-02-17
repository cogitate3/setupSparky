#!/bin/bash
###############################################################################
# 脚本名称：setup_alacritty.sh
# 作用：安装/卸载 Alacritty 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 版本：1.3
# 用法：
#   安装: ./setup_alacritty.sh install
#   卸载: ./setup_alacritty.sh uninstall
###############################################################################

# 检测是否被source
(return 0 2>/dev/null) && SOURCED=1 || SOURCED=0

# 配置文件URL
CONFIG_URL="URLABCD"

# 日志颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 安装步骤追踪
declare -a INSTALL_STEPS=()
declare -a ROLLBACK_STEPS=()
CURRENT_STEP=0

# 依赖列表
declare -A DEPENDENCIES=(
    ["wget"]="wget"
    ["unzip"]="unzip"
    ["fc-cache"]="fontconfig"
    ["git"]="git"
    ["curl"]="curl"
    ["tar"]="tar"
    ["rustc"]="rustc"
    ["cargo"]="cargo"
)

# 显示用法函数
show_usage() {
    cat << EOF
Usage: $(basename "$0") <command>

Commands:
    install     Install Alacritty terminal
    uninstall   Uninstall Alacritty terminal

Examples:
    $(basename "$0") install
    $(basename "$0") uninstall
EOF
    exit 1
}

# 系统信息获取
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
}

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 参数验证
validate_args() {
    if [ $# -ne 1 ]; then
        log_error "Invalid number of arguments"
        show_usage
    fi

    case "$1" in
        install|uninstall)
            true
            ;;
        *)
            log_error "Invalid command: $1"
            show_usage
            ;;
    esac
}

# 注册安装步骤
register_step() {
    local step_name="$1"
    local rollback_cmd="$2"
    INSTALL_STEPS+=("$step_name")
    ROLLBACK_STEPS+=("$rollback_cmd")
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log_info "Registered step $CURRENT_STEP: $step_name"
}

# 回滚函数
rollback() {
    log_warn "Installation failed at step $CURRENT_STEP, rolling back..."
    for ((i=${#ROLLBACK_STEPS[@]}-1; i>=0; i--)); do
        if [ -n "${ROLLBACK_STEPS[i]}" ]; then
            log_info "Rolling back step $((i+1)): ${INSTALL_STEPS[i]}"
            eval "${ROLLBACK_STEPS[i]}" || log_error "Rollback failed for step $((i+1))"
        fi
    done
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local error_msg="$1"
    log_error "$error_msg (Exit code: $exit_code)"
    log_error "Check logs at: $LOG_FILE"
    rollback
    cleanup
    exit 1
}

# 清理函数
cleanup() {
    log_info "Performing cleanup..."
    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
}

# 下载配置文件函数
download_config() {
    local config_dir="$1"
    local config_file="$2"
    local temp_dir="$tmp_dir/config"
    local temp_download="$temp_dir/downloaded_config"
    
    # 创建临时目录
    mkdir -p "$temp_dir" || handle_error "Failed to create temporary config directory"
    
    log_info "Downloading configuration file..."
    if ! curl -sSL "$CONFIG_URL" -o "$temp_download"; then
        handle_error "Failed to download configuration file"
    fi

    # 验证下载的文件
    if [ ! -s "$temp_download" ]; then
        handle_error "Downloaded configuration file is empty"
    fi

    # 验证文件格式（TOML格式检查）
    if ! grep -q "\[.*\]" "$temp_download"; then
        rm -f "$temp_download"
        handle_error "Invalid configuration file format"
    fi

    # 确保配置目录存在
    mkdir -p "$config_dir" || handle_error "Failed to create config directory: $config_dir"

    # 如果已存在配置文件，先备份
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up existing configuration to $backup_file"
        mv "$config_file" "$backup_file" || handle_error "Failed to backup existing configuration"
        register_step "Backup config" "mv $backup_file $config_file"
    fi

    # 移动到最终位置，确保文件名正确
    log_info "Installing configuration file to $config_file"
    if ! mv "$temp_download" "$config_file"; then
        handle_error "Failed to install configuration file"
    fi
    
    # 验证安装的配置文件
    if [ ! -f "$config_file" ]; then
        handle_error "Configuration file not found at expected location: $config_file"
    fi

    # 设置正确的权限
    chmod 644 "$config_file" || handle_error "Failed to set configuration file permissions"
    chown "$USER:$USER" "$config_file" || handle_error "Failed to set configuration file ownership"

    log_info "Configuration file successfully installed"
    register_step "Install config" "rm -f $config_file"
}

# 验证配置安装
verify_config_installation() {
    local config_file="$1"
    
    log_info "Verifying configuration installation..."
    
    # 检查文件是否存在
    if [ ! -f "$config_file" ]; then
        handle_error "Configuration file not found: $config_file"
    fi

    # 检查文件权限
    if [ "$(stat -c %a "$config_file")" != "644" ]; then
        handle_error "Incorrect configuration file permissions"
    fi

    # 检查文件所有者
    if [ "$(stat -c %U "$config_file")" != "$USER" ]; then
        handle_error "Incorrect configuration file ownership"
    fi

    # 检查文件内容
    if ! grep -q "\[.*\]" "$config_file"; then
        handle_error "Configuration file appears to be invalid"
    fi

    log_info "Configuration file verification successful"
}

# 系统依赖检查
check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # 检查操作系统
    get_os_info
    log_info "Detected OS: $OS_NAME $OS_VERSION"
    
    # 检查系统架构
    ARCH=$(uname -m)
    log_info "System architecture: $ARCH"
    
    # 检查可用磁盘空间
    AVAILABLE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    log_info "Available disk space: $AVAILABLE_SPACE"
    
    # 检查内存
    TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
    log_info "Total system memory: $TOTAL_MEM"
}

# 检查依赖
check_dependencies() {
    log_info "Checking dependencies..."
    local missing_deps=()
    
    for cmd in "${!DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("${DEPENDENCIES[$cmd]}")
            log_warn "Missing dependency: $cmd"
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_info "Installing missing dependencies: ${missing_deps[*]}"
        if ! sudo apt update; then
            handle_error "Failed to update package list"
        fi
        
        for dep in "${missing_deps[@]}"; do
            if ! sudo apt install -y "$dep"; then
                handle_error "Failed to install dependency: $dep"
            fi
            register_step "Install $dep" "sudo apt remove -y $dep"
        done
    fi
}

# 卸载函数
uninstall_alacritty() {
    log_info "Starting Alacritty uninstallation..."

    # 删除配置文件和目录
    local config_dir="$HOME/.config/alacritty"
    if [ -d "$config_dir" ]; then
        log_info "Removing configuration directory..."
        rm -rf "$config_dir"
    fi

    # 卸载字体
    log_info "Removing JetBrains Mono font..."
    local font_dir="$HOME/.local/share/fonts"
    if [ -d "$font_dir" ]; then
        rm -f "$font_dir"/JetBrains*
        fc-cache -f
    fi

    # 卸载 Alacritty
    log_info "Removing Alacritty package..."
    if ! sudo apt remove --purge -y alacritty; then
        log_error "Failed to remove Alacritty package"
        return 1
    fi

    # 清理依赖
    log_info "Cleaning up dependencies..."
    sudo apt autoremove -y

    log_info "Alacritty has been successfully uninstalled"
    return 0
}

# 初始化
init_installation() {
    # 创建日志目录和文件
    LOG_DIR="$HOME/.logs/alacritty"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    
    # 创建临时目录
    tmp_dir=$(mktemp -d)
    
    # 设置错误处理
    set -e
    trap cleanup EXIT
    trap 'handle_error "Script interrupted"' INT TERM
    
    log_info "Installation started at $(date)"
    log_info "Log file: $LOG_FILE"
}

# 安装 JetBrains Mono 字体
install_font() {
    log_info "Installing JetBrains Mono font..."

    # 检查字体是否已安装
    if fc-list | grep -i "JetBrains Mono" >/dev/null; then
        log_warn "JetBrains Mono font is already installed"
        return 0
    fi

    # 创建字体目录
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR" || handle_error "Failed to create fonts directory"

    # 下载并安装字体
    FONT_ZIP="$tmp_dir/JetBrainsMono.tar.xz"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz"

    log_info "Downloading JetBrains Mono font..."
    if ! wget -q "$FONT_URL" -O "$FONT_ZIP"; then
        handle_error "Failed to download JetBrains Mono font"
    fi

    log_info "Extracting font files..."
    if ! tar -xf "$FONT_ZIP" -C "$FONT_DIR"; then
        handle_error "Failed to extract font files"
    fi

    # 设置权限
    chown -R "$USER:$USER" "$FONT_DIR"

    # 更新字体缓存
    log_info "Updating font cache..."
    if ! fc-cache -f; then
        handle_error "Failed to update font cache"
    fi

    register_step "Install font" "rm -rf $FONT_DIR/JetBrains*"
}

# 主程序
setup_alacritty() {
    # 验证参数
    validate_args "$@"

    # 初始化安装环境
    init_installation

    case "$1" in
        install)
            log_info "Starting Alacritty installation..."
            check_system_compatibility
            check_dependencies

            # 安装 Alacritty
            log_info "Installing Alacritty..."
            if ! sudo apt install -y alacritty; then
                handle_error "Failed to install Alacritty"
            fi
            register_step "Install Alacritty" "sudo apt remove -y alacritty"

            # 安装字体
            install_font

            # 配置文件安装
            CONFIG_DIR="$HOME/.config/alacritty"
            CONFIG_FILE="$CONFIG_DIR/alacritty.toml"
            
            log_info "Setting up Alacritty configuration..."
            download_config "$CONFIG_DIR" "$CONFIG_FILE"
            verify_config_installation "$CONFIG_FILE"

            log_info "Installation completed successfully!"
            ;;
            
        uninstall)
            uninstall_alacritty
            ;;
    esac
}

# 执行控制
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 脚本被直接执行
    if [ -z "$BASH_VERSION" ]; then
        log_error "This script must be run using bash."
        log_info "Usage: bash $(basename "$0") <command>"
        exit 1
    fi
    
    setup_alacritty "$@"
else
    # 脚本被source，只导出函数
    if [[ $SOURCED -eq 1 ]]; then
        log_info "Script is being sourced. Functions are now available."
    fi
fi

# 安装
# ./setup_alacritty.sh install

# 卸载
# ./setup_alacritty.sh uninstall

# source使用（只加载函数）
# source setup_alacritty.sh