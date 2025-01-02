#!/bin/bash

# 检查脚本格式,必须为 Unix 格式
if [[ $(file -b --mime "$0") != *"text/x-shellscript"* ]]; then
    echo "Error: This script must be in Unix format."
    exit 1
fi

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

# 引入日志相关配置
source 001log2File.sh

# 全局变量定义
OH_MY_ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
BACKUP_DIR=~/.shell_backup/$(date +%Y%m%d_%H%M%S)  # 添加备份目录

# 通用函数：执行命令并在失败时退出
run_or_fail() {
    if ! "$@"; then
        log 3 "Error running command: $*"
        exit 1
    fi
}

# 备份函数
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/" || log 3 "Failed to backup $file"
        log 2 "Backed up $file to $BACKUP_DIR"
    fi
}

# 检查并安装软件包
__install_if_missing() {
    local package="$1"
    # 检查是否为有效的包名
    if [[ -z "$package" ]]; then
        log 3 "Invalid package name"
        return 1
    fi
    
    # 更新软件包列表
    if ! dpkg -l | grep -q "^ii.*$package"; then
        log 1 "Updating package lists..."
        run_or_fail sudo apt update
        
        log 1 "Installing $package..."
        if ! sudo apt install -y "$package"; then
            log 3 "Failed to install $package"
            return 1
        fi
        log 2 "$package installed successfully"
    else
        log 2 "$package is already installed"
    fi
}

# 卸载软件包
__uninstall_package() {
    local package="$1"
    if dpkg -l | grep -q "^ii.*$package"; then
        log 1 "Uninstalling $package..."
        if ! sudo apt remove -y "$package"; then
            log 3 "Failed to uninstall $package"
            return 1
        fi
        run_or_fail sudo apt autoremove -y
        log 2 "$package uninstalled successfully"
    else
        log 2 "$package is not installed"
    fi
}

# 安装字体
install_MesloLGS_fonts() {
    log 1 "Installing MesloLGS NF fonts..."
    local font_dir=~/.local/share/fonts
    mkdir -p "$font_dir"
    
    # 字体文件数组
    local fonts=(
        "MesloLGS-NF-Regular.ttf"
        "MesloLGS-NF-Bold.ttf"
        "MesloLGS-NF-Italic.ttf"
        "MesloLGS-NF-BoldItalic.ttf"
    )

    # 下载和安装字体
    local success=true
    for font in "${fonts[@]}"; do
        if ! curl -L \
            --retry 3 \
            --retry-delay 5 \
            --retry-max-time 60 \
            --connect-timeout 30 \
            --max-time 120 \
            --progress-bar \
            -o "$font_dir/$font" \
            "https://github.com/romkatv/powerlevel10k/raw/master/font/$font"; then
            log 3 "Failed to download $font"
            success=false
            break
        fi
    done

    if $success; then
        fc-cache -f -v
        if fc-list | grep -q "MesloLGS"; then
            log 2 "MesloLGS NF fonts installed successfully"
        else
            log 3 "Font cache update failed"
        fi
    else
        log 3 "Font installation failed"
        return 1
    fi
}

# 卸载字体
uninstall_MesloLGS_fonts() {
    log 1 "Uninstalling MesloLGS NF fonts..."
    local font_dir=~/.local/share/fonts
    
    if [[ -d "$font_dir" ]]; then
        rm -f "$font_dir"/MesloLGS*
        fc-cache -f -v
        
        if ! fc-list | grep -q "MesloLGS"; then
            log 2 "MesloLGS NF fonts uninstalled successfully"
        else
            log 3 "Failed to uninstall fonts completely"
            return 1
        fi
    else
        log 2 "Font directory not found, nothing to uninstall"
    fi
}

# 安装 zsh 和 oh-my-zsh
function install_zsh_and_ohmyzsh() {
    log 1 "Starting zsh installation..."
    
    # 安装 zsh
    __install_if_missing "zsh" || return 1
    
    # 备份现有的 .zshrc
    backup_file ~/.zshrc
    
    # 安装 oh-my-zsh
    if [[ ! -d ~/.oh-my-zsh ]]; then
        log 1 "Installing oh-my-zsh..."
        if ! sh -c "$(curl -fsSL --retry 3 --retry-delay 5 --retry-max-time 60 --connect-timeout 30 --max-time 120 https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            log 3 "Failed to install oh-my-zsh"
            return 1
        fi
    fi

    # 更改默认 shell
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        log 1 "Changing default shell to zsh..."
        run_or_fail sudo usermod -s "$(which zsh)" "$(whoami)"
    fi

    log 2 "zsh and oh-my-zsh installation complete"
}

# 配置 oh-my-zsh
function configure_ohmyzsh() {
    log 1 "Configuring oh-my-zsh plugins..."
    
    # 安装依赖包
    local deps=("autojump" "git-extras" "fzf")
    for dep in "${deps[@]}"; do
        __install_if_missing "$dep" || return 1
    done
    
    # 插件配置
    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )

    # 安装插件
    for plugin in "${!plugins[@]}"; do
        local plugin_dir="$OH_MY_ZSH_CUSTOM/plugins/$plugin"
        if [[ -d "$plugin_dir" && -n "$(ls -A "$plugin_dir")" ]]; then
            log 2 "Plugin $plugin already exists"
            continue
        fi
        
        log 1 "Installing plugin: $plugin..."
        if ! git clone "${plugins[$plugin]}" "$plugin_dir"; then
            log 3 "Failed to install plugin: $plugin"
            return 1
        fi
    done

    # 配置 incr
    log 1 "Checking incr installation..."
    local incr_dir="$OH_MY_ZSH_CUSTOM/incr"
    local incr_file="$incr_dir/incr-0.2.zsh"
    
    if [[ -f "$incr_file" ]]; then
        log 2 "incr is already installed"
    else
        log 1 "Installing incr..."
        mkdir -p "$incr_dir"
        if ! wget -O "$incr_file" https://mimosa-pudica.net/src/incr-0.2.zsh; then
            log 3 "Failed to download incr"
            return 1
        fi
        log 2 "incr installed successfully"
    fi

    # 更新 .zshrc
    local plugins_line='plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)'
    if ! grep -q "^plugins=" ~/.zshrc; then
        echo "$plugins_line" >> ~/.zshrc
    else
        sed -i "/^plugins=/c\\$plugins_line" ~/.zshrc
    fi

    # 添加 incr 源
    local incr_source="source $OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh"
    grep -q "$incr_source" ~/.zshrc || echo "$incr_source" >> ~/.zshrc
}

# 配置 Powerlevel10k
function configure_powerlevel10k() {
    log 1 "Configuring powerlevel10k theme..."
    
    local theme_dir="$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"
    
    # 克隆主题
    if [[ ! -d "$theme_dir" ]]; then
        if ! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"; then
            log 3 "Failed to clone powerlevel10k"
            return 1
        fi
    fi

    # 配置主题
    local theme_source="source $theme_dir/powerlevel10k.zsh-theme"
    grep -q "$theme_source" ~/.zshrc || echo "$theme_source" >> ~/.zshrc
    
    # 设置主题
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    # # 安装字体
    install_MesloLGS_fonts
}

# 卸载 Powerlevel10k
function uninstall_powerlevel10k() {
    log 1 "Removing Powerlevel10k..."
    
    # 备份配置文件
    backup_file ~/.p10k.zsh
    backup_file ~/.zshrc
    
    # 删除主题目录
    local theme_dir="$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"
    if [[ -d "$theme_dir" ]]; then
        rm -rf "$theme_dir"
    fi

    # 删除配置文件
    rm -f ~/.p10k.zsh

    # 更新 .zshrc
    if [[ -f ~/.zshrc ]]; then
        sed -i '/source.*powerlevel10k.*powerlevel10k.zsh-theme/d' ~/.zshrc
        sed -i 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME="robbyrussell"/' ~/.zshrc
    fi

    # 卸载字体
    uninstall_MesloLGS_fonts
}

# 卸载 zsh 和 oh-my-zsh
function uninstall_zsh_and_ohmyzsh() {
    log 1 "Starting zsh uninstallation..."
    
    # 切换回 bash
    if [[ "$SHELL" == "$(which zsh)" ]]; then
        log 1 "Changing default shell back to bash..."
        run_or_fail sudo usermod -s "$(which bash)" "$(whoami)"
    fi

    # 备份重要文件
    backup_file ~/.zshrc
    backup_file ~/.zsh_history
    
    # 删除相关目录和文件
    local files_to_remove=(
        ~/.oh-my-zsh
        ~/.zshrc
        ~/.zsh_history
        "$OH_MY_ZSH_CUSTOM"
        "$OH_MY_ZSH_CUSTOM/incr"
    )

    for file in "${files_to_remove[@]}"; do
        if [[ -e "$file" ]]; then
            log 1 "Removing $file..."
            rm -rf "$file"
        fi
    done

    # 卸载相关包
    local packages=(
        "autojump"
        "git-extras"
        "fzf"
        "zsh"
    )

    for package in "${packages[@]}"; do
        __uninstall_package "$package"
    done
}

# 主函数
mainsetup() {
    # 检查 root 权限
    if [[ $EUID -eq 0 ]]; then
        log 3 "请不要使用 root 用户运行此脚本"
        exit 1
    fi

    # 检查网络连接
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log 3 "无法连接到互联网，请检查网络连接"
        exit 1
    fi

    case "$1" in
        install)
            install_zsh_and_ohmyzsh
            configure_ohmyzsh
            configure_powerlevel10k
            ;;
        uninstall)
            uninstall_zsh_and_ohmyzsh
            uninstall_powerlevel10k
            ;;
        *)
            echo "用法: $0 {install|uninstall}"
            exit 1
            ;;
    esac
}

# 检查参数并执行
if [[ "$#" -ne 1 ]]; then
    echo "用法: $0 {install|uninstall}"
    exit 1
fi

# 如果脚本被直接运行（不是被source），则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mainsetup "$1"
fi