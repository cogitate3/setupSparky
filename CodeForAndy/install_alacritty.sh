#!/bin/bash
###############################################################################
# 脚本名称：install_alacritty.sh
# 作用：安装 Alacritty 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 版本：1.0
# 返回值：
#   无
###############################################################################

# 日志颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local error_msg="$1"
    log_error "$error_msg (Exit code: $exit_code)"
    cleanup
    exit 1
}

# 清理函数
cleanup() {
    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
}

# 设置错误处理
set -e
trap cleanup EXIT
trap 'handle_error "Script interrupted"; exit 1' INT TERM

# 检查必要的命令
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found. Installing..."
        if ! sudo apt install -y "$2"; then
            handle_error "Failed to install $2"
        fi
    fi
}

# 检查必要的命令
check_command "wget" "wget"
check_command "unzip" "unzip"
check_command "fc-cache" "fontconfig"

# 创建临时目录
tmp_dir=$(mktemp -d)

# 检查脚本是否通过 bash 执行
if [ -z "$BASH_VERSION" ]; then
    log_error "This script must be run using bash."
    log_info "Usage: bash $(basename "$0")"
    exit 1
fi

# 检查是否有 sudo 权限
if ! sudo -v; then
    log_error "This script requires sudo privileges"
    exit 1
fi

# 确保正确获取用户家目录
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
if [ ! -d "$USER_HOME" ]; then
    log_error "Failed to determine user home directory"
    exit 1
fi

# 检查是否已安装 Alacritty
if command -v alacritty &> /dev/null; then
    log_warn "Alacritty is already installed"
    read -p "Do you want to reinstall? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
fi

# 更新系统并安装 Alacritty
log_info "Updating system packages..."
if ! sudo apt update; then
    handle_error "Failed to update package list"
fi

log_info "Installing Alacritty..."
if ! sudo apt install -y alacritty; then
    handle_error "Failed to install Alacritty"
fi

# 在原脚本的 Alacritty 安装之后、配置文件设置之前添加以下代码：

# 安装 JetBrains Mono 字体
log_info "Installing JetBrains Mono font..."

# 检查字体是否已安装
if fc-list | grep -i "JetBrains Mono" >/dev/null; then
    log_warn "JetBrains Mono font is already installed"
else
    # 创建字体目录
    FONT_DIR="$USER_HOME/.local/share/fonts"
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

    # 复制字体文件
    cp "$tmp_dir/JetBrainsMono/"*.ttf "$FONT_DIR/" || \
        handle_error "Failed to copy font files"

    # 设置权限
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$FONT_DIR"

    # 更新字体缓存
    log_info "Updating font cache..."
    if ! fc-cache -f; then
        handle_error "Failed to update font cache"
    fi
fi

# 检查字体是否成功安装
if ! fc-list | grep -i "JetBrains Mono" >/dev/null; then
    handle_error "Font installation verification failed"
else
    log_info "JetBrains Mono font installed successfully"
fi

# 创建 Alacritty 配置文件
log_info "Setting up Alacritty configuration..."
CONFIG_DIR="$USER_HOME/.config/alacritty"
CONFIG_FILE="$CONFIG_DIR/alacritty.toml"

# 备份并删除现有配置
if [ -f "$CONFIG_FILE" ]; then
    backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backing up existing configuration to $backup_file"
    cp "$CONFIG_FILE" "$backup_file" || handle_error "Failed to backup existing configuration"
    rm "$CONFIG_FILE" || handle_error "Failed to remove old configuration file"
fi

# 创建配置目录
mkdir -p "$CONFIG_DIR" || handle_error "Failed to create configuration directory"

# 写入配置文件
cat > "$CONFIG_FILE" <<EOL || handle_error "Failed to write configuration file"
# Alacritty Configuration File

[font]
normal = { family = "JetBrains Mono", style = "Regular" }
size = 14.0

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.normal]
black = "#1e1e2e"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#cba6f7"
cyan = "#94e2d5"
white = "#bac2de"

[colors.bright]
black = "#585b70"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#cba6f7"
cyan = "#94e2d5"
white = "#a6adc8"

[cursor]
style = "Beam"
unfocused_hollow = true

[window.padding]
x = 10
y = 10
EOL

# 设置正确的文件权限
if ! sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$CONFIG_DIR"; then
    handle_error "Failed to set permissions on configuration directory"
fi

# 清理临时文件
cleanup

log_info "Alacritty has been successfully installed and configured!"

exit 0