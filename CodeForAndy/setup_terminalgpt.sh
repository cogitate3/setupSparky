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

# 初始化日志系统
source "$(dirname "$0")/log.sh"
mkdir -p "$HOME/logs"
LOG_FILE="$HOME/logs/$(dirname "$0").log"
set_log_file "$LOG_FILE" || exit 1

show_usage() {
    echo "用法:"
    echo "  安装: $0 install"
    echo "  卸载: $0 uninstall"
    echo "示例:"
    echo "  $0 install    # 安装 TerminalGPT"
    echo "  $0 uninstall  # 卸载 TerminalGPT"
}

# 创建备份目录
create_backup_dir() {
    local backup_dir="$1"
    if [ ! -d "$backup_dir" ]; then
        log 1 "正在创建备份目录: $backup_dir"
        mkdir -p "$backup_dir" 2>/dev/null || {
            log 3 "无法创建备份目录: $backup_dir"
            return 1
        }
        log 2 "备份目录创建成功: $backup_dir"
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

    log 1 "正在备份配置文件: $source_file -> $backup_file"

    cp "$source_file" "$backup_file" 2>/dev/null || {
        log 3 "无法备份文件: $source_file"
        return 1
    }

    log 2 "配置文件备份成功: $backup_file"
    return 0
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

    log 1 "开始配置Shell别名: $shell_rc"

    # 创建备份目录
    log 1 "正在创建备份目录: $backup_dir"
    mkdir -p "$backup_dir" || {
        log 3 "无法创建备份目录: $backup_dir"
        return 1
    }
    log 2 "备份目录创建成功: $backup_dir"

    # 备份原始配置
    if [ -f "$shell_rc" ]; then
        log 1 "正在备份原始配置文件: $shell_rc"
        cp "$shell_rc" "${backup_dir}/$(basename ${shell_rc}).$(date +%Y%m%d_%H%M%S).bak" || {
            log 3 "无法备份文件: $shell_rc"
            return 1
        }
        log 2 "配置文件备份成功: $shell_rc"
    else
        log 2 "未找到配置文件: $shell_rc，将创建新文件"
    fi

    # 添加别名
    log 1 "正在添加TerminalGPT别名"
    {
        echo -e "\n# TerminalGPT aliases"
        echo 'alias gpto="terminalgpt one-shot"'
        echo 'alias gptn="terminalgpt new"'
    } >>"$shell_rc" || {
        log 3 "无法写入文件: $shell_rc"
        return 1
    }

    # 验证别名是否添加成功
    if ! grep -q 'alias gpto=' "$shell_rc" || ! grep -q 'alias gptn=' "$shell_rc"; then
        log 3 "别名添加失败，请检查文件权限"
        return 1
    fi

    log 1 "Shell别名配置成功: $shell_rc"
    log 2 "请运行 'source $shell_rc' 使配置生效"
    log 2 "您可以使用以下快捷命令:"
    log 2 "  gpto - 单次对话模式"
    log 2 "  gptn - 新建对话模式"
    return 0
}

# 配置环境变量
setup_env_path() {
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")

    log 1 "开始配置环境变量PATH"

    # 检查当前PATH是否已包含.local/bin
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        log 2 "当前会话PATH已包含.local/bin"
    else
        log 1 "当前会话PATH缺少.local/bin，正在添加"
        export PATH="$HOME/.local/bin:$PATH"
        log 2 "当前会话PATH更新成功"
    fi

    # 更新shell配置文件
    for config in "${shell_configs[@]}"; do
        if [ -f "$config" ]; then
            log 1 "正在检查配置文件: $config"
            if ! grep -q "^$path_line" "$config"; then
                log 1 "正在添加PATH配置到: $config"
                echo "$path_line" >>"$config" || {
                    log 3 "无法写入文件: $config"
                    return 1
                }
                log 2 "PATH配置添加成功: $config"
            else
                log 2 "PATH配置已存在: $config"
            fi
        else
            log 2 "未找到配置文件: $config"
        fi
    done

    # 验证PATH配置
    if ! command -v pipx &>/dev/null && [ -x "$HOME/.local/bin/pipx" ]; then
        log 3 "PATH配置失败，无法访问.local/bin目录"
        return 1
    fi

    log 1 "环境变量PATH配置完成"
    return 0
}

# 安装函数
install_terminalgpt() {
    log 1 "开始TerminalGPT安装流程"

    # 检查Python版本
    python_version=$(python3 --version 2>&1 | awk '{print $2}') || {
        log 3 "无法获取Python版本"
        exit 1
    }
    required_version="3.6"
    if [[ $(echo -e "$python_version\n$required_version" | sort -V | head -n1) != "$required_version" ]]; then
        log 3 "Python版本必须是3.6或更高版本。当前版本为 $python_version"
        exit 1
    fi

    # 确保PATH中包含~/.local/bin
    setup_env_path

    # 安装pipx
    if ! command -v pipx &>/dev/null; then
        log 2 "pipx未安装，正在安装pipx..."
        python3 -m pip install --user pipx || {
            log 3 "pipx安装失败"
            exit 1
        }
        python3 -m pipx ensurepath || {
            log 3 "pipx路径配置失败"
            exit 1
        }

        # 重新加载PATH
        export PATH="$HOME/.local/bin:$PATH"

        # 验证pipx安装
        if ! command -v pipx &>/dev/null; then
            log 3 "pipx安装后仍无法使用。请运行: source ~/.bashrc 或 source ~/.zshrc"
            exit 1
        fi
    fi

    # 安装TerminalGPT
    log 1 "正在使用pipx安装TerminalGPT..."
    pipx install terminalgpt --force || {
        log 3 "TerminalGPT安装失败"
        exit 1
    }

    # 等待几秒确保安装完成
    sleep 2

    # 检查安装路径
    local terminalgpt_path="$HOME/.local/bin/terminalgpt"
    if [ ! -f "$terminalgpt_path" ]; then
        log 3 "找不到TerminalGPT可执行文件: $terminalgpt_path"
        exit 1
    fi

    # 确保文件有执行权限
    chmod +x "$terminalgpt_path" || {
        log 3 "无法设置执行权限"
        exit 1
    }

    # 配置Shell环境
    setup_aliases "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && setup_aliases "$HOME/.zshrc"

    echo "TerminalGPT安装完成！"
    echo "安装成功！请按照以下步骤完成配置："
    echo "1. 运行 'terminalgpt install' 配置API Key"
    echo "2. 运行 'source ~/.bashrc' 或 'source ~/.zshrc' 使配置生效"
    echo "3. 使用 'gpto' 或 'gptn' 开始使用"
    echo ""
    echo "如果遇到问题，请检查:"
    echo "- API Key是否正确"
    echo "- 网络连接是否正常"
    echo "- Python环境是否正确"
    echo "- PATH环境变量是否包含 ~/.local/bin"
    echo "- 查看日志文件: $LOG_FILE"
}

# 卸载函数
uninstall_terminalgpt() {
    log 1 "开始TerminalGPT卸载流程"

    # 使用pipx卸载
    if command -v pipx &>/dev/null; then
        log 1 "正在使用pipx卸载TerminalGPT..."
        pipx uninstall terminalgpt || {
            log 3 "TerminalGPT卸载失败"
            exit 1
        }
        log 2 "pipx卸载完成"
    else
        log 2 "pipx未安装，跳过pipx卸载步骤"
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
            log 1 "正在删除目录: $dir"
            rm -rf "$dir" 2>/dev/null || {
                log 2 "无法删除目录: $dir，尝试使用sudo"
                sudo rm -rf "$dir" 2>/dev/null || {
                    log 3 "无法删除目录: $dir，请手动删除"
                    exit 1
                }
            }
            log 2 "成功删除目录: $dir"
        else
            log 2 "目录不存在，跳过删除: $dir"
        fi
    done

    # 清理配置文件中的别名
    local config_files=("$HOME/.bashrc" "$HOME/.zshrc")
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            log 1 "正在清理配置文件: $config"
            sed -i '/# TerminalGPT aliases/d' "$config"
            sed -i '/alias gpto/d' "$config"
            sed -i '/alias gptn/d' "$config"
            log 2 "成功清理配置文件: $config"
        else
            log 2 "配置文件不存在，跳过清理: $config"
        fi
    done

    # 确保删除本地bin目录中的符号链接
    if [ -L "$HOME/.local/bin/terminalgpt" ]; then
        log 1 "正在删除符号链接: $HOME/.local/bin/terminalgpt"
        rm -f "$HOME/.local/bin/terminalgpt" || {
            log 3 "无法删除符号链接"
            exit 1
        }
        log 2 "成功删除符号链接"
    fi

    log 1 "TerminalGPT已完全卸载！"
    log 1 "请运行以下命令完成清理："
    log 1 "1. 运行 'source ~/.bashrc' 或 'source ~/.zshrc' 使配置生效"
    log 1 "2. 检查并删除以下目录（如果存在）："
    log 1 "   - ~/.terminalgpt"
    log 1 "   - ~/.config/terminalgpt"
    log 1 "3. 检查PATH环境变量是否包含 ~/.local/bin"
    log 1 "4. 查看日志文件: $LOG_FILE 获取更多信息"
}
# 主程序
setup_terminalgpt() {
    log 1 "开始执行TerminalGPT安装脚本"

    # 检查参数个数
    if [ $# -ne 1 ]; then
        log 3 "参数错误：需要1个参数，但提供了$#个"
        show_usage
        return 1
    fi

    # 记录传入的命令
    log 2 "接收到的命令参数: $1"

    # 处理命令
    case "$1" in
    "install")
        log 1 "开始安装TerminalGPT"
        install_terminalgpt || {
            log 3 "TerminalGPT安装失败"
            return 1
        }
        log 2 "TerminalGPT安装过程完成"
        log 1 "安装成功！请按照以下步骤完成配置："
        log 1 "1. 运行 'terminalgpt install' 配置API Key"
        log 1 "2. 运行 'source ~/.bashrc' 或 'source ~/.zshrc' 使配置生效"
        log 1 "3. 使用 'gpto' 或 'gptn' 开始使用"
        log 1 "4. 查看日志文件: $LOG_FILE 获取更多信息"
        ;;
    "uninstall")
        log 1 "开始卸载TerminalGPT"
        uninstall_terminalgpt || {
            log 3 "TerminalGPT卸载失败"
            return 1
        }
        log 2 "TerminalGPT卸载过程完成"
        log 1 "卸载成功！请运行以下命令清理环境："
        log 1 "1. 运行 'source ~/.bashrc' 或 'source ~/.zshrc' 使配置生效"
        log 1 "2. 检查并删除 ~/.terminalgpt 和 ~/.config/terminalgpt 目录"
        log 1 "3. 查看日志文件: $LOG_FILE 获取更多信息"
        ;;
    *)
        log 3 "无效的命令: $1"
        log 2 "显示使用说明"
        show_usage
        return 1
        ;;
    esac

    log 1 "TerminalGPT脚本执行完成"
    return 0
}

# 只有当脚本直接运行时才执行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_terminalgpt "$@"
fi
