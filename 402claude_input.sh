#!/bin/bash

# 设置错误时退出
set -e

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}开始安装 Rime 输入法...${NC}"

# 更新系统包列表
echo "更新系统包列表..."
apt update

# 安装必要的包
echo "安装必要的软件包..."
apt install -y --install-recommends \
    git \
    rime-data \
    fcitx5 \
    fcitx5-rime \
    fcitx5-chinese-addons \
    fcitx5-frontend-gtk2 \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-qt5 \
    fcitx5-module-cloudpinyin \
    qt5-style-plugins \
    zenity \
    kde-config-fcitx5 \
    fcitx5-module-lua \
    fcitx5-material-color

# 创建配置目录
echo "创建配置目录..."
mkdir -p ~/.local/share/fcitx5/rime
cd ~/.local/share/fcitx5/rime

# 选择配置方案
echo -e "${BLUE}请选择配置方案：${NC}"
echo "1) 雾凇拼音（推荐，词库大而精准）"
echo "2) lifedever's Rime（完整配置）"
read -p "请输入选择（1 或 2）: " choice

case $choice in
    1)
        echo "下载雾凇拼音配置..."
        if [ -d "rime-ice" ]; then
            rm -rf rime-ice
        fi
        git clone --depth=1 https://github.com/iDvel/rime-ice.git
        cp -r rime-ice/* ./
        rm -rf rime-ice
        ;;
    2)
        echo "下载 lifedever's Rime 配置..."
        if [ -d "rime-config" ]; then
            rm -rf rime-config
        fi
        git clone --depth=1 https://github.com/lifedever/rime.git rime-config
        cp -r rime-config/* ./
        rm -rf rime-config
        ;;
    *)
        echo -e "${RED}无效的选择，使用默认的雾凇拼音配置...${NC}"
        git clone --depth=1 https://github.com/iDvel/rime-ice.git
        cp -r rime-ice/* ./
        rm -rf rime-ice
        ;;
esac

# 设置 fcitx5 为默认输入法
echo "配置系统环境变量..."
cat > /etc/environment << EOL
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOL

# 创建配置目录
mkdir -p ~/.config/fcitx5/conf

# 配置 Material Color 主题
echo "配置 Material Color 主题..."
cat > ~/.config/fcitx5/conf/classicui.conf << EOL
# 垂直候选列表
Vertical Candidate List=False

# 按屏幕 DPI 使用
PerScreenDPI=True

# Font (设置字体)
Font="Sans 13"

# 主题
Theme=Material-Color-Pink
EOL

# 启用云拼音
echo "配置云拼音..."
cat > ~/.config/fcitx5/conf/cloudpinyin.conf << EOL
# 启用云拼音
Enabled=True
# 云拼音来源
Source=Baidu
# 最小拼音长度
MinimumPinyinLength=2
EOL

# 启动 fcitx5
echo "启动输入法服务..."
killall fcitx5 2>/dev/null || true
fcitx5 -d

echo -e "${GREEN}安装完成！${NC}"
echo "请注意："
echo "1. 需要重新登录系统使环境变量生效"
echo "2. 首次使用需要等待词库部署，可能需要几分钟时间"
echo "3. 可以使用 Ctrl + \` 切换输入方案"
echo "4. 已启用 Material Color Pink 主题，可在设置中更改其他颜色"
echo "5. 已启用云拼音功能，可以在设置中调整"

if [ "$choice" = "2" ]; then
    echo "6. 您选择了 lifedever's Rime 配置，具体使用方法请参考："
    echo "   https://github.com/lifedever/rime"
fi