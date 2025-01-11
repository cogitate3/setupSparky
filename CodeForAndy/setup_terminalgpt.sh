#!/bin/bash

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误处理函数
handle_error() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 警告函数
show_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 成功信息函数
show_success() {
    echo -e "${GREEN}成功: $1${NC}"
}

# 显示使用说明
show_usage() {
    echo -e "${GREEN}=== TerminalGPT 安装脚本 ===${NC}

${YELLOW}使用方法:${NC}
    ${GREEN}$0 install${NC}   - 安装 TerminalGPT
    ${GREEN}$0 uninstall${NC} - 卸载 TerminalGPT

${YELLOW}示例:${NC}
    ${GREEN}sudo bash $0 install${NC}     # 安装 TerminalGPT
    ${GREEN}sudo bash $0 uninstall${NC}   # 卸载 TerminalGPT

${YELLOW}注意:${NC}
- 安装需要 sudo 权限
- 安装后需要重新加载终端配置
"
    exit 1
}

# 备份函数
backup_config() {
    local config_file="$1"
    local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file" || handle_error "配置备份失败"
        show_success "已备份原配置到: $backup_file"
        return 0
    fi
    return 1
}

# 配置shell别名
setup_aliases() {
    local zshrc="$HOME/.zshrc"
    local bashrc="$HOME/.bashrc"
    
    # 为zsh配置别名
    if command -v zsh &> /dev/null; then
        if [ -f "$zshrc" ]; then
            # 删除已存在的别名配置
            sed -i '/alias gpto="terminalgpt one-shot"/d' "$zshrc"
            sed -i '/alias gptn="terminalgpt new"/d' "$zshrc"
            # 添加新的别名配置
            echo 'alias gpto="terminalgpt one-shot"' >> "$zshrc"
            echo 'alias gptn="terminalgpt new"' >> "$zshrc"
            show_success "已配置zsh别名"
        fi
    fi
    
    # 为bash配置别名
    if command -v bash &> /dev/null; then
        if [ -f "$bashrc" ]; then
            # 删除已存在的别名配置
            sed -i '/alias gpto="terminalgpt one-shot"/d' "$bashrc"
            sed -i '/alias gptn="terminalgpt new"/d' "$bashrc"
            # 添加新的别名配置
            echo 'alias gpto="terminalgpt one-shot"' >> "$bashrc"
            echo 'alias gptn="terminalgpt new"' >> "$bashrc"
            show_success "已配置bash别名"
        fi
    fi
}

# 配置环境变量
setup_env_path() {
    local bashrc="$HOME/.bashrc"
    local pipx_bin_path="$HOME/.local/bin"
    
    if [ -f "$bashrc" ]; then
        # 删除已存在的PATH配置
        sed -i '/export PATH=$PATH:$HOME\/.local\/bin/d' "$bashrc"
        # 添加新的PATH配置
        echo 'export PATH=$PATH:$HOME/.local/bin' >> "$bashrc"
        show_success "已将 TerminalGPT 路径添加到环境变量"
    fi
}

# 安装函数
install_terminalgpt() {
    # 检查配置文件是否存在
    CONFIG_DIR="$HOME/.config/terminalgpt"
    CONFIG_FILE="$CONFIG_DIR/config"
    if [ -f "$CONFIG_FILE" ]; then
        show_warning "检测到已存在的配置文件: $CONFIG_FILE"
        backup_config "$CONFIG_FILE"
        read -p "是否要覆盖现有配置？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            show_success "保留现有配置，跳过配置步骤"
            return 0
        fi
    fi

    # 检查Python版本
    python_version=$(python3 --version 2>&1 | awk '{print $2}') || handle_error "无法获取Python版本"
    required_version="3.6"
    if [[ $(echo -e "$python_version\n$required_version" | sort -V | head -n1) != "$required_version" ]]; then
        handle_error "Python版本必须是3.6或更高版本。当前版本为 $python_version"
    fi

    # 安装pipx
    if ! command -v pipx &> /dev/null; then
        show_warning "pipx未安装，正在安装pipx..."
        python3 -m pip install --user pipx || handle_error "pipx安装失败"
        python3 -m pipx ensurepath || handle_error "pipx路径配置失败"
        export PATH=$PATH:~/.local/bin
        if ! command -v pipx &> /dev/null; then
            handle_error "pipx安装后仍无法使用，请尝试重新启动终端"
        fi
    fi

    # 安装TerminalGPT
    echo "正在使用pipx安装TerminalGPT..."
    pipx install terminalgpt --force || handle_error "TerminalGPT安装失败"

    # 检查安装
    if ! command -v terminalgpt &> /dev/null; then
        handle_error "TerminalGPT安装失败，无法找到可执行文件"
    fi

    # 创建配置目录
    mkdir -p "$CONFIG_DIR" || handle_error "无法创建配置目录"

    # 配置TerminalGPT
    echo "正在配置TerminalGPT..."
    if ! terminalgpt install <<EOF
您的_OpenAI_API_Key
gpt-3.5-turbo
markdown
EOF
    then
        handle_error "TerminalGPT配置失败"
    fi

    # 配置别名和环境变量
    setup_aliases
    setup_env_path

    show_success "TerminalGPT安装和配置完成！"

    # 显示使用说明
echo -e "
${GREEN}=== TerminalGPT安装成功 ===${NC}

${YELLOW}使用方法:${NC}
1. 在终端中输入 ${GREEN}'terminalgpt'${NC} 开始使用
2. ${YELLOW}快捷命令:${NC}
   - ${GREEN}gpto${NC}: 单次对话模式
   - ${GREEN}gptn${NC}: 新建对话模式
3. ${YELLOW}配置文件位置:${NC} ${GREEN}$CONFIG_FILE${NC}
4. ${YELLOW}配置备份位置:${NC} ${GREEN}${CONFIG_DIR}${NC} 
   (文件名格式: config.json.backup.YYYYMMDD_HHMMSS)

${YELLOW}请运行以下命令使配置生效:${NC}
${GREEN}source ~/.bashrc${NC}
${GREEN}source ~/.zshrc${NC} (如果使用zsh)

${YELLOW}如果遇到问题，请检查:${NC}
- API Key是否正确
- 网络连接是否正常
- Python环境是否正确
"

}

# 卸载函数
uninstall_terminalgpt() {
    echo "正在卸载TerminalGPT..."
    
    # 使用pipx卸载
    if command -v pipx &> /dev/null; then
        pipx uninstall terminalgpt || handle_error "TerminalGPT卸载失败"
    fi

    # 删除配置文件
    CONFIG_DIR="$HOME/.config/terminalgpt"
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR" || handle_error "无法删除配置目录"
    fi

    # 清理别名配置
    local zshrc="$HOME/.zshrc"
    local bashrc="$HOME/.bashrc"
    
    if [ -f "$zshrc" ]; then
        sed -i '/alias gpto="terminalgpt one-shot"/d' "$zshrc"
        sed -i '/alias gptn="terminalgpt new"/d' "$zshrc"
    fi
    
    if [ -f "$bashrc" ]; then
        sed -i '/alias gpto="terminalgpt one-shot"/d' "$bashrc"
        sed -i '/alias gptn="terminalgpt new"/d' "$bashrc"
        sed -i '/export PATH=$PATH:$HOME\/.local\/bin/d' "$bashrc"
    fi

    show_success "TerminalGPT已完全卸载！"
    echo "请运行 'source ~/.bashrc' (和 'source ~/.zshrc' 如果使用zsh) 使配置生效"
}

# 主程序
case "$1" in
    "install")
        install_terminalgpt
        ;;
    "uninstall")
        uninstall_terminalgpt
        ;;
    *)
        show_usage
        ;;
esac