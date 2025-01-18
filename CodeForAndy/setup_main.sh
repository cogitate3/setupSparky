#!/bin/bash

# Source the setup_from_github.sh file to use its functions
source "$(dirname "$0")/setup_from_github.sh"

# Set up logging
log "$HOME/logs/$(basename "$0").log" 1 "Starting setup menu"

# 定义软件安装函数数组
declare -A apps=(
    ["1"]="WaveTerm|https://github.com/wavetermdev/waveterm/releases|-amd64.*\.deb$|waveterm"
    ["2"]="Stretchly|https://github.com/hovancik/stretchly/releases|.*amd64\.deb$|stretchly"
    ["3"]="AB Download Manager|https://github.com/amir1376/ab-download-manager/releases|.*linux_x64.*\.deb$|ab-download-manager"
    ["4"]="LocalSend|https://github.com/localsend/localsend/releases|.*linux-x86-64.*\.deb$|localsend"
    ["5"]="Tabby Terminal|https://github.com/Eugeny/tabby/releases|.*linux-x64.*\.deb$|tabby"
    ["6"]="OpenAI Translator|https://github.com/openai-translator/openai-translator/releases|.*amd64\.deb$|openai-translator"
)

# 显示菜单函数
show_menu() {
    echo -e "\n=== 软件安装菜单 ==="
    echo "0. 退出"
    for key in "${!apps[@]}"; do
        IFS='|' read -r name url pattern pkg_name <<< "${apps[$key]}"
        echo "$key. 安装 $name"
    done
    echo "a. 安装所有软件"
    echo -e "================="
}

# 安装指定软件
install_app() {
    local key="$1"
    if [[ -n "${apps[$key]}" ]]; then
        IFS='|' read -r name url pattern pkg_name <<< "${apps[$key]}"
        log 1 "开始安装 $name..."
        setup_from_github "$url" "$pattern" "install" "$pkg_name"
    fi
}

# 安装所有软件
install_all() {
    log 1 "开始安装所有软件..."
    for key in "${!apps[@]}"; do
        install_app "$key"
    done
    log 1 "所有软件安装完成"
}

# 主循环
while true; do
    show_menu
    read -p "请选择要安装的软件 (0-6, a 安装所有, q 退出): " choice
    
    case "$choice" in
        0|q|Q)
            log 1 "退出安装程序"
            exit 0
            ;;
        [1-6])
            install_app "$choice"
            ;;
        a|A)
            install_all
            ;;
        *)
            echo "无效的选择，请重试"
            ;;
    esac
    
    # 等待用户按回车继续
    read -p "按回车键继续..."
done
