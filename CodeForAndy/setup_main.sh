#!/bin/bash

# Source the setup_from_github.sh file to use its functions
source "$(dirname "$0")/setup_from_github.sh"

# Set up logging
log "$HOME/logs/$(basename "$0").log" 1 "Starting setup menu"
log 1 "安装日志记录在${CURRENT_LOG_FILE}"

# 定义颜色变量
GREEN="${COLORS[green]}"
RESET="${COLORS[reset]}"

# 定义软件名称数组（保持顺序）
app_names=(
    "WaveTerm"
    "Stretchly"
    "AB Download Manager"
    "LocalSend"
    "Tabby Terminal"
    "OpenAI Translator"
)

# 定义对应的URL数组
app_urls=(
    "https://github.com/wavetermdev/waveterm/releases"
    "https://github.com/hovancik/stretchly/releases"
    "https://github.com/amir1376/ab-download-manager/releases"
    "https://github.com/localsend/localsend/releases"
    "https://github.com/Eugeny/tabby/releases"
    "https://github.com/openai-translator/openai-translator/releases"
)

# 定义对应的匹配模式数组
app_patterns=(
    "-amd64.*\.deb$"
    ".*amd64\.deb$"
    ".*linux_x64.*\.deb$"
    ".*linux-x86-64.*\.deb$"
    ".*linux-x64.*\.deb$"
    ".*amd64\.deb$"
)

# 定义对应的包名数组
app_pkgnames=(
    "waveterm"
    "stretchly"
    "abdownloadmanager"
    "localsend"
    "tabby"
    "open-ai-translator"
)

# 显示主菜单
show_main_menu() {
    echo -e "\n${GREEN}=== 主菜单 ===${RESET}"
    echo -e "${GREEN}1. 安装软件${RESET}"
    echo -e "${GREEN}2. 卸载软件${RESET}"
    echo -e "${GREEN}0. 退出程序${RESET}"
    echo -e "${GREEN}=================${RESET}"
}

# 显示安装菜单
show_install_menu() {
    echo -e "\n${GREEN}=== 软件安装菜单 ===${RESET}"
    echo -e "${GREEN}0. 返回主菜单${RESET}"
    for i in "${!app_names[@]}"; do
        echo -e "${GREEN}$((i+1)). 安装 ${app_names[$i]}${RESET}"
    done
    echo -e "${GREEN}a. 安装所有软件${RESET}"
    echo -e "${GREEN}=================${RESET}"
}

# 显示卸载菜单
show_uninstall_menu() {
    echo -e "\n${GREEN}=== 软件卸载菜单 ===${RESET}"
    echo -e "${GREEN}0. 返回主菜单${RESET}"
    for i in "${!app_names[@]}"; do
        echo -e "${GREEN}$((i+1)). 卸载 ${app_names[$i]}${RESET}"
    done
    echo -e "${GREEN}a. 卸载所有软件${RESET}"
    echo -e "${GREEN}=================${RESET}"
}

# 安装指定软件
install_app() {
    local index="$1"
    # 将选项数字转换为数组索引
    index=$((index-1))
    
    if [ "$index" -ge 0 ] && [ "$index" -lt "${#app_names[@]}" ]; then
        log 1 "开始安装 ${app_names[$index]}..."
        setup_from_github "${app_urls[$index]}" "${app_patterns[$index]}" "install" "${app_pkgnames[$index]}"
    fi
}

# 卸载指定软件
uninstall_app() {
    local index="$1"
    # 将选项数字转换为数组索引
    index=$((index-1))
    
    if [ "$index" -ge 0 ] && [ "$index" -lt "${#app_names[@]}" ]; then
        log 1 "开始卸载 ${app_names[$index]}..."
        setup_from_github "uninstall" "${app_pkgnames[$index]}"
    fi
}

# 安装所有软件
install_all() {
    log 1 "开始安装所有软件..."
    for i in "${!app_names[@]}"; do
        log 1 "开始安装 ${app_names[$i]}..."
        setup_from_github "${app_urls[$i]}" "${app_patterns[$i]}" "install" "${app_pkgnames[$i]}"
    done
    log 1 "所有软件安装完成"
}

# 卸载所有软件
uninstall_all() {
    log 1 "开始卸载所有软件..."
    for i in "${!app_names[@]}"; do
        log 1 "开始卸载 ${app_names[$i]}..."
        setup_from_github "uninstall" "${app_pkgnames[$i]}"
    done
    log 1 "所有软件卸载完成"
}

# 处理安装菜单
handle_install_menu() {
    while true; do
        show_install_menu
        read -p "请选择要安装的软件 (0-${#app_names[@]}, a 安装所有): " choice
        
        case "$choice" in
            0)
                return
                ;;
            [1-9])
                if [ "$choice" -le "${#app_names[@]}" ]; then
                    install_app "$choice"
                else
                    echo "无效的选择，请重试"
                fi
                ;;
            a|A)
                install_all
                ;;
            *)
                echo "无效的选择，请重试"
                ;;
        esac
        
        read -p "按回车键继续..."
    done
}

# 处理卸载菜单
handle_uninstall_menu() {
    while true; do
        show_uninstall_menu
        read -p "请选择要卸载的软件 (0-${#app_names[@]}, a 卸载所有): " choice
        
        case "$choice" in
            0)
                return
                ;;
            [1-9])
                if [ "$choice" -le "${#app_names[@]}" ]; then
                    uninstall_app "$choice"
                else
                    echo "无效的选择，请重试"
                fi
                ;;
            a|A)
                uninstall_all
                ;;
            *)
                echo "无效的选择，请重试"
                ;;
        esac
        
        read -p "按回车键继续..."
    done
}

# 主循环
while true; do
    show_main_menu
    read -p "请选择操作 (0-2): " choice
    
    case "$choice" in
        0)
            log 1 "退出程序"
            exit 0
            ;;
        1)
            handle_install_menu
            ;;
        2)
            handle_uninstall_menu
            ;;
        *)
            echo "无效的选择，请重试"
            ;;
    esac
done
