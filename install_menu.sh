#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        1) echo -e "${GREEN}[INFO] $timestamp - $message${NC}" ;;
        2) echo -e "${YELLOW}[WARN] $timestamp - $message${NC}" ;;
        3) echo -e "${RED}[ERROR] $timestamp - $message${NC}" ;;
        *) echo -e "${BLUE}[DEBUG] $timestamp - $message${NC}" ;;
    esac
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}==================================="
    echo "Linux 软件安装/卸载菜单"
    echo "===================================${NC}"
    
    echo -e "${YELLOW}1. 桌面系统增强必备${NC}"
    echo "   1) Plank 快捷启动器"
    echo "   2) fSearch 快速查找工具"
    echo "   3) Pot-desktop 翻译工具"
    echo "   4) Geany 文本编辑器"
    echo "   5) stretchly 定时休息工具"
    echo "   6) AB Download Manager 下载工具"
    echo "   7) LocalSend 局域网传输工具"
    echo "   8) WPS Office 办公软件"
    
    echo -e "${YELLOW}2. 桌面系统进阶常用软件${NC}"
    echo "   10) Tabby 终端"
    echo "   11) Telegram 聊天软件"
    echo "   12) Brave 浏览器"
    echo "   13) VLC 视频播放器"
    echo "   14) Windsurf IDE 编程工具"
    echo "   15) PDF Arranger PDF编辑器"
    echo "   16) Warp Terminal 终端"
    
    echo -e "${YELLOW}3. 命令行增强工具${NC}"
    echo "   20) Neofetch 系统信息工具"
    echo "   21) micro 命令行编辑器"
    echo "   22) cheat.sh 命令示例工具"
    echo "   23) eg 命令示例工具"
    echo "   24) eggs 系统备份工具"
    echo "   25) 按两次Esc键加sudo"
    echo "   26) zsh和oh-my-zsh增强"
    
    echo -e "${YELLOW}4. 软件库工具${NC}"
    echo "   30) Docker 和 Docker Compose"
    echo "   31) Snap 和 Snapstore"
    echo "   32) Flatpak 软件库"
    echo "   33) Homebrew 软件库"
    
    echo -e "${YELLOW}5. 批量操作${NC}"
    echo "   40) 一键安装全部软件"
    
    echo -e "${YELLOW}0. 退出${NC}"
}

# 安装单个软件
install_single() {
    source ./901afterLinuxInstall.sh
    case $1 in
        1) install_plank ;;
        2) setup_fsearch install ;;
        3) install_pot_desktop ;;
        4) install_geany ;;
        5) install_stretchly ;;
        6) install_ab_download_manager ;;
        7) install_localsend ;;
        8) install_wps ;;
        10) install_tabby ;;
        11) install_telegram ;;
        12) install_brave ;;
        13) install_VLC ;;
        14) install_windsurf ;;
        15) install_pdfarranger ;;
        16) install_warp_terminal ;;
        20) install_neofetch ;;
        21) install_micro ;;
        22) install_cheatsh ;;
        23) install_eg ;;
        24) install_eggs ;;
        25) install_double_esc_sudo ;;
        26) sudo bash "$(dirname "$0")/009install_zsh_omz.sh" install ;;
        30) install_docker_and_docker_compose ;;
        31) install_snap ;;
        32) install_flatpak ;;
        33) install_homebrew ;;
        *) log 3 "无效的选项" ;;
    esac
}

# 卸载单个软件
uninstall_single() {
    source ./901afterLinuxInstall.sh
    case $1 in
        1) uninstall_plank ;;
        2) uninstall_angrysearch ;;
        3) uninstall_pot_desktop ;;
        4) uninstall_geany ;;
        5) uninstall_stretchly ;;
        6) uninstall_ab_download_manager ;;
        7) uninstall_localsend ;;
        8) uninstall_wps ;;
        10) uninstall_tabby ;;
        11) uninstall_telegram ;;
        12) uninstall_brave ;;
        13) uninstall_VLC ;;
        14) uninstall_windsurf ;;
        15) uninstall_pdfarranger ;;
        16) uninstall_warp_terminal ;;
        20) uninstall_neofetch ;;
        21) uninstall_micro ;;
        22) uninstall_cheatsh ;;
        23) uninstall_eg ;;
        24) uninstall_eggs ;;
        25) uninstall_double_esc_sudo ;;
        26) sudo bash "$(dirname "$0")/009install_zsh_omz.sh" uninstall ;;
        30) uninstall_docker_and_docker_compose ;;
        31) uninstall_snap ;;
        32) uninstall_flatpak ;;
        33) uninstall_homebrew ;;
        *) log 3 "无效的选项" ;;
    esac
}

# 主菜单
main_menu() {
    while true; do
        show_menu
        read -p "请输入选项编号（安装直接输入数字，卸载输入数字+100，如101）：" choice
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -lt 100 ]]; then
            if [[ $choice -eq 40 ]]; then
                # 批量安装所有软件
                for i in {1..8} {10..16} {20..26} {30..33}; do
                    install_single $i
                done
            else
                install_single $choice
            fi
        else
            uninstall_choice=$((choice - 100))
            uninstall_single $uninstall_choice
        fi
        
        read -p "按Enter键继续..."
    done
}

# 执行主菜单
main_menu
