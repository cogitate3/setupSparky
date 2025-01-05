#!/bin/

# 作为函数引用sudo bash -c 'source /path/to/script.sh; install_fonts'
# 作为脚本直接运行bash /path/to/script.sh

# 颜色函数
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}

install_fonts() {
    # 检查是否有sudo权限
    if [ "$EUID" -ne 0 ]; then 
        red "错误: 需要sudo权限"
        yellow "请使用: sudo bash -c 'source ${BASH_SOURCE[0]}; install_fonts'"
        return 1
    fi

    green "=== Debian/Ubuntu 字体安装脚本 ==="
    green "准备安装以下字体:"
    green "- JetBrains Mono, Cascadia Code (编程字体)"
    green "- Hack, Source Sans 3, FiraCode (编程字体)"
    green "- LXGW WenKai, WQY (中文字体)"
    green "- Noto CJK, Noto Mono (CJK字体)"
    echo 

    # 更新包列表
    blue "步骤1: 更新包列表..."
    apt update || {
        red "错误: 更新包列表失败"
        return 1
    }

    # 安装字体
    blue "步骤2: 安装字体包..."
    apt install -y --install-recommends \
        fnt \
        fonts-jetbrains-mono fonts-cascadia-code \
        fonts-hack-otf fonts-hack-ttf fonts-adobe-sourcesans3 \
        fonts-lxgw-wenkai fonts-wqy-microhei fonts-wqy-zenhei \
        fonts-noto-cjk-extra fonts-noto-mono fonts-firacode || {
            red "错误: 字体安装失败"
            return 1
        }

    # 刷新字体缓存
    blue "步骤3: 更新字体缓存..."
    fc-cache -f -v

    echo 
    green "=== 安装完成 ==="
    green "所有字体已成功安装！"
    yellow "你可能需要重启应用程序来使用新安装的字体。"
    echo 
    green "=== fnt 命令使用指南 ==="
    green "fnt 是一个简单的字体管理工具，以下是常用命令："
    echo
    bold "1. 列出所有已安装的字体："
    blue "   fnt list"
    echo
    bold "2. 搜索特定字体："
    blue "   fnt search JetBrains    # 搜索包含JetBrains的字体"
    blue "   fnt search '文楷'       # 搜索中文字体"
    echo
    bold "3. 查看字体详细信息："
    blue "   fnt info '文楷'         # 查看特定字体信息"
    blue "   fnt info -a             # 查看所有字体详细信息"
    echo
    bold "4. 预览字体："
    blue "   fnt sample '文楷'       # 预览特定字体"
    blue "   fnt sample -a           # 预览所有字体"
    echo
    yellow "提示：可以使用 'fnt --help' 查看更多命令选项"
    green "================================================================"
    return 0
}

# 如果是直接运行脚本，显示正确的使用方法
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$EUID" -ne 0 ]; then
        red "请使用以下命令运行:"
        yellow "sudo bash -c 'source ${BASH_SOURCE[0]}; install_fonts'"
        exit 1
    else
        # 如果已经是root权限，直接运行
        install_fonts
    fi
fi