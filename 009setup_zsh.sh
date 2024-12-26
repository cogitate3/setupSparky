#!/bin/bash

# 引入日志相关配置
source 001log2File.sh

# 设置日志文件
log "/tmp/logs/009.log" 1 "Starting zsh installation script"

function install_zsh_and_ohmyzsh() {
    # 1. 安装 zsh
    if ! command -v zsh &> /dev/null; then
        log 1 "正在安装 zsh..."
        sudo apt update && sudo apt install -y zsh
    fi

    # 2. 安装 oh-my-zsh
    if ! [ -d ~/.oh-my-zsh ]; then
        log 1 "正在安装 oh-my-zsh..."
        # 使用 curl 安装 oh-my-zsh
        #   -fsSL 选项表示：
        #     -f: 如果 URL 不存在，不显示错误信息
        #     -s: 静默模式，curl 不会输出进度信息
        #     -S: 显示错误信息
        #     -L: 跟踪重定向
        #   sh -c: 将 curl 的输出作为 shell 命令执行
        #   "" --unattended: 传递空字符串作为参数，表示不需要交互
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # 3. 更改默认 shell
    log 1 "正在更改默认 shell..."
    sudo usermod -s "$(which zsh)" "$(whoami)"
    log 2 "zsh 和 oh-my-zsh 安装完成！"
    log 2 "建议重新登录以使配置生效。"


    # 4. 配置 oh-my-zsh
    log 1 "正在配置 oh-my-zsh..."
    # 4.1. 配置 plugins
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git clone https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/zsh-interactive-cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-interactive-cd
    sudo apt install -y autojump git-extras

    
    # 4.3. 配置 incr
    log 1 "正在配置incr..."
    mkdir -p ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/incr
    wget -O ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/incr/incr-0.2.zsh https://mimosa-pudica.net/src/incr-0.2.zsh
    sed -i '/^#/a\source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/incr/incr*.zsh' ~/.zshrc
    
    
    sed -i '1i\# Add zsh-completions to FPATH\nfpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src' ~/.zshrc
    
    sed -i '/plugins=(/c\plugins=(git zsh-autosuggestions zsh-completions  autojump brew git-extras npm ssh-agent vagrant zsh-interactive-cd zsh-syntax-highlighting docker sudo)' ~/.zshrc

    # 4.2. 配置 theme
    log 1 "正在配置主题..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
    echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    # 5. 手动安装 MesloLGS NF 字体
    log 1 "正在手动安装 MesloLGS NF 字体..."
    mkdir -p ~/.local/share/fonts
    curl -Lso ~/.local/share/fonts/MesloLGS-NF-Regular.ttf https://github.com/romkatv/powerlevel10k/raw/master/font/MesloLGS%20NF%20Regular.ttf
    curl -Lso ~/.local/share/fonts/MesloLGS-NF-Bold.ttf https://github.com/romkatv/powerlevel10k/raw/master/font/MesloLGS%20NF%20Bold.ttf
    curl -Lso ~/.local/share/fonts/MesloLGS-NF-Italic.ttf https://github.com/romkatv/powerlevel10k/raw/master/font/MesloLGS%20NF%20Italic.ttf
    curl -Lso ~/.local/share/fonts/MesloLGS-NF-BoldItalic.ttf https://github.com/romkatv/powerlevel10k/raw/master/font/MesloLGS%20NF%20Bold%20Italic.ttf
    fc-cache -f -v
}