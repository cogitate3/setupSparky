#!/bin/bash

# Source all required scripts
source "$(dirname "$0")/001log2File.sh"
source "$(dirname "$0")/003get_download_link.sh"
source "$(dirname "$0")/004detect_install_cmd.sh"
source "$(dirname "$0")/005get_fonts.sh"
source "$(dirname "$0")/006double-Esc-to-sudo.sh"
source "$(dirname "$0")/007setupDavfs2.sh"
source "$(dirname "$0")/008setup_sshfs.sh"
source "$(dirname "$0")/009setup_zsh.sh"
source "$(dirname "$0")/011x_cmd_manager.sh"
source "$(dirname "$0")/901afterLinuxInstall.sh"

# Main installation function
install_all_packages() {
    # Create log file
    local log_file="/tmp/install_all_$(date '+%Y%m%d_%H%M%S').log"
    # 设置日志文件
    log "$log_file" 1 "开始全面安装过程..."

    # Check root privileges
    check_root

    # Install base dependencies
    log 1 "正在安装基础依赖..."
    check_and_install_dependencies "jq" "git" "curl" "wget" "sudo"

    # Install fonts
    log 1 "开始安装字体..."
    if install_fonts; then
        log 1 "字体安装成功"
    else
        log 3 "字体安装失败"
    fi

    # Install x-cmd
    log 1 "开始安装X-CMD..."
    if x_cmd_manager install; then
        log 1 "X-CMD安装成功"
    else
        log 3 "X-CMD安装失败"
    fi

    # Install double-ESC to sudo functionality
    log 1 "开始配置双击ESC转换为sudo功能..."
    if install_double_esc_sudo; then
        log 1 "双击ESC功能配置成功"
    else
        log 3 "双击ESC功能配置失败"
    fi

    # Setup davfs2
    log 1 "开始安装davfs2..."
    if install_davfs2; then
        log 1 "davfs2安装成功"
    else
        log 3 "davfs2安装失败"
    fi

    # Setup SSHFS
    log 1 "开始安装SSHFS..."
    if install_sshfs; then
        log 1 "SSHFS安装成功"
    else
        log 3 "SSHFS安装失败"
    fi

    # Desktop Enhancements
    log 1 "开始安装桌面增强工具..."

    log 1 "正在安装Plank..."
    if install_plank; then
        log 1 "Plank安装成功"
    else
        log 3 "Plank安装失败"
    fi

    log 1 "正在安装AngrySearch..."
    if install_angrysearch; then
        log 1 "AngrySearch安装成功"
    else
        log 3 "AngrySearch安装失败"
    fi

    log 1 "正在安装Pot Desktop..."
    if install_pot_desktop; then
        log 1 "Pot Desktop安装成功"
    else
        log 3 "Pot Desktop安装失败"
    fi

    log 1 "正在安装Geany..."
    if install_geany; then
        log 1 "Geany安装成功"
    else
        log 3 "Geany安装失败"
    fi

    log 1 "正在安装Stretchly..."
    if install_stretchly; then
        log 1 "Stretchly安装成功"
    else
        log 3 "Stretchly安装失败"
    fi

    # File Management and Transfer Tools
    log 1 "开始安装文件管理工具..."

    log 1 "正在安装AB Download Manager..."
    if install_ab_download_manager; then
        log 1 "AB Download Manager安装成功"
    else
        log 3 "AB Download Manager安装失败"
    fi

    log 1 "正在安装LocalSend..."
    if install_localsend; then
        log 1 "LocalSend安装成功"
    else
        log 3 "LocalSend安装失败"
    fi

    log 1 "正在安装SpaceFM..."
    if install_spacefm; then
        log 1 "SpaceFM安装成功"
    else
        log 3 "SpaceFM安装失败"
    fi

    log 1 "正在安装Krusader..."
    if install_krusader; then
        log 1 "Krusader安装成功"
    else
        log 3 "Krusader安装失败"
    fi

    # Terminal and Development Tools
    log 1 "开始安装终端和开发工具..."

    log 1 "正在安装Konsole..."
    if install_konsole; then
        log 1 "Konsole安装成功"
    else
        log 3 "Konsole安装失败"
    fi

    log 1 "正在安装Tabby..."
    if install_tabby; then
        log 1 "Tabby安装成功"
    else
        log 3 "Tabby安装失败"
    fi

    log 1 "正在安装Windsurf IDE..."
    if install_windsurf; then
        log 1 "Windsurf IDE安装成功"
    else
        log 3 "Windsurf IDE安装失败"
    fi

    # Internet and Communication
    log 1 "开始安装网络和通讯工具..."

    log 1 "正在安装Telegram..."
    if install_telegram; then
        log 1 "Telegram安装成功"
    else
        log 3 "Telegram安装失败"
    fi

    log 1 "正在安装Brave浏览器..."
    if install_brave; then
        log 1 "Brave浏览器安装成功"
    else
        log 3 "Brave浏览器安装失败"
    fi

    # Multimedia
    log 1 "开始安装多媒体工具..."

    log 1 "正在安装VLC..."
    if install_VLC; then
        log 1 "VLC安装成功"
    else
        log 3 "VLC安装失败"
    fi

    # Office and Document Tools
    log 1 "开始安装办公和文档工具..."

    log 1 "正在安装PDF Arranger..."
    if install_pdfarranger; then
        log 1 "PDF Arranger安装成功"
    else
        log 3 "PDF Arranger安装失败"
    fi

    log 1 "正在安装WPS Office..."
    if install_wps; then
        log 1 "WPS Office安装成功"
    else
        log 3 "WPS Office安装失败"
    fi

    # Command Line Tools
    log 1 "开始安装命令行工具..."

    log 1 "正在安装Micro编辑器..."
    if install_micro; then
        log 1 "Micro编辑器安装成功"
    else
        log 3 "Micro编辑器安装失败"
    fi

    log 1 "正在安装Cheat.sh..."
    if install_cheatsh; then
        log 1 "Cheat.sh安装成功"
    else
        log 3 "Cheat.sh安装失败"
    fi

    log 1 "正在安装EG..."
    if install_eg; then
        log 1 "EG安装成功"
    else
        log 3 "EG安装失败"
    fi

    log 1 "正在安装Eggs..."
    if install_eggs; then
        log 1 "Eggs安装成功"
    else
        log 3 "Eggs安装失败"
    fi

    # Package Managers and System Tools
    log 1 "开始安装包管理器和系统工具..."

    log 1 "正在安装Snap..."
    if install_snap; then
        log 1 "Snap安装成功"
    else
        log 3 "Snap安装失败"
    fi

    log 1 "正在安装Flatpak..."
    if install_flatpak; then
        log 1 "Flatpak安装成功"
    else
        log 3 "Flatpak安装失败"
    fi

    log 1 "正在安装Homebrew..."
    if install_homebrew; then
        log 1 "Homebrew安装成功"
    else
        log 3 "Homebrew安装失败"
    fi

    log 1 "正在安装Docker..."
    if install_docker_and_docker_compose; then
        log 1 "Docker安装成功"
    else
        log 3 "Docker安装失败"
    fi

    log 1 "全部安装过程完成。详细日志请查看：$log_file"
}

# Run the main installation function
# install_all_packages

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 如果脚本是被 source 引用的，就直接返回，不继续执行后面的代码
    # 这通常用于防止某些命令被重复执行
    install_all_packages
    return 0
fi
