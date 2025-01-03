#!/bin/bash

# 检查脚本格式,必须为 Unix 格式
if [[ $(file -b --mime "$0") != *"text/x-shellscript"* ]]; then
    echo "Error: This script must be in Unix format."
    exit 1
fi

# 引入日志相关配置
source 001log2File.sh

# 全局变量定义
OH_MY_ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# 通用函数：执行命令并在失败时退出
run_or_fail() {
    "$@" || { log 3 "Error running command: $*"; exit 1; }
}

# 检查并安装软件包
__install_if_missing() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii.*$package"; then
        log 1 "Installing $package..."
        run_or_fail sudo apt install -y "$package"
    else
        log 2 "$package is already installed."
    fi
}

# 卸载软件包
__uninstall_package() {
    local package="$1"
    if dpkg -l | grep -q "^ii.*$package"; then
        log 1 "Uninstalling $package..."
        run_or_fail sudo apt remove -y "$package"
        run_or_fail sudo apt autoremove -y
    else
        log 2 "$package is not installed."
    fi
}

# 安装字体
install_MesloLGS_fonts() {
    log 1 "Installing MesloLGS NF fonts..."
    mkdir -p ~/.local/share/fonts
    local fonts=(
        "MesloLGS-NF-Regular.ttf"
        "MesloLGS-NF-Bold.ttf"
        "MesloLGS-NF-Italic.ttf"
        "MesloLGS-NF-BoldItalic.ttf"
    )

    for font in "${fonts[@]}"; do
        curl -L \
            --retry 3 \
            --retry-delay 5 \
            --retry-max-time 60 \
            --connect-timeout 30 \
            --max-time 120 \
            --progress-bar \
            -o ~/.local/share/fonts/$font \
        https://github.com/romkatv/powerlevel10k/raw/master/font/$font
    done

    fc-cache -f -v
    if fc-list | grep -q "MesloLGS"; then
        log 2 "MesloLGS NF fonts installed successfully."
    else
        log 3 "Failed to install MesloLGS NF fonts. Please check manually."
    fi
}

# 卸载字体
uninstall_MesloLGS_fonts() {
    log 1 "Uninstalling MesloLGS NF fonts..."
    rm -rf ~/.local/share/fonts/MesloLGS*
    fc-cache -f -v
    if fc-list | grep -q "MesloLGS"; then
        log 3 "Failed to uninstall MesloLGS NF fonts. Please check manually."
    else
        log 2 "MesloLGS NF fonts uninstalled successfully."
    fi
}

# 安装 zsh 和 oh-my-zsh
install_zsh_and_ohmyzsh() {
    log 1 "Starting zsh installation script"
    __install_if_missing "zsh"

    if [ ! -d ~/.oh-my-zsh ]; then
        log 1 "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    log 1 "Changing default shell to zsh..."
    sudo usermod -s "$(which zsh)" "$(whoami)"

    log 2 "zsh and oh-my-zsh installation complete. Please re-login to apply changes."

    configure_ohmyzsh
}

# 配置 oh-my-zsh
configure_ohmyzsh() {
    log 1 "Configuring oh-my-zsh plugins..."
    __install_if_missing "autojump"
    __install_if_missing "git-extras"
    __install_if_missing "fzf"
    
    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )

    for plugin in "${!plugins[@]}"; do
        plugin_dir="$OH_MY_ZSH_CUSTOM/plugins/$plugin"
        if [ -d "$plugin_dir" ] && [ "$(ls -A $plugin_dir)" ]; then
            log 2 "Plugin $plugin already exists in $plugin_dir, skipping..."
            continue
        fi
        log 1 "Installing plugin: $plugin..."
        git clone "${plugins[$plugin]}" "$plugin_dir" || log 3 "Failed to clone $plugin"
    done

    log 1 "Configuring incr..."
    mkdir -p "$OH_MY_ZSH_CUSTOM/incr"
    wget -O "$OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh" https://mimosa-pudica.net/src/incr-0.2.zsh
    grep -q "source $OH_MY_ZSH_CUSTOM/incr/incr" ~/.zshrc || echo "source $OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh" >>~/.zshrc

    log 1 "Updating .zshrc plugins list..."
    grep -q "plugins=(" ~/.zshrc || echo "plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)" >> ~/.zshrc
    sed -i '/plugins=(/c\plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)' ~/.zshrc

    configure_powerlevel10k
}

# 配置 Powerlevel10k
configure_powerlevel10k() {
    log 1 "Configuring powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"

    grep -q "source $OH_MY_ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme" ~/.zshrc || \
        echo "source $OH_MY_ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc

    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    install_MesloLGS_fonts
}

# 卸载 Powerlevel10k
uninstall_powerlevel10k() {
    log 1 "Removing Powerlevel10k..."
    
    if [ -d "$OH_MY_ZSH_CUSTOM/themes/powerlevel10k" ]; then
        rm -rf "$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"
    fi

    if [ -f "${HOME}/.p10k.zsh" ]; then
        rm -f "${HOME}/.p10k.zsh"
    fi

    if [ -f ~/.zshrc ]; then
        sed -i '/source.*powerlevel10k.*powerlevel10k.zsh-theme/d' ~/.zshrc
        sed -i 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME="robbyrussell"/' ~/.zshrc
    fi

    uninstall_MesloLGS_fonts
}

# 卸载 zsh 和 oh-my-zsh
uninstall_zsh_and_ohmyzsh() {
    log 1 "Starting zsh uninstallation..."
    
    if [ "$SHELL" = "$(which zsh)" ]; then
        log 1 "Changing default shell back to bash..."
        sudo usermod -s "$(which bash)" "$(whoami)"
    fi

    local files_to_remove=(
        ~/.oh-my-zsh
        ~/.zshrc
        ~/.zsh_history
        "$OH_MY_ZSH_CUSTOM"
        "$OH_MY_ZSH_CUSTOM/incr"
    )

    for file in "${files_to_remove[@]}"; do
        if [ -e "$file" ]; then
            log 1 "Removing $file..."
            rm -rf "$file"
        fi
    done

    local packages_to_remove=(
        "zsh"
        "autojump"
        "git-extras"
        "fzf"
    )

    for package in "${packages_to_remove[@]}"; do
        uninstall_package "$package"
    done
}

# 主函数
mainsetup() {
    case "$1" in
        install)
            install_zsh_and_ohmyzsh
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
if [ "$#" -ne 1 ]; then
    echo "用法: $0 {install|uninstall}"
    exit 1
fi

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mainsetup "$1"
fi