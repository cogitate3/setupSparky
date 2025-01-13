#!/bin/bash
###############################################################################
# 脚本名称：setup_terminalgpt.sh
# 作用：安装/卸载 TerminalGPT 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai
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
    local zshrc="$HOME/.zshrc"
    local bashrc="$HOME/.bashrc"
    local backup_dir="$HOME/.shell_backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local exit_code=0
    local gpto_alias='alias gpto="terminalgpt one-shot"'
    local gptn_alias='alias gptn="terminalgpt new"'
    
    # 创建备份目录
    if ! create_backup_dir "$backup_dir"; then
        show_error "无法创建备份目录"
        return 1
    fi

    # 为zsh配置别名
    if command -v zsh &> /dev/null; then
        if [ -f "$zshrc" ]; then
            if [ ! -w "$zshrc" ]; then
                show_error "没有 $zshrc 的写入权限"
                exit_code=1
            else
                if ! backup_shell_config "$zshrc" "$backup_dir" "$timestamp"; then
                    show_warning "无法备份 $zshrc"
                else
                    show_success "已备份 $zshrc"
                fi
                
                # 创建临时文件
                local tmp_file=$(mktemp)
                if [ $? -ne 0 ]; then
                    show_error "无法创建临时文件"
                    return 1
                fi
                
                # 删除已存在的别名配置
                sed '/alias[[:space:]]*gpto[[:space:]]*=.*terminalgpt[[:space:]]*one-shot.*/d' "$zshrc" > "$tmp_file" \
                    && sed -i '/alias[[:space:]]*gptn[[:space:]]*=.*terminalgpt[[:space:]]*new.*/d' "$tmp_file"
                
                if [ $? -eq 0 ]; then
                    # 添加新的别名配置
                    echo "$gpto_alias" >> "$tmp_file"
                    echo "$gptn_alias" >> "$tmp_file"
                    
                    # 验证并更新文件
                    if ! grep -q "^$gpto_alias\$" "$tmp_file" || ! grep -q "^$gptn_alias\$" "$tmp_file"; then
                        show_error "别名格式验证失败"
                        rm -f "$tmp_file"
                        exit_code=1
                    else
                        mv "$tmp_file" "$zshrc"
                        show_success "已配置zsh别名"
                    fi
                else
                    show_error "更新 $zshrc 失败"
                    rm -f "$tmp_file"
                    exit_code=1
                fi
            fi
        fi
    fi
    
    # 为bash配置别名
    if command -v bash &> /dev/null; then
        if [ -f "$bashrc" ]; then
            if [ ! -w "$bashrc" ]; then
                show_error "没有 $bashrc 的写入权限"
                exit_code=1
            else
                if ! backup_shell_config "$bashrc" "$backup_dir" "$timestamp"; then
                    show_warning "无法备份 $bashrc"
                else
                    show_success "已备份 $bashrc"
                fi
                
                local tmp_file=$(mktemp)
                if [ $? -ne 0 ]; then
                    show_error "无法创建临时文件"
                    return 1
                fi
                
                sed '/alias[[:space:]]*gpto[[:space:]]*=.*terminalgpt[[:space:]]*one-shot.*/d' "$bashrc" > "$tmp_file" \
                    && sed -i '/alias[[:space:]]*gptn[[:space:]]*=.*terminalgpt[[:space:]]*new.*/d' "$tmp_file"
                
                if [ $? -eq 0 ]; then
                    echo "$gpto_alias" >> "$tmp_file"
                    echo "$gptn_alias" >> "$tmp_file"
                    
                    if ! grep -q "^$gpto_alias\$" "$tmp_file" || ! grep -q "^$gptn_alias\$" "$tmp_file"; then
                        show_error "别名格式验证失败"
                        rm -f "$tmp_file"
                        exit_code=1
                    else
                        mv "$tmp_file" "$bashrc"
                        show_success "已配置bash别名"
                    fi
                else
                    show_error "更新 $bashrc 失败"
                    rm -f "$tmp_file"
                    exit_code=1
                fi
            fi
        fi
    fi

    # 清理旧备份
    cleanup_old_backups "$backup_dir"

    return $exit_code
}

# 配置环境变量
setup_env_path() {
    local bashrc="$HOME/.bashrc"
    local pipx_bin_path="$HOME/.local/bin"
    
    if [ -f "$bashrc" ] && [ -w "$bashrc" ]; then
        # 删除已存在的PATH配置
        sed -i '/export PATH=$PATH:$HOME\/.local\/bin/d' "$bashrc"
        # 添加新的PATH配置
        echo 'export PATH=$PATH:$HOME/.local/bin' >> "$bashrc"
        show_success "已将 TerminalGPT 路径添加到环境变量"
    else
        show_error "无法更新环境变量配置"
        return 1
    fi
}

# 安装函数
install_terminalgpt() {
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

    # 配置别名和环境变量
    setup_aliases
    setup_env_path

    show_success "TerminalGPT安装完成！"

    # 显示使用说明
    echo -e "
${GREEN}=== TerminalGPT安装成功 ===${NC}

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

    # 清理别名配置
    local zshrc="$HOME/.zshrc"
    local bashrc="$HOME/.bashrc"
    local gpto_pattern='alias[[:space:]]*gpto[[:space:]]*=.*terminalgpt[[:space:]]*one-shot.*'
    local gptn_pattern='alias[[:space:]]*gptn[[:space:]]*=.*terminalgpt[[:space:]]*new.*'
    
    if [ -f "$zshrc" ] && [ -w "$zshrc" ]; then
        sed -i "/${gpto_pattern}/d" "$zshrc"
        sed -i "/${gptn_pattern}/d" "$zshrc"
    fi
    
    if [ -f "$bashrc" ] && [ -w "$bashrc" ]; then
        sed -i "/${gpto_pattern}/d" "$bashrc"
        sed -i '/export PATH=$PATH:$HOME\/.local\/bin/d' "$bashrc"
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