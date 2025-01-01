#!/bin/bash

# 显示使用方法
show_usage() {
    echo "用法: $0 [install|uninstall]"
    echo "示例:"
    echo "  安装 fcitx5:   $0 install"
    echo "  卸载 fcitx5:   $0 uninstall"
    exit 1
}

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 检查参数
if [ $# -ne 1 ]; then
    show_usage
fi

# 获取当前登录用户
CURRENT_USER=${SUDO_USER:-$(whoami)}
USER_HOME="/home/$CURRENT_USER"

# 卸载功能
uninstall_fcitx5() {
    echo "开始卸载 fcitx5 输入法..."

    # 1. 停止 fcitx5 服务
    echo "停止 fcitx5 服务..."
    pkill fcitx5 2>/dev/null

    # 2. 卸载所有 fcitx5 相关包
    echo "卸载 fcitx5 相关软件包..."
    apt remove --purge -y \
        fcitx5 \
        fcitx5-chinese-addons \
        fcitx5-frontend-qt5 \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-gtk4 \
        fcitx5-config-qt \
        kde-config-fcitx5 \
        fcitx5-rime

    # 清理依赖
    apt autoremove -y

    # 3. 删除配置文件和目录
    echo "删除配置文件..."

    # 删除系统级配置
    if [ -f "/etc/environment" ]; then
        # 备份原始文件
        cp /etc/environment /etc/environment.bak
        # 删除 fcitx5 相关的环境变量
        sed -i '/GTK_IM_MODULE=fcitx/d' /etc/environment
        sed -i '/QT_IM_MODULE=fcitx/d' /etc/environment
        sed -i '/XMODIFIERS=@im=fcitx/d' /etc/environment
        sed -i '/SDL_IM_MODULE=fcitx/d' /etc/environment
    fi

    # 删除自启动配置
    if [ -f "$USER_HOME/.config/autostart/fcitx5.desktop" ]; then
        rm -f "$USER_HOME/.config/autostart/fcitx5.desktop"
    fi

    # 删除 fcitx5 配置目录
    if [ -d "$USER_HOME/.config/fcitx5" ]; then
        rm -rf "$USER_HOME/.config/fcitx5"
    fi

    # 删除 Rime 配置目录
    if [ -d "$USER_HOME/.local/share/fcitx5" ]; then
        rm -rf "$USER_HOME/.local/share/fcitx5"
    fi

    # 删除词库
    if [ -d "/usr/share/fcitx5" ]; then
        rm -rf /usr/share/fcitx5
    fi

    # 4. 清理环境变量
    if [ -f "$USER_HOME/.bashrc" ]; then
        sed -i '/GTK_IM_MODULE=fcitx/d' "$USER_HOME/.bashrc"
        sed -i '/QT_IM_MODULE=fcitx/d' "$USER_HOME/.bashrc"
        sed -i '/XMODIFIERS=@im=fcitx/d' "$USER_HOME/.bashrc"
        sed -i '/SDL_IM_MODULE=fcitx/d' "$USER_HOME/.bashrc"
    fi

    echo "fcitx5 输入法已完全卸载。建议重启系统以确保所有更改生效。"
}

# 安装功能
install_fcitx5() {
    echo "开始配置中文输入法..."

    # 1. 检测并卸载 IBus
    if dpkg -l | grep -qw "ibus"; then
        echo "检测到 IBus，正在卸载..."
        apt remove --purge -y ibus ibus-*
        apt autoremove -y
        echo "IBus 已卸载"
    fi

    # 2. 安装 fcitx5 及相关包
    echo "正在安装 fcitx5 及相关包..."
    apt update -qq
    apt install -y -qq \
        fcitx5 \
        fcitx5-chinese-addons \
        fcitx5-frontend-qt5 \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-gtk4 \
        fcitx5-config-qt \
        kde-config-fcitx5 \
        fcitx5-rime \
        wget

    # 3. 配置环境变量
    echo "配置环境变量..."
    # 定义要添加的环境变量
    ENV_VARS="GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx"

    # 检查并追加
    echo "$ENV_VARS" | while read -r line; do
        if ! grep -Fxq "$line" /etc/environment; then
            echo "$line" >> /etc/environment
        fi
    done

    # 4. 创建自启动配置
    echo "配置自动启动..."
    mkdir -p "$USER_HOME/.config/autostart"
    cat > "$USER_HOME/.config/autostart/fcitx5.desktop" <<EOF
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

    # 修改文件所有权
    chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/autostart/fcitx5.desktop"

    # 5. 配置默认输入法
    mkdir -p "$USER_HOME/.config/fcitx5/profile"
    cat > "$USER_HOME/.config/fcitx5/profile/default" <<EOF
[Groups/0]
# Group Name
Name=默认
# Layout
Default Layout=us
# Default Input Method
DefaultIM=pinyin

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=pinyin
# Layout
Layout=

[Groups/0/Items/2]
# Name
Name=rime
# Layout
Layout=

[GroupOrder]
0=默认
EOF

    # 6. 下载并安装自定义拼音词库
    echo "正在安装自定义拼音词库..."
    CUSTOM_PINYIN_URL="https://github.com/wuhgit/CustomPinyinDictionary/releases/download/assets/CustomPinyinDictionary_Fcitx_20240824.tar.gz"
    TEMP_DIR=$(mktemp -d)
    if ! wget -P "$TEMP_DIR" "$CUSTOM_PINYIN_URL"; then
        echo "下载自定义拼音词库失败，请检查网络连接或 URL 是否正确。"
        exit 1
    fi
    tar -xzf "$TEMP_DIR/CustomPinyinDictionary_Fcitx_20240824.tar.gz" -C "$TEMP_DIR"
    mkdir -p /usr/share/fcitx5/pinyin/dictionaries/
    cp "$TEMP_DIR/CustomPinyinDictionary_Fcitx.dict" /usr/share/fcitx5/pinyin/dictionaries/
    rm -rf "$TEMP_DIR"

    # 7. 配置 Rime 输入法
    echo "配置 Rime 输入法..."
    mkdir -p "$USER_HOME/.local/share/fcitx5/rime"

    # 配置默认设置
    cat > "$USER_HOME/.local/share/fcitx5/rime/default.custom.yaml" <<EOF
patch:
  schema_list:
    - schema: luna_pinyin_simp
    - schema: luna_pinyin
  menu:
    page_size: 7
  switches:
    - name: ascii_mode
      reset: 0
      states: ["中文", "西文"]
    - name: full_shape
      states: ["半角", "全角"]
    - name: simplification
      reset: 1
      states: ["漢字", "汉字"]
    - name: ascii_punct
      states: ["。，", "．，"]
  style:
    horizontal: true
EOF

    # 配置简体拼音方案的模糊音
    cat > "$USER_HOME/.local/share/fcitx5/rime/luna_pinyin_simp.custom.yaml" <<EOF
patch:
  speller:
    algebra:
      - erase/^xx$/
      - derive/^([zcs])h/$1/
      - derive/^([zcs])([^h])/$1h$2/
      - derive/in$/ing/
      - derive/ing$/in/
      - derive/^n/l/
      - derive/^l/n/
EOF

    # 修改 Rime 配置文件所有权
    chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.local/share/fcitx5/rime"

    # 修改配置文件所有权
    chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fcitx5"

    echo "配置完成！请重启系统以应用更改。重启后首次运行 Rime 时会自动部署配置文件，可能需要等待几分钟。"
}

# 主程序
case "$1" in
    install)
        install_fcitx5
        ;;
    uninstall)
        uninstall_fcitx5
        ;;
    *)
        show_usage
        ;;
esac