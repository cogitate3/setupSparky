#!/bin/bash

# 设置错误时立即退出并开启调试模式
set -e  # 遇到错误立即退出
set -u  # 使用未定义的变量时报错
set -o pipefail  # 管道中的错误也会导致脚本退出

# 定义颜色输出
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'  # No Color

# 定义日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" >&2
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    exit 1
}

# 清理函数
cleanup() {
    local exit_code=$?
    # 如果不是正常退出，显示错误信息
    if [ $exit_code -ne 0 ]; then
        error "脚本执行失败，退出码: $exit_code"
    fi
}

# 注册清理函数
trap cleanup EXIT

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1 || error "需要 $1 命令但未找到"
}

# 检查系统兼容性
check_system_compatibility() {
    # 检查是否为 Debian 系列
    if [ ! -f /etc/debian_version ]; then
        error "此脚本仅支持 Debian/Ubuntu 系统"
    }
    
    # 检查是否有图形界面
    if ! dpkg -l | grep -qE "x11|wayland"; then
        error "未检测到图形界面环境"
    }
}

# 获取当前用户信息
get_current_user() {
    local current_user
    # 尝试多种方式获取当前用户
    current_user=$(who -m | awk '{print $1}') || \
    current_user=$(logname) || \
    current_user=$SUDO_USER || \
    error "无法获取当前用户名"
    
    echo "$current_user"
}

# 检查并创建目录
create_directories() {
    local user=$1
    local home_dir="/home/$user"
    local dirs=(
        "$home_dir/.config/autostart"
        "$home_dir/.config/fcitx5/profile"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" || error "无法创建目录: $dir"
    done
}

# 安装必要的包
install_packages() {
    local packages=(
        fcitx5
        fcitx5-chinese-addons
        fcitx5-pinyin
        fcitx5-rime
        fcitx5-frontend-qt5
        fcitx5-frontend-gtk3
        fcitx5-frontend-gtk4
        fcitx5-config-qt
        kde-config-fcitx5
    )
    
    # 设置非交互式安装
    export DEBIAN_FRONTEND=noninteractive
    
    # 更新包列表
    apt-get update || error "更新软件源失败"
    
    # 安装软件包
    apt-get install -y "${packages[@]}" || error "安装软件包失败"
}

# 配置环境变量
configure_environment() {
    cat > /etc/environment <<'EOF' || error "配置环境变量失败"
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus  # 某些应用需要
EOF
}

# 配置自动启动
configure_autostart() {
    local user=$1
    local autostart_file="/home/$user/.config/autostart/fcitx5.desktop"
    
    cat > "$autostart_file" <<'EOF' || error "配置自动启动失败"
[Desktop Entry]
Name=Fcitx 5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Notify=false
X-KDE-autostart-after=panel
X-KDE-autostart-phase=1
EOF
}

# 配置输入法
configure_input_method() {
    local user=$1
    local config_file="/home/$user/.config/fcitx5/profile/default"
    
    cat > "$config_file" <<'EOF' || error "配置输入法失败"
[Groups/0]
Name=默认
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=默认
EOF
}

# 设置文件权限
set_permissions() {
    local user=$1
    local home_dir="/home/$user"
    
    chown -R "$user:$user" "$home_dir/.config/fcitx5" || \
        error "设置 fcitx5 配置权限失败"
}

# 主要执行流程
main() {
    # 检查基本命令
    check_command apt-get
    check_command who
    check_command dpkg
    
    # 检查root权限
    [[ $EUID -eq 0 ]] || error "请使用 root 权限运行此脚本"
    
    # 检查系统兼容性
    check_system_compatibility
    
    # 获取当前用户
    CURRENT_USER=$(get_current_user)
    USER_HOME="/home/$CURRENT_USER"
    [[ -d "$USER_HOME" ]] || error "用户主目录 $USER_HOME 不存在"
    
    log "开始配置中文输入法..."
    
    # 卸载IBus
    if dpkg -l | grep -qw "ibus"; then
        log "检测到 IBus，正在卸载..."
        apt-get remove --purge -y ibus ibus-* || warning "卸载 IBus 时出现警告"
        apt-get autoremove -y
    fi
    
    # 创建必要的目录
    create_directories "$CURRENT_USER"
    
    # 安装必要的包
    log "安装必要的软件包..."
    install_packages
    
    # 配置各个组件
    log "配置环境变量..."
    configure_environment
    
    log "配置自动启动..."
    configure_autostart "$CURRENT_USER"
    
    log "配置默认输入法..."
    configure_input_method "$CURRENT_USER"
    
    # 设置权限
    set_permissions "$CURRENT_USER"
    
    log "配置完成！请重启系统以应用更改。"
}

# 执行主函数
main "$@"