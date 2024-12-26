#!/bin/bash

# 检查脚本格式,必须为 Unix 格式
if [[ $(file -b --mime "$0") != *"text/x-shellscript"* ]]; then
    echo "Error: This script must be in Unix format."
    exit 1
fi

# 引入日志相关配置
source 001log2File.sh
log 1 "Starting zsh installation script"

# 通用函数：执行命令并在失败时退出
run_or_fail() {
    "$@" || { log 3 "Error running command: $*"; exit 1; }
}

# 检查并安装软件包
install_if_missing() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii.*$package"; then
        log 1 "Installing $package..."
        run_or_fail sudo apt install -y "$package"
    else
        log 2 "$package is already installed."
    fi
}

# 安装 zsh 和 oh-my-zsh
install_zsh_and_ohmyzsh() {
    install_if_missing "zsh"

    if [ ! -d ~/.oh-my-zsh ]; then
        log 1 "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    log 1 "Changing default shell to zsh..."
    sudo usermod -s "$(which zsh)" "$(whoami)"

    log 2 "zsh and oh-my-zsh installation complete. Please re-login to apply changes."

    # 配置 oh-my-zsh
    configure_ohmyzsh
}

# 配置 oh-my-zsh
configure_ohmyzsh() {
    local OH_MY_ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

    log 1 "Configuring oh-my-zsh plugins..."
    install_if_missing "autojump"
    install_if_missing "git-extras"
    install_if_missing "fzf"
    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        ["zsh-interactive-cd"]="https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/zsh-interactive-cd"
    )

    for plugin in "${!plugins[@]}"; do
        git clone "${plugins[$plugin]}" "$OH_MY_ZSH_CUSTOM/plugins/$plugin" || log 3 "Failed to clone $plugin"
    done



    log 1 "Configuring incr..."
    mkdir -p "$OH_MY_ZSH_CUSTOM/incr"
    wget -O "$OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh" https://mimosa-pudica.net/src/incr-0.2.zsh
    grep -q "source $OH_MY_ZSH_CUSTOM/incr/incr" ~/.zshrc || echo "source $OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh" >>~/.zshrc

    log 1 "Updating .zshrc plugins list..."
    grep -q "plugins=(" ~/.zshrc || echo "plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)" >> ~/.zshrc
    sed -i '/plugins=(/c\plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)' ~/.zshrc

    log 1 "Configuring powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
    grep -q "source ~/powerlevel10k/powerlevel10k.zsh-theme" ~/.zshrc || echo "source ~/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    install_fonts
}

# 安装 MesloLGS NF 字体
install_fonts() {
    log 1 "Installing MesloLGS NF fonts..."
    mkdir -p ~/.local/share/fonts
    local fonts=(
        "MesloLGS-NF-Regular.ttf"
        "MesloLGS-NF-Bold.ttf"
        "MesloLGS-NF-Italic.ttf"
        "MesloLGS-NF-BoldItalic.ttf"
    )

    for font in "${fonts[@]}"; do
        curl -Lso ~/.local/share/fonts/$font https://github.com/romkatv/powerlevel10k/raw/master/font/$font
    done

    fc-cache -f -v
    if fc-list | grep -q "MesloLGS"; then
        log 2 "MesloLGS NF fonts installed successfully."
    else
        log 3 "Failed to install MesloLGS NF fonts. Please check manually."
    fi
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_zsh_and_ohmyzsh
fi