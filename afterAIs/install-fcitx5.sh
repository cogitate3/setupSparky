#!/bin/bash

# 颜色和输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

success() {
    echo -e "${GREEN}成功: $1${NC}"
}

error_exit() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "请使用 sudo 运行此脚本"
    fi
}

# 检查系统兼容性
check_system() {
    if ! command -v apt-get >/dev/null; then
        error_exit "此脚本仅支持 Debian/Ubuntu 系统"
    fi
}

# 检查冲突的输入法
check_conflicting_inputs() {
    echo "检查并清理冲突的输入法..."
    
    # 检查是否安装了ibus
    if dpkg -l | grep -qw ibus; then
        echo "删除 ibus..."
        apt-get purge -y ibus ibus-* || error_exit "无法删除 ibus"
    fi
    
    # 检查旧版本fcitx
    if dpkg -l | grep -qw fcitx && ! dpkg -l | grep -qw fcitx5; then
        echo "删除旧版本 fcitx..."
        apt-get purge -y fcitx fcitx-* || error_exit "无法删除旧版本 fcitx"
    fi
}

# 安装必要的软件包
install_packages() {
    echo "安装必要的软件包..."
    
    # 更新软件包列表
    apt-get update || error_exit "无法更新软件包列表"
    
    # 安装fcitx5及其依赖
    PACKAGES=(
        fcitx5
        fcitx5-chinese-addons
        fcitx5-config-qt
        fcitx5-material-color
        fcitx5-module-cloudpinyin
        fcitx5-module-lua
        fcitx5-module-quickphrase
    )
    
    apt-get install -y "${PACKAGES[@]}" || error_exit "软件包安装失败"
}

# 配置环境变量
configure_environment() {
    echo "配置环境变量..."
    
    # 创建环境变量配置文件
    ENV_FILE="/etc/environment"
    
    # 添加或更新环境变量
    grep -v "^GTK_IM_MODULE\|^QT_IM_MODULE\|^XMODIFIERS" "$ENV_FILE" > "${ENV_FILE}.tmp"
    cat >> "${ENV_FILE}.tmp" << EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
}

# 安装 rime-ice 配置
# 安装 rime-ice 配置
install_rime_ice() {
    echo "安装 rime-ice 配置..."
    
    # 确保用户目录存在
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    RIME_DIR="$USER_HOME/.local/share/fcitx5/rime"
    
    # 安装 git（如果未安装）
    if ! command -v git >/dev/null; then
        echo "正在安装 git..."
        apt-get install -y git || error_exit "git 安装失败"
    fi
    
    # 备份原有配置（如果存在）
    if [ -d "$RIME_DIR" ]; then
        BACKUP_DIR="${RIME_DIR}_backup_$(date +%Y%m%d%H%M%S)"
        echo "备份现有配置到 $BACKUP_DIR ..."
        mv "$RIME_DIR" "$BACKUP_DIR" || error_exit "备份原有配置失败"
    fi
    
    # 创建新的空目录
    echo "创建新的配置目录..."
    mkdir -p "$RIME_DIR" || error_exit "无法创建配置目录"
    
    # 创建并进入临时目录
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || error_exit "无法创建临时目录"
    
    # 使用 git clone 下载配置
    echo "克隆 rime-ice 配置..."
    if ! sudo -u "$SUDO_USER" git clone --depth=1 https://github.com/iDvel/rime-ice.git; then
        rm -rf "$TEMP_DIR"
        # 如果失败，恢复备份
        if [ -d "$BACKUP_DIR" ]; then
            mv "$BACKUP_DIR" "$RIME_DIR"
        fi
        error_exit "克隆 rime-ice 仓库失败"
    fi
    
    # 复制配置文件
    echo "复制配置文件..."
    cp -rf rime-ice/* "$RIME_DIR/"
    chown -R "$SUDO_USER:$SUDO_USER" "$RIME_DIR"
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
    
    success "rime-ice 配置安装完成"
    
    # 提示备份信息
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${BLUE}原有配置已备份到: $BACKUP_DIR${NC}"
        echo "如需恢复，请执行:"
        echo "rm -rf $RIME_DIR && mv $BACKUP_DIR $RIME_DIR"
    fi
}

# 设置系统默认输入法
set_default_input_method() {
    echo "设置 fcitx5 为系统默认输入法..."
    
    # 设置 im-config 默认输入法
    if ! im-config -n fcitx5; then
        error_exit "设置默认输入法失败"
    fi
    
    # 如果用户在X环境下，立即生效
    if [ -n "$DISPLAY" ]; then
        echo "正在结束现有输入法进程..."
        pkill fcitx5 2>/dev/null
        pkill ibus 2>/dev/null
        pkill fcitx 2>/dev/null
        
        echo "启动 fcitx5..."
        # 使用当前用户启动 fcitx5
        if ! su - "$SUDO_USER" -c "fcitx5 -d"; then
            echo "警告: 无法立即启动 fcitx5，请重新登录后生效"
        fi
    else
        echo "请重新登录后生效"
    fi
    
    success "已设置 fcitx5 为默认输入法"
}

# 验证安装
verify_installation() {
    echo -e "${BLUE}=== 验证安装 ===${NC}"
    
    # 检查软件包安装
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            error_exit "软件包 $pkg 安装失败"
        fi
    done
    
    # 检查配置文件
    if [ ! -d "$RIME_DIR" ]; then
        error_exit "Rime 配置目录不存在"
    fi
    
    # 检查环境变量
    if ! grep -q "GTK_IM_MODULE=fcitx" /etc/environment; then
        error_exit "环境变量配置失败"
    fi
    
    success "安装验证通过"
}

# 主函数
main() {
    # 检查权限
    check_root
    
    # 检查系统
    check_system
    
    # 检查冲突的输入法
    check_conflicting_inputs
    
    # 安装必要的包
    install_packages
    
    # 设置环境变量
    configure_environment
    
    # 安装 rime-ice 配置
    install_rime_ice
    
    # 设置为默认输入法
    set_default_input_method
    
    # 验证安装
    verify_installation
    
    success "安装完成！请重新登录以使配置生效。"
    
    echo -e "\n${BLUE}=== 重新登录后验证清单 ===${NC}"
    echo "1. 检查环境变量:"
    echo "   echo \$GTK_IM_MODULE"
    echo "   echo \$QT_IM_MODULE"
    echo "   echo \$XMODIFIERS"
    echo "2. 检查进程:"
    echo "   ps aux | grep fcitx5"
    echo "3. 测试输入法切换 (Ctrl + Space)"
    echo "4. 测试中文输入"
}

# 执行主函数
main "$@"