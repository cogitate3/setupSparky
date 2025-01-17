#!/bin/bash
###############################################################################
# 脚本名称：setup_terminalgpt.sh
# 作用：安装/卸载 TerminalGPT 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai opanai4o
# 源代码：https://github.com/adamyodinsky/TerminalGPT
# 版本：1.3
# 用法:
#   安装: ./setup_terminalgpt.sh install
#   卸载: ./setup_terminalgpt.sh uninstall
###############################################################################

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示错误信息
show_error() {
    echo -e "${RED}错误: $1${NC}" >&2
}

# 显示警告信息
show_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 显示成功信息
show_success() {
    echo -e "${GREEN}成功: $1${NC}"
}

# 显示信息
show_info() {
    echo -e "${NC}$1${NC}"
}

# 错误处理函数
handle_error() {
    show_error "$1"
    exit 1
}

# 定义日志文件
LOG_FILE="$HOME/.terminalgpt/install.log"
DEBUG=true

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    if [[ "$DEBUG" == "true" || "$level" != "DEBUG" ]]; then
        echo -e "[${level}] ${message}" >&2
    fi
}

# 显示使用说明
show_usage() {
    echo -e "${GREEN}=== TerminalGPT 安装脚本 ===${NC}

${YELLOW}使用方法:${NC}
    ${GREEN}$0 install${NC}   - 安装 TerminalGPT
    ${GREEN}$0 uninstall${NC} - 卸载 TerminalGPT

${YELLOW}示例:${NC}
    ${GREEN}bash $0 install${NC}     # 安装 TerminalGPT
    ${GREEN}bash $0 uninstall${NC}   # 卸载 TerminalGPT

${YELLOW}注意:${NC}
- 安装后需要重新加载终端配置
"
    exit 1
}

# 创建备份目录
create_backup_dir() {
    local backup_dir="$1"
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir" 2>/dev/null
        return $?
    fi
    return 0
}

# 备份shell配置文件
backup_shell_config() {
    local source_file="$1"
    local backup_dir="$2"
    local timestamp="$3"
    local filename=$(basename "$source_file")
    local backup_file="$backup_dir/${filename}_${timestamp}.bak"
    
    cp "$source_file" "$backup_file" 2>/dev/null
    return $?
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="$1"
    find "$backup_dir" -type f -name "*.bak" -mtime +7 -delete 2>/dev/null
}

# 配置shell别名
setup_aliases() {
    local shell_rc="$1"
    local backup_dir="$HOME/.terminalgpt/backups"
    
    log_message "INFO" "配置Shell别名: $shell_rc"

    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 备份原始配置
    if [ -f "$shell_rc" ]; then
        cp "$shell_rc" "${backup_dir}/$(basename ${shell_rc}).$(date +%Y%m%d_%H%M%S).bak"
        log_message "DEBUG" "已备份 $shell_rc"
    fi

    # 添加别名
    {
        echo -e "\n# TerminalGPT aliases"
        echo 'alias gpto="terminalgpt one-shot"'
        echo 'alias gptn="terminalgpt new"'
    } >> "$shell_rc"

    log_message "INFO" "Shell别名配置完成: $shell_rc"
}

# 配置环境变量
setup_env_path() {
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    
    for config in "${shell_configs[@]}"; do
        if [ -f "$config" ]; then
            if ! grep -q "^$path_line" "$config"; then
                echo "$path_line" >> "$config"
                show_success "已添加PATH配置到 $config"
            fi
        fi
    done
    
    # Immediately update current session's PATH
    export PATH="$HOME/.local/bin:$PATH"
}

# 安装函数
install_terminalgpt() {
    # 检查Python版本
    python_version=$(python3 --version 2>&1 | awk '{print $2}') || handle_error "无法获取Python版本"
    required_version="3.6"
    if [[ $(echo -e "$python_version\n$required_version" | sort -V | head -n1) != "$required_version" ]]; then
        handle_error "Python版本必须是3.6或更高版本。当前版本为 $python_version"
    fi

    # 确保PATH中包含~/.local/bin
    setup_env_path

    # 安装pipx
    if ! command -v pipx &> /dev/null; then
        show_warning "pipx未安装，正在安装pipx..."
        python3 -m pip install --user pipx || handle_error "pipx安装失败"
        python3 -m pipx ensurepath || handle_error "pipx路径配置失败"
        
        # 重新加载PATH
        export PATH="$HOME/.local/bin:$PATH"
        
        # 验证pipx安装
        if ! command -v pipx &> /dev/null; then
            handle_error "pipx安装后仍无法使用。请运行: source ~/.bashrc 或 source ~/.zshrc"
        fi
    fi

    # 安装TerminalGPT
    echo "正在使用pipx安装TerminalGPT..."
    pipx install terminalgpt --force || handle_error "TerminalGPT安装失败"

    # 等待几秒确保安装完成
    sleep 2

    # 检查安装路径
    local terminalgpt_path="$HOME/.local/bin/terminalgpt"
    if [ ! -f "$terminalgpt_path" ]; then
        handle_error "找不到TerminalGPT可执行文件: $terminalgpt_path"
    fi

    # 确保文件有执行权限
    chmod +x "$terminalgpt_path" || handle_error "无法设置执行权限"

    # 配置Shell环境
    setup_aliases "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && setup_aliases "$HOME/.zshrc"

    show_success "TerminalGPT安装完成！"

    # 显示使用说明
    echo -e "
${GREEN}=== TerminalGPT安装成功 ===${NC}

${YELLOW}重要: 请运行以下命令使环境变量生效:${NC}
${GREEN}source ~/.bashrc${NC}  # 如果使用bash
${GREEN}source ~/.zshrc${NC}   # 如果使用zsh

${YELLOW}使用方法:${NC}
1. 第一次运行时，在终端中输入 ${GREEN}'terminalgpt install'${NC} 按提示输入openai api key，开始使用
2. ${YELLOW}快捷命令:${NC}
   - ${GREEN}gpto${NC}: 单次对话模式
   - ${GREEN}gptn${NC}: 新建对话模式

${YELLOW}请运行以下命令使配置生效:${NC}
${GREEN}source ~/.bashrc${NC}
${GREEN}source ~/.zshrc${NC} (如果使用zsh)

${YELLOW}首次运行说明:${NC}
首次运行时，输入terminalgpt install程序会自动引导您完成配置：
- 设置 OpenAI API Key
- 选择语言模型
- 设置输出格式

${YELLOW}如果遇到问题，请检查:${NC}
- API Key是否正确
- 网络连接是否正常
- Python环境是否正确
- PATH环境变量是否包含 ~/.local/bin
"
}

# 卸载函数
uninstall_terminalgpt() {
    echo "正在卸载TerminalGPT..."
    
    # 使用pipx卸载
    if command -v pipx &> /dev/null; then
        pipx uninstall terminalgpt || handle_error "TerminalGPT卸载失败"
    fi

    # 定义要删除的目录列表
    local dirs_to_remove=(
        "$HOME/.local/bin/terminalgpt"
        "$HOME/.local/pipx/venvs/terminalgpt"
        "$HOME/.terminalgpt"
        "$HOME/.config/terminalgpt"
    )

    # 遍历并删除每个目录
    for dir in "${dirs_to_remove[@]}"; do
        if [ -e "$dir" ]; then
            echo "删除目录: $dir"
            rm -rf "$dir" 2>/dev/null || {
                show_warning "无法删除目录: $dir"
                # 如果普通删除失败，尝试使用sudo
                echo "尝试使用sudo删除..."
                sudo rm -rf "$dir" 2>/dev/null || {
                    show_error "无法删除目录: $dir，请手动删除"
                }
            }
        fi
    done

    # 清理配置文件中的别名
    local config_files=("$HOME/.bashrc" "$HOME/.zshrc")
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            sed -i '/# TerminalGPT aliases/d' "$config"
            sed -i '/alias gpto/d' "$config"
            sed -i '/alias gptn/d' "$config"
            log_message "DEBUG" "已清理配置: $config"
        fi
    done
    
    # 确保删除本地bin目录中的符号链接
    if [ -L "$HOME/.local/bin/terminalgpt" ]; then
        rm -f "$HOME/.local/bin/terminalgpt"
    fi

    show_success "TerminalGPT已完全卸载！"
    echo "请运行 'source ~/.bashrc' (和 'source ~/.zshrc' 如果使用zsh) 使配置生效"
}                       

# 主程序
setup_terminalgpt() {
    # 检查参数个数
    if [ $# -ne 1 ]; then
        show_error "参数错误"
        echo -e "\n${YELLOW}正确用法:${NC}"
        echo -e "  ${GREEN}bash $0 install${NC}     安装 TerminalGPT"
        echo -e "  ${GREEN}bash $0 uninstall${NC}   卸载 TerminalGPT"
        exit 1
    fi

    # 处理命令
    case "$1" in
        "install")
            install_terminalgpt
            ;;
        "uninstall")
            uninstall_terminalgpt
            ;;
        *)
            show_error "无效的命令: $1"
            echo -e "\n${YELLOW}可用命令:${NC}"
            echo -e "  ${GREEN}install${NC}    安装 TerminalGPT"
            echo -e "  ${GREEN}uninstall${NC}  卸载 TerminalGPT"
            echo -e "\n${YELLOW}示例:${NC}"
            echo -e "  ${GREEN}bash $0 install${NC}"
            exit 1
            ;;
    esac
}

# 只有当脚本直接运行时才执行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_terminalgpt "$@"
fi