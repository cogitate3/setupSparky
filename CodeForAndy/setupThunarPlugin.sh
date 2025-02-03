#!/bin/bash
# 一键安装 Thunar 插件的脚本
# 本脚本支持 apt-get、dnf 和 pacman 包管理器
# Bulk Renamer 和 Custom Actions 已内建于 Thunar，无需安装

set -e

# 判断使用的包管理器
if command -v apt-get >/dev/null 2>&1; then
    PM="apt-get"
    INSTALL="sudo apt-get install -y"
    UPDATE="sudo apt-get update"
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
    INSTALL="sudo dnf install -y"
    UPDATE="sudo dnf check-update"
elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"
    INSTALL="sudo pacman -S --noconfirm"
    UPDATE="sudo pacman -Sy"
else
    echo "未检测到支持的包管理器，请手动安装插件。"
    exit 1
fi

echo "使用的包管理器：$PM"
echo "更新软件包列表..."
$UPDATE

# 根据不同包管理器定义要安装的插件包名
case "$PM" in
    apt-get|dnf)
        PLUGINS="thunar-archive-plugin thunar-media-tags-plugin thunar-shares-plugin thunar-volman thunar-vcs-plugin"
        ;;
    pacman)
        # 在 Arch/Manjaro 系统中，这些插件一般在 xfce4-goodies 包组中提供，
        # 如有单独包可修改下面的包名
        PLUGINS="thunar-archive-plugin thunar-media-tags-plugin thunar-shares-plugin thunar-volman thunar-vcs-plugin"
        ;;
    *)
        echo "未知的包管理器类型"
        exit 1
        ;;
esac

echo "安装 Thunar 插件：$PLUGINS"
$INSTALL $PLUGINS

echo "======================================"
echo "安装完成！"
echo "注意：Bulk Renamer 和 Custom Actions 已内建于 Thunar。"
echo "======================================"
