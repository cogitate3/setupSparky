#!/bin/bash

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 获取当前登录用户
CURRENT_USER=$(logname)
USER_HOME="/home/$CURRENT_USER"

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
apt update
apt install -y \
    fcitx5 \
    fcitx5-chinese-addons \
    fcitx5-pinyin \
    fcitx5-rime \
    fcitx5-frontend-qt5 \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-config-qt \
    kde-config-fcitx5

# 3. 配置环境变量
echo "配置环境变量..."
cat > /etc/environment <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

# 4. 创建自启动配置
echo "配置自动启动..."
mkdir -p $USER_HOME/.config/autostart
cat > $USER_HOME/.config/autostart/fcitx5.desktop <<EOF
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
chown $CURRENT_USER:$CURRENT_USER $USER_HOME/.config/autostart/fcitx5.desktop

# 5. 配置默认输入法
mkdir -p $USER_HOME/.config/fcitx5/profile
cat > $USER_HOME/.config/fcitx5/profile/default <<EOF
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

[GroupOrder]
0=默认
EOF

# 修改配置文件所有权
chown -R $CURRENT_USER:$CURRENT_USER $USER_HOME/.config/fcitx5

echo "配置完成！请重启系统以应用更改。"