#!/bin/bash
###############################################################################
# 脚本名称：main.sh
# 作用：管理和运行各种安装脚本的菜单界面
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 版本：1.2
###############################################################################

# 严格模式
set -euo pipefail

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 创建临时目录
TEMP_DIR="$(mktemp -d)"
chmod 700 "$TEMP_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 错误处理
trap 'echo -e "\n${RED}错误: 脚本在第 ${LINENO} 行执行失败${NC}" >&2' ERR
trap 'cleanup' EXIT

# 清理函数
cleanup() {
    tput cnorm  # 恢复光标
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

# 日志函数
log_error() {
    echo -e "${RED}错误: $1${NC}" >&2
}

log_info() {
    echo -e "${BLUE}信息: $1${NC}"
}

log_success() {
    echo -e "${GREEN}成功: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 检查脚本权限
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        log_error "请不要使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检查依赖脚本
check_dependencies() {
    local missing_scripts=()
    local required_scripts=(
        "setup_alacritty.sh"
        "setup_chatgpt.sh"
        "setup_terminalgpt.sh"
        "setup_tgpt.sh"
        "setup_rime.sh"
        "setup_fonts.sh"
    )

    for script in "${required_scripts[@]}"; do
        if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
            missing_scripts+=("$script")
        fi
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        log_error "以下脚本缺失:"
        printf '%s\n' "${missing_scripts[@]}"
        exit 1
    fi
}

# 检查系统依赖
check_system_dependencies() {
    local missing_deps=()
    local required_deps=(
        "curl"
        "wget"
        "git"
    )

    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下系统依赖:"
        printf '%s\n' "${missing_deps[@]}"
        log_warning "请使用包管理器安装缺少的依赖"
        exit 1
    fi
}

# 检查是否已安装的辅助函数
is_already_installed() {
    local script="$1"
    
    case "$(basename "$script")" in
        "setup_alacritty.sh")
            [ -d ~/.config/alacritty ] && return 0
            ;;
        "setup_chatgpt.sh")
            command -v chatgpt >/dev/null 2>&1 && return 0
            ;;
        "setup_terminalgpt.sh")
            command -v terminalgpt >/dev/null 2>&1 && return 0
            ;;
        "setup_tgpt.sh")
            command -v tgpt >/dev/null 2>&1 && return 0
            ;;
        "setup_rime.sh")
            [ -d ~/.config/ibus/rime ] && return 0
            ;;
        "setup_fonts.sh")
            [ -d ~/.local/share/fonts ] && return 0
            ;;
    esac
    
    return 1
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}=== 安装脚本管理菜单 ===${NC}\n"
    echo -e "${GREEN}1)${NC} 安装/配置 Alacritty 终端"
    echo -e "${GREEN}2)${NC} 安装/配置 ChatGPT 终端"
    echo -e "${GREEN}3)${NC} 安装/配置 TerminalGPT 终端"
    echo -e "${GREEN}4)${NC} 安装/配置 TGPT 终端"
    echo -e "${GREEN}5)${NC} 安装/配置 Rime 输入法"
    echo -e "${GREEN}6)${NC} 安装/配置 字体"
    echo -e "${YELLOW}q)${NC} 退出\n"
    echo -e "请输入选项 [1-6 或 q]: "
}

# 备份配置
backup_config() {
    local script_name="$1"
    local backup_dir="${TEMP_DIR}/backups/$(basename "$script_name" .sh)"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    case "$script_name" in
        *"setup_alacritty.sh")
            if [ -d ~/.config/alacritty ]; then
                cp -r ~/.config/alacritty "$backup_dir/alacritty_$timestamp"
                log_info "已备份 Alacritty 配置"
            fi
            ;;
        *"setup_rime.sh")
            if [ -d ~/.config/ibus/rime ]; then
                cp -r ~/.config/ibus/rime "$backup_dir/rime_$timestamp"
                log_info "已备份 Rime 配置"
            fi
            ;;
        *)
            log_info "无需备份配置"
            ;;
    esac
}

# 获取用户操作选择
get_action() {

    local script="$1"
    local choice
    local timeout=300  # 5分钟超时
    local try_count=0
    local max_tries=3

    # 验证输入的脚本名称
    if [ -z "$script" ]; then
        log_error "脚本名称不能为空"
        return 1
    fi

    # 设置中断处理
    trap 'echo -e "\n操作已取消"; return 1' INT

    # 显示菜单
    printf "\n${BLUE}=== %s ===${NC}\n" "$(basename "$script")"
    printf "\n${BLUE}请选择操作:${NC}\n"
    printf "${GREEN}1)${NC} 安装\n"
    printf "${GREEN}2)${NC} 卸载\n"
    printf "${GREEN}b)${NC} 返回主菜单\n\n"
    
    # 读取用户输入（带超时）
    while [ $try_count -lt $max_tries ]; do
        printf "请输入选项 [1/2/b]: "
        
        if ! read -r -t $timeout choice; then
            echo  # 新行
            log_error "操作超时"
            return 1
        fi

        # 验证用户输入
        case "$choice" in
            1) 
                # 检查是否已安装
                if is_already_installed "$script"; then
                    log_warning "检测到已存在安装，是否继续？ [y/N]: "
                    read -r confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        return 1
                    fi
                fi
                backup_config "$script"
                echo "install"
                return 0 
                ;;
            2) 
                # 检查是否已安装
                if ! is_already_installed "$script"; then
                    log_warning "未检测到安装，是否继续卸载？ [y/N]: "
                    read -r confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        return 1
                    fi
                fi
                backup_config "$script"
                echo "uninstall"
                return 0 
                ;;
            b|B) 
                echo "back"
                return 0 
                ;;
            *)
                ((try_count++))
                if [ $try_count -lt $max_tries ]; then
                    log_error "无效的选项，请重试 (还剩 $((max_tries-try_count)) 次机会)"
                else
                    log_error "已达到最大重试次数"
                    return 1
                fi
                ;;
        esac

    done

    return 1
}

# 运行选择的脚本
run_script() {
    local script="${SCRIPT_DIR}/$1"
    local action=$2
    
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            if ! chmod +x "$script"; then
                log_error "无法设置脚本执行权限"
                return 1
            fi
        fi
        log_info "执行脚本: ${script}"
        if ! bash "$script" "$action"; then
            local exit_code=$?
            log_error "脚本执行失败 (退出代码: $exit_code)"
            log_warning "按回车键返回主菜单"
            read -r
            return 1
        fi
        log_success "脚本执行完成"
        echo -e "${GREEN}按回车键返回主菜单${NC}"
        read -r
    else
        log_error "脚本 ${script} 不存在"
        sleep 2
        return 1
    fi
}

# 初始化
init() {
    check_permissions
    check_system_dependencies
    check_dependencies
}

# 主循环
main() {

    local choice
    local action
    local script_name
    
    while true; do
        show_menu
        read -r choice
        
        case "$choice" in
            1)
                script_name="setup_alacritty.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            2)
                script_name="setup_chatgpt.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            3)
                script_name="setup_terminalgpt.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            4)
                script_name="setup_tgpt.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            5)
                script_name="setup_rime.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            6)
                script_name="setup_fonts.sh"
                action=$(get_action "$script_name")
                [ "$action" != "back" ] && run_script "$script_name" "$action"
                ;;
            q|Q)
                log_success "感谢使用！再见！"
                exit 0
                ;;
            *)
                log_error "无效的选项，请重试"
                sleep 1
                ;;
        esac

    done
}

# 执行主程序
init
main