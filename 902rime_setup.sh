#!/bin/bash
# 文件名: 902rime_setup.sh
# 描述: 雾凇拼音输入法一键安装/卸载脚本 (Freedesktop标准版本)
# 作者: CodeParetoImpove Cogitate3 Claude.ai
# 版本: 2.1
# 使用方法: sudo bash rime_setup.sh install|uninstall
# 系统要求: 任何遵循freedesktop.org标准的Linux发行版

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# XDG 基础目录规范
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
        exit 1
    fi
}

# 更安全的用户检测函数
get_real_user_info() {
    # 优先使用SUDO_USER，因为这个变量准确反映了执行sudo的原始用户
    if [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        # 如果没有SUDO_USER（直接以root登录的情况），使用当前登录用户
        REAL_USER=$(who | awk '{print $1}' | head -n1)
        REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    fi

    # 验证获取的信息
    if [ -z "$REAL_USER" ] || [ -z "$REAL_HOME" ]; then
        echo -e "${RED}错误: 无法确定实际用户信息${NC}"
        exit 1
    fi

    echo -e "${BLUE}实际用户: $REAL_USER${NC}"
    echo -e "${BLUE}用户主目录: $REAL_HOME${NC}"
}

# 检查桌面环境
check_desktop_environment() {
    # 检测是否有图形环境
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        echo -e "${RED}错误: 未检测到图形环境${NC}"
        exit 1
    fi
    
    # 获取当前桌面环境
    local current_de="$XDG_CURRENT_DESKTOP"
    echo -e "${BLUE}当前桌面环境: $current_de${NC}"
    
    # 检查是否支持XDG标准
    if [ ! -d "$XDG_CONFIG_HOME" ]; then
        echo -e "${RED}警告: 系统可能不完全遵循XDG标准${NC}"
        read -p "是否继续？[y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}操作已取消${NC}"
            exit 1
        fi
    fi
}

# 带有重试的git clone函数
function git_clone_with_retry {
    local repo_url=$1
    local target_dir=$2
    local max_attempts=3
    local retry_delay=5

    # 检查目标目录是否存在且非空
    if [ -d "$target_dir" ] && [ "$(ls -A $target_dir)" ]; then
        echo -e "${BLUE}目标目录 $target_dir 已存在且非空，正在删除...${NC}"
        rm -rf "$target_dir"
    fi

    local counter=0
    until [ "$counter" -ge $max_attempts ]
    do
        git clone "$repo_url" "$target_dir" && break
        counter=$((counter+1))
        if [ "$counter" -eq $max_attempts ]; then
            echo -e "${RED}Failed to clone $repo_url after $max_attempts attempts. Aborting.${NC}"
            return 1
        fi
        echo -e "${RED}git clone failed, retrying in $retry_delay seconds...${NC}"
        sleep $retry_delay
    done
    
    return 0
}

# 安装必要的包并检查安装结果
install_packages() {
    echo -e "${GREEN}检查并安装必要的软件包...${NC}"
    
    # 创建要安装的包列表
    local packages=(
        "fcitx5"
        "fcitx5-rime"
        "fcitx5-chinese-addons"
        "fcitx5-frontend-gtk2"
        "fcitx5-frontend-gtk3"
        "fcitx5-frontend-qt5"
        "fcitx5-module-cloudpinyin"
        "qt5-style-plugins"
        "zenity"
        "fcitx5-module-lua"
        "fcitx5-material-color"
        "fonts-noto-cjk"
        "fonts-noto-color-emoji"
        "git"
        "curl"
    )

    # 需要安装的包列表
    local packages_to_install=()
    # 已安装的包列表
    local already_installed=()
    # 安装失败的包列表
    local failed_packages=()

    # 检查每个包的安装状态
    echo -e "${BLUE}检查已安装的软件包...${NC}"
    for package in "${packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii\s\+$package\s"; then
            already_installed+=("$package")
        else
            packages_to_install+=("$package")
        fi
    done

    # 显示已安装的包
    if [ ${#already_installed[@]} -ne 0 ]; then
        echo -e "${GREEN}以下软件包已安装，将跳过：${NC}"
        for package in "${already_installed[@]}"; do
            echo -e "${GREEN}✓ $package${NC}"
        done
    fi

    # 如果有需要安装的包
    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${BLUE}即将安装以下软件包：${NC}"
        for package in "${packages_to_install[@]}"; do
            echo -e "${BLUE}→ $package${NC}"
        done

        echo -e "${GREEN}开始安装缺失的软件包...${NC}"
        for package in "${packages_to_install[@]}"; do
            echo -e "${BLUE}正在安装 $package...${NC}"
            if ! apt install -y --install-recommends "$package"; then
                failed_packages+=("$package")
                echo -e "${RED}安装 $package 失败${NC}"
            else
                echo -e "${GREEN}安装 $package 成功${NC}"
            fi
        done
    else
        echo -e "${GREEN}所有必要的软件包都已安装${NC}"
        return 0
    fi

    # 检查是否有安装失败的包
    if [ ${#failed_packages[@]} -ne 0 ]; then
        echo -e "${RED}错误: 以下包安装失败：${NC}"
        for package in "${failed_packages[@]}"; do
            echo -e "${RED}✗ $package${NC}"
        done
        echo -e "${RED}请检查系统包管理器状态和网络连接后重试${NC}"
        echo -e "${BLUE}您可以尝试手动安装失败的包：${NC}"
        echo -e "${BLUE}sudo apt install ${failed_packages[*]}${NC}"
        return 1
    fi

    echo -e "${GREEN}所有必要的包安装完成${NC}"
    return 0
}

# 配置XDG自动启动
configure_xdg_autostart() {
    local autostart_dir="$REAL_HOME/.config/autostart"
    mkdir -p "$autostart_dir"

    # 创建自动启动文件
    cat > "$autostart_dir/fcitx5.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=Fcitx 5
Name[zh_CN]=Fcitx 5 输入法
Comment=Start Input Method
Comment[zh_CN]=启动输入法
Exec=fcitx5
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
X-GNOME-Autostart-Phase=Applications
EOF

    # 设置权限
    chown -R $REAL_USER:$REAL_USER "$autostart_dir"
    chmod 644 "$autostart_dir/fcitx5.desktop"
}

# 配置环境变量
configure_environment() {
    # 使用XDG规范的环境变量配置目录
    local env_dir="$REAL_HOME/.config/environment.d"
    mkdir -p "$env_dir"
    
    # 创建输入法环境变量配置
    cat > "$env_dir/fcitx5.conf" <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
INPUT_METHOD=fcitx
SDL_IM_MODULE=fcitx
EOF

    # 同时配置到.profile以确保兼容性
    local profile_file="$REAL_HOME/.profile"
    
    # 删除可能存在的旧配置
    sed -i '/^export GTK_IM_MODULE=fcitx/d' "$profile_file"
    sed -i '/^export QT_IM_MODULE=fcitx/d' "$profile_file"
    sed -i '/^export XMODIFIERS=@im=fcitx/d' "$profile_file"
    sed -i '/^export INPUT_METHOD=fcitx/d' "$profile_file"
    sed -i '/^export SDL_IM_MODULE=fcitx/d' "$profile_file"

    # 添加新的环境变量配置
    cat >> "$profile_file" <<EOF

# Fcitx5 input method
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
EOF

    # 设置权限
    chown -R $REAL_USER:$REAL_USER "$env_dir"
    chown $REAL_USER:$REAL_USER "$profile_file"
}

# 配置fcitx5和Rime输入法
configure_fcitx5_rime() {
    echo -e "${GREEN}配置Fcitx5和Rime输入法...${NC}"

    # 确保XDG配置目录存在
    local fcitx5_config_dir="$REAL_HOME/.config/fcitx5"
    local fcitx5_data_dir="$REAL_HOME/.local/share/fcitx5"
    
    mkdir -p "$fcitx5_config_dir/conf"
    mkdir -p "$fcitx5_config_dir/profile"
    mkdir -p "$fcitx5_data_dir/themes"

    # 配置输入法配置文件
    cat > "$fcitx5_config_dir/profile" <<EOF
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=rime
# Layout
Layout=

[GroupOrder]
0=Default
EOF

    # 配置Fcitx5全局配置
    cat > "$fcitx5_config_dir/config" <<EOF
[Hotkey]
# 切换启用/禁用输入法
TriggerKeys=Alt+space
# 轮换输入法
EnumerateForwardKeys=
EnumerateBackwardKeys=
# 切换至上一个输入法
AltTriggerKeys=

[Hotkey/EnumerateGroups]
0=Control+space

[Behavior]
# 默认启用输入法
ShareInputState=All
# 显示输入法信息
ShowInputMethodInformation=True
# 默认英文模式
ActiveByDefault=False
EOF

# 配置经典界面
    cat > "$fcitx5_config_dir/conf/classicui.conf" <<EOF
# Vertical Candidate List
Vertical Candidate List=False
# Use mouse wheel to go to prev or next page
WheelForPaging=True
# Font
Font="Noto Sans CJK SC 11"
# Menu Font
MenuFont="Sans 10"
# Tray Font
TrayFont="Sans Bold 10"
# Tray Label Outline Color
TrayOutlineColor=#000000
# Tray Label Text Color
TrayTextColor=#ffffff
# Prefer Text Icon
PreferTextIcon=False
# Show Layout Name In Icon
ShowLayoutNameInIcon=True
# Use input method language to display text
UseInputMethodLanguageToDisplayText=True
# Theme
Theme=Material-Color-orange
# Dark Theme
DarkTheme=Material-Color-deepPurple
# Follow system light/dark color scheme
UseDarkTheme=False
# Follow system accent color if it is supported by theme and desktop
UseAccentColor=True
# Use Per Screen DPI on X11
PerScreenDPI=True
# Force font DPI on Wayland
ForceWaylandDPI=0
# Enable fractional scale under Wayland
EnableFractionalScale=True
EOF

    # 配置云拼音
    cat > "$fcitx5_config_dir/conf/cloudpinyin.conf" <<EOF
# 云拼音来源
CloudPinyinBackend=Baidu
# 最小拼音长度
MinimumPinyinLength=2
EOF

    # 配置punctuation
    cat > "$fcitx5_config_dir/conf/punctuation.conf" <<EOF
# 半角/全角标点切换
HalfWidthPuncAfterLetterOrNumber=True
EOF

    # 配置rime
    cat > "$fcitx5_config_dir/conf/rime.conf" <<EOF
# 同步设置
PreeditInApplication=True
# 在程序中显示预编辑文本
PreeditInApplication=True
# 是否允许扩展编辑器
AllowExtensionEditor=False
EOF

    # 配置XDG自动启动
    configure_xdg_autostart

    # 配置环境变量
    configure_environment

    # 设置所有权
    chown -R $REAL_USER:$REAL_USER "$fcitx5_config_dir"
    chown -R $REAL_USER:$REAL_USER "$fcitx5_data_dir"

    echo -e "${GREEN}Fcitx5和Rime输入法配置完成${NC}"
}

# 卸载现有输入法
remove_existing_input_methods() {
    echo -e "${BLUE}检测到系统中可能存在其他输入法，需要先卸载它们...${NC}"
    echo -e "${RED}警告: 即将卸载ibus、fcitx和fcitx5（如果存在）${NC}"
    read -p "是否继续？[y/N] " response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}开始卸载现有输入法...${NC}"
        apt remove -y ibus ibus-* fcitx* > /dev/null 2>&1
        apt autoremove -y > /dev/null 2>&1
        echo -e "${GREEN}现有输入法已卸载${NC}"
    else
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
}

# 提示重启
prompt_restart() {
    echo -e "${RED}重要: 需要重启系统才能使更改生效${NC}"
    read -p "是否现在重启系统？[y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}系统将在5秒后重启...${NC}"
        sleep 5
        reboot
    else
        echo -e "${BLUE}请记得稍后重启系统以使更改生效${NC}"
    fi
}

# 安装雾凇拼音输入法
install_rime() {
    echo -e "${GREEN}开始安装雾凇拼音输入法...${NC}"
    
    # 检查root权限
    check_root
    
    # 获取真实用户信息
    get_real_user_info
    
    # 检查桌面环境
    check_desktop_environment
    
    # 更新软件包列表
    echo -e "${GREEN}更新软件包列表...${NC}"
    apt update
    
    # 卸载现有输入法
    remove_existing_input_methods
    
    # 安装必要的包
    if ! install_packages; then
        echo -e "${RED}安装必要的包失败，退出安装${NC}"
        exit 1
    fi

    # 创建配置目录
    echo -e "${GREEN}创建配置目录...${NC}"
    RIME_DIR="$REAL_HOME/.local/share/fcitx5/rime"
    mkdir -p "$RIME_DIR"
    
    # 下载雾凇拼音配置
    echo -e "${GREEN}下载雾凇拼音配置...${NC}"
    if ! git_clone_with_retry "https://github.com/cogitate3/rime-ice" "$RIME_DIR/rime-ice-tmp"; then
        echo -e "${RED}下载配置失败${NC}"
        exit 1
    fi

    # 复制配置文件
    echo -e "${GREEN}复制配置文件...${NC}"
    cp -r "$RIME_DIR/rime-ice-tmp"/* "$RIME_DIR/"
    rm -rf "$RIME_DIR/rime-ice-tmp"

    # 配置Fcitx5和Rime输入法
    configure_fcitx5_rime

    # 设置权限
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.local"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config"

    echo -e "${GREEN}安装完成!${NC}"
    prompt_restart
}

# 卸载雾凇拼音输入法
uninstall_rime() {
    echo -e "${GREEN}开始卸载雾凇拼音输入法...${NC}"
    
    # 检查root权限
    check_root
    
    # 获取真实用户信息
    get_real_user_info
    
    # 卸载相关软件包
    echo -e "${BLUE}卸载相关软件包...${NC}"
    apt remove -y --purge \
        fcitx5 \
        fcitx5-rime \
        fcitx5-chinese-addons \
        fcitx5-frontend-gtk2 \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-qt5 \
        fcitx5-module-cloudpinyin \
        qt5-style-plugins \
        fcitx5-module-lua \
        fcitx5-material-color
    
    apt autoremove -y

    # 清理配置文件
    echo -e "${BLUE}清理配置文件...${NC}"
    rm -rf "$REAL_HOME/.local/share/fcitx5"
    rm -rf "$REAL_HOME/.config/fcitx5"
    rm -f "$REAL_HOME/.config/autostart/fcitx5.desktop"
    rm -f "$REAL_HOME/.config/environment.d/99-fcitx5.conf"
    
    # 清理环境变量配置
    echo -e "${BLUE}清理环境变量配置...${NC}"
    sed -i '/# Fcitx5 input method/d' "$REAL_HOME/.profile"
    sed -i '/^export GTK_IM_MODULE=fcitx/d' "$REAL_HOME/.profile"
    sed -i '/^export QT_IM_MODULE=fcitx/d' "$REAL_HOME/.profile"
    sed -i '/^export XMODIFIERS=@im=fcitx/d' "$REAL_HOME/.profile"
    sed -i '/^export INPUT_METHOD=fcitx/d' "$REAL_HOME/.profile"
    sed -i '/^export SDL_IM_MODULE=fcitx/d' "$REAL_HOME/.profile"

    echo -e "${GREEN}卸载完成！${NC}"
    prompt_restart
}

# 主函数
main() {
    case "$1" in
        "install")
            install_rime
            ;;
        "uninstall")
            uninstall_rime
            ;;
        *)
            echo -e "${RED}用法: sudo bash $0 install|uninstall${NC}"
            exit 1
            ;;
    esac
}

# 仅在直接执行脚本时运行main函数，被source时不运行
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi