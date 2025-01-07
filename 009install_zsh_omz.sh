#!/bin/bash

# 强制使用bash执行
function force_bash() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "==============================================="
        echo "警告：此脚本必须在 bash 环境中运行"
        echo "当前检测到 zsh 环境，正在切换到 bash 重新执行..."
        echo "==============================================="
        sleep 1
        exec bash "$0" "$@"
        exit 0
    elif [ -z "$BASH_VERSION" ]; then
        echo "==============================================="
        echo "错误：此脚本必须在 bash 环境中运行"
        echo "请使用以下命令重新执行："
        echo "    bash $0"
        echo "==============================================="
        exit 1
    fi
}

# 立即检查shell类型
force_bash "$@"

# 引入日志相关配置
source 001log2File.sh

# 全局变量
OH_MY_ZSH_CUSTOM=""
BACKUP_DIR=""
TIMEOUT=30  # 网络操作超时时间

# 显示进度条函数
show_progress() {
    local message="$1"
    echo -n "$message "
    while true; do
        echo -n "."
        sleep 1
    done
}

# 检查权限函数
check_permissions() {
    # 检查是否使用sudo运行
    if [[ $EUID -eq 0 ]]; then
        if [[ -z "$SUDO_USER" ]]; then
            echo "请使用 sudo 运行此脚本，而不是直接以 root 用户运行"
            exit 1
        fi
    else
        echo "请使用 sudo 运行此脚本"
        exit 1
    fi

    # 确保REAL_USER和REAL_HOME正确设置
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

    # 验证用户主目录
    if [[ ! -d "$REAL_HOME" ]]; then
        log 3 "用户 $REAL_USER 的主目录 $REAL_HOME 不存在"
        exit 1
    fi

    # 验证权限
    if ! sudo -u "$REAL_USER" test -w "$REAL_HOME"; then
        log 3 "用户 $REAL_USER 没有对 $REAL_HOME 的写入权限"
        exit 1
    fi
}

# 检查环境函数
check_environment() {
    # 初始化全局变量
    OH_MY_ZSH_CUSTOM="$REAL_HOME/.oh-my-zsh/custom"
    BACKUP_DIR="$REAL_HOME/.shell_backup/$(date +%Y%m%d_%H%M%S)"

    # 确保备份目录存在
    if ! sudo -u "$REAL_USER" mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        log 3 "创建备份目录失败"
        return 1
    fi

    # 确保备份目录权限正确
    sudo chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$BACKUP_DIR"
    sudo chmod 755 "$BACKUP_DIR"
}

# 网络检测函数
check_network() {
    local test_hosts=("google.com" "github.com" "8.8.8.8")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    log 3 "网络连接失败，请检查网络设置"
    return 1
}

# 改进的备份函数
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        if ! cp -p "$file" "$BACKUP_DIR/"; then
            log 3 "备份 $file 失败"
            return 1
        fi
        
        # 确保备份文件属于正确的用户
        sudo chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$BACKUP_DIR"
        
        log 2 "已备份 $file 到 $BACKUP_DIR"
        
        # 验证备份
        if ! diff "$file" "$BACKUP_DIR/$(basename "$file")" >/dev/null; then
            log 3 "备份验证失败"
            return 1
        fi
    fi
    return 0
}


# 带有重试的git clone函数
function git_clone_with_retry {
    local repo_url=$1
    local target_dir=$2
    local max_attempts=3
    local retry_delay=5

    # 检查目标目录是否存在且非空
    if [ -d "$target_dir" ] && [ "$(ls -A $target_dir)" ]; then
        echo "目标目录 $target_dir 已存在且非空，正在删除..."
        rm -rf "$target_dir"
    fi

    local counter=0
    until [ "$counter" -ge $max_attempts ]
    do
        git clone "$repo_url" "$target_dir" && break
        counter=$((counter+1))
        if [ "$counter" -eq $max_attempts ]; then
            echo "Failed to clone $repo_url after $max_attempts attempts. Aborting."
            return 1
        fi
        echo "git clone failed, retrying in $retry_delay seconds..."
        sleep $retry_delay
    done
    
    return 0
}

# 改进的软件包安装函数
__install_if_missing() {
    local package="$1"
    if [[ -z "$package" ]]; then
        log 3 "无效的包名"
        return 1
    fi
    
    # 先更新包列表
    log 1 "正在更新包列表..."
    local progress_pid
    show_progress "更新中" & progress_pid=$!
    
    if ! sudo apt-get update -qq; then
        kill $progress_pid
        log 3 "更新包列表失败"
        return 1
    fi
    kill $progress_pid

    # 检查包是否已安装并且可用
    if ! command -v "$package" >/dev/null 2>&1; then
        log 1 "正在安装 $package..."
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
            log 3 "安装 $package 失败"
            return 1
        fi
        log 2 "$package 安装成功"
    else
        log 2 "$package 已安装"
    fi
}

# 改进的 zsh 和 oh-my-zsh 安装函数
install_zsh_and_ohmyzsh() {
    log 1 "检查环境，如果存在zsh就先删除，并清理其配置文件"
    
    # 备份现有的配置文件
    backup_file "$REAL_HOME/.zshrc"
    backup_file "$REAL_HOME/.zsh_history"
    
    # 如果zsh已安装，先卸载
    if command -v zsh >/dev/null 2>&1; then
        # 检查当前shell是否为zsh
        if [ -n "$ZSH_VERSION" ]; then
            log 1 "检测到当前在zsh环境中运行，切换到bash重新执行..."
            exec bash "$0" "$@"
            exit 0
        fi

        # 如果当前默认shell是zsh，先改回bash
        if grep -q "^$USER.*zsh$" /etc/passwd; then
            log 1 "检测到默认shell是zsh，先改回bash..."
            sudo chsh -s /bin/bash "$USER"
        fi

        log 1 "检测到 zsh 已安装，正在删除..."
        # 更新软件包列表
        sudo apt update
        # 删除 zsh
        sudo apt purge -y zsh
        # 清理不需要的依赖
        sudo apt autoremove -y
    fi

    # 清理所有zsh相关配置文件
    log 1 "清理zsh配置文件..."
    sudo rm -rf "$REAL_HOME/.oh-my-zsh"
    sudo rm -rf "$REAL_HOME/.zshrc"
    sudo rm -rf "$REAL_HOME/.zsh_history"
    sudo rm -rf "$OH_MY_ZSH_CUSTOM"
    sudo rm -rf "$OH_MY_ZSH_CUSTOM/incr"

    log 1 "开始安装 zsh..."
    
    # 安装 zsh
    __install_if_missing "zsh" "retry"|| return 1

    # # 安装 retry
    # __install_if_missing "retry"|| return 1

    # 手动安装 oh-my-zsh
    if [[ ! -d "$REAL_HOME/.oh-my-zsh" ]] || [[ -z "$(ls -A $REAL_HOME/.oh-my-zsh)" ]]; then
        log 1 "安装 oh-my-zsh..."
        if ! git_clone_with_retry "https://github.com/ohmyzsh/ohmyzsh.git" "$REAL_HOME/.oh-my-zsh"; then
            log 3 "安装 oh-my-zsh 失败"
            log 3 "安装终止！oh-my-zsh 是必需组件，无法继续安装其他功能"
            exit 1
        fi
    fi

    cp "$REAL_HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$REAL_HOME/.zshrc"

    log 1 "更改默认 shell"
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        log 1 "更改默认 shell 为 zsh..."
        sudo chsh -s "$(which zsh)" "$REAL_USER"
    fi

    # 确保权限正确
    sudo chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$REAL_HOME/.oh-my-zsh"
    sudo chown "$REAL_USER:$(id -gn "$REAL_USER")" "$REAL_HOME/.zshrc"

    log 2 "zsh 和 oh-my-zsh 安装完成"
}

# 卸载软件包
__uninstall_package() {
    local package="$1"
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "installed"; then
        log 1 "正在卸载 $package..."
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$package"; then
            log 3 "卸载 $package 失败"
            return 1
        fi
        sudo apt-get autoremove -y
        log 2 "$package 卸载成功"
    else
        log 2 "$package 未安装"
    fi
}

# 安装字体
install_MesloLGS_fonts() {
    log 1 "正在安装 MesloLGS NF 字体..."
    
    # 安装字体相关依赖
    log 1 "安装字体相关依赖..."
    __install_if_missing "fontconfig" || return 1
    __install_if_missing "xfonts-utils" || return 1
    
    local font_dir="$REAL_HOME/.local/share/fonts"
    local font_cache_dir="$REAL_HOME/.cache/fontconfig"
    
    # 清理旧的字体文件和缓存
    log 1 "清理旧的字体文件..."
    sudo rm -rf "$font_dir"/MesloLGS*
    sudo rm -rf "$font_cache_dir"
    
    # 确保字体目录存在且属于正确的用户
    sudo -u "$REAL_USER" mkdir -p "$font_dir"
    sudo -u "$REAL_USER" mkdir -p "$font_cache_dir"
    
    # 设置正确的权限
    sudo chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$font_dir"
    sudo chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$font_cache_dir"
    sudo chmod 755 "$font_dir"
    sudo chmod 755 "$font_cache_dir"
    
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
        log 1 "下载字体: $font"
        if ! sudo -u "$REAL_USER" curl -L \
            --retry 3 \
            --retry-delay 5 \
            --retry-max-time 60 \
            --connect-timeout 30 \
            --max-time 120 \
            --progress-bar \
            -o "$font_dir/$font" \
            "https://github.com/romkatv/powerlevel10k/raw/master/font/$font"; then
            log 3 "下载 $font 失败"
            success=false
            break
        fi
        # 设置字体文件权限
        sudo chmod 644 "$font_dir/$font"
    done

    if $success; then
        # 更新字体缓存
        log 1 "更新字体缓存..."
        
        # 先尝试用用户权限更新
        if ! sudo -u "$REAL_USER" fc-cache -f "$font_dir" 2>/dev/null; then
            log 2 "用户权限更新缓存失败，尝试使用root权限..."
            # 如果失败，使用root权限更新
            if ! fc-cache -f "$font_dir" 2>/dev/null; then
                log 3 "字体缓存更新失败"
                return 1
            fi
        fi
        
        # 等待字体缓存更新完成
        sleep 2
        
        # 检查字体文件是否存在
        local font_found=false
        for font in "${fonts[@]}"; do
            if [[ -f "$font_dir/$font" ]]; then
                font_found=true
                break
            fi
        done

        if $font_found; then
            log 2 "MesloLGS NF 字体安装成功"
            # 检查是否在WSL环境中
            if grep -qi microsoft /proc/version; then
                log 1 "检测到WSL环境，请在Windows终端中手动安装字体文件"
                log 1 "字体文件位置: $(wslpath -w "$font_dir")"
                log 1 "请在Windows中双击字体文件进行安装"
                printf "WSL 中无法像传统 Linux 系统一样直接安装字体。WSL 运行在 Windows 之上，字体渲染由 Windows 系统完成，而非 WSL 本身。\n因此，要在 WSL 终端使用新字体，必须在 Windows 系统中安装字体。安装后，在运行 WSL 发行版的终端模拟器（如 Windows Terminal 或 ConEmu）中选择该字体即可。\n步骤：\n1. 在 Windows 中安装字体：下载字体文件（通常为 .ttf 或 .otf 文件），双击安装。\n2. 在终端中选择字体：打开终端模拟器的设置，更改为新安装的字体。具体步骤取决于使用的终端模拟器。\n简而言之，字体安装在 Windows 宿主机操作系统中，WSL 环境使用宿主系统提供的字体。\n"
                
            fi
            # 确保所有用户都能访问字体
            sudo chmod -R +r "$font_dir"
            return 0
        else
            log 3 "字体文件未能成功保存"
            return 1
        fi
    else
        log 3 "字体安装失败"
        return 1
    fi
}

# 卸载字体
uninstall_MesloLGS_fonts() {
    log 1 "正在卸载 MesloLGS NF 字体..."
    local font_dir="$REAL_HOME/.local/share/fonts"
    
    if [[ -d "$font_dir" ]]; then
        sudo -u "$REAL_USER" rm -f "$font_dir"/MesloLGS*
        sudo -u "$REAL_USER" fc-cache -f -v
        
        if ! fc-list | grep -q "MesloLGS"; then
            log 2 "MesloLGS NF 字体卸载成功"
        else
            log 3 "字体未完全卸载"
            return 1
        fi
    else
        log 2 "字体目录不存在，无需卸载"
    fi
}

# 配置 oh-my-zsh
configure_ohmyzsh() {
    log 1 "配置 oh-my-zsh 插件..."
    
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
            log 2 "插件 $plugin 已存在"
            continue
        fi
        
        log 1 "安装插件: $plugin..."
        if ! sudo -u "$REAL_USER" git clone "${plugins[$plugin]}" "$plugin_dir"; then
            log 3 "安装插件失败: $plugin"
            return 1
        fi
    done

    # 更新 .zshrc
    local zshrc="$REAL_HOME/.zshrc"
    local plugins_line='plugins=(git zsh-autosuggestions zsh-completions autojump git-extras zsh-syntax-highlighting docker sudo zsh-interactive-cd)'
    
    if ! grep -q "^plugins=" "$zshrc"; then
        echo "$plugins_line" | sudo -u "$REAL_USER" tee -a "$zshrc" > /dev/null
    else
        sudo -u "$REAL_USER" sed -i "/^plugins=/c\\$plugins_line" "$zshrc"
    fi

    # 配置 incr
    log 1 "检查 incr 安装..."
    local incr_dir="$OH_MY_ZSH_CUSTOM/incr"
    local incr_file="$incr_dir/incr-0.2.zsh"
    
    if [[ -f "$incr_file" ]]; then
        log 2 "incr 已安装"
    else
        log 1 "安装 incr..."
        sudo -u "$REAL_USER" mkdir -p "$incr_dir"
        if ! sudo -u "$REAL_USER" wget -O "$incr_file" https://mimosa-pudica.net/src/incr-0.2.zsh; then
            log 3 "下载 incr 失败"
            return 1
        fi
        log 2 "incr 安装成功"
    fi

    log 1 "Configuring incr..."
    local incr_source="source $OH_MY_ZSH_CUSTOM/incr/incr-0.2.zsh"
    if ! grep -q "$incr_source" "$zshrc"; then
        echo "$incr_source" | sudo -u "$REAL_USER" tee -a "$zshrc" > /dev/null
    fi

}

# 配置 Powerlevel10k
configure_powerlevel10k() {
    log 1 "配置 powerlevel10k 主题..."
    
    local theme_dir="$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"
    
    # 克隆主题
    if [[ ! -d "$theme_dir" ]]; then
        if ! sudo -u "$REAL_USER" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"; then
            log 3 "克隆 powerlevel10k 失败"
            return 1
        fi
    fi

    # 配置主题
    local zshrc="$REAL_HOME/.zshrc"
    local theme_source="source $theme_dir/powerlevel10k.zsh-theme"
    
    if ! grep -q "$theme_source" "$zshrc"; then
        echo "$theme_source" | sudo -u "$REAL_USER" tee -a "$zshrc" > /dev/null
    fi
    
    # 设置主题
    sudo -u "$REAL_USER" sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"

    # 下载 .p10k.zsh
    if ! sudo -u "$REAL_USER" curl -L \
        --retry 3 \
        --retry-delay 5 \
        --retry-max-time 60 \
        --connect-timeout 30 \
        --max-time 120 \
        --progress-bar \
        -o "$REAL_HOME/.p10k.zsh" \
        "https://github.com/gushmazuko/Powerlevel10k/raw/refs/heads/master/.p10k.zsh"; then
        log 3 "下载 .p10k.zsh 失败"
        return 1
    fi

    # 修改.zshrc中的默认启动项
    local wizard_config='POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true'
    if ! grep -q "^$wizard_config" "$zshrc"; then
        echo "$wizard_config" | sudo -u "$REAL_USER" tee -a "$zshrc" > /dev/null
    fi

    # 安装字体
    install_MesloLGS_fonts
}

# 卸载 Powerlevel10k
uninstall_powerlevel10k() {
    log 1 "移除 Powerlevel10k..."
    
    # 备份配置文件
    backup_file "$REAL_HOME/.p10k.zsh"
    backup_file "$REAL_HOME/.zshrc"
    
    # 删除主题目录
    local theme_dir="$OH_MY_ZSH_CUSTOM/themes/powerlevel10k"
    if [[ -d "$theme_dir" ]]; then
        sudo rm -rf "$theme_dir"
    fi

    # 删除配置文件
    sudo rm -f "$REAL_HOME/.p10k.zsh"

    # 更新 .zshrc
    local zshrc="$REAL_HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        sudo -u "$REAL_USER" sed -i '/source.*powerlevel10k.*powerlevel10k.zsh-theme/d' "$zshrc"
        sudo -u "$REAL_USER" sed -i 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME="robbyrussell"/' "$zshrc"
    fi

    # 卸载字体
    uninstall_MesloLGS_fonts
}

# 卸载 zsh 和 oh-my-zsh
uninstall_zsh_and_ohmyzsh() {
    log 1 "开始卸载 zsh..."
    
    # 如果当前在zsh中运行，先切换到bash
    if [ -n "$ZSH_VERSION" ]; then
        log 1 "检测到当前在zsh环境中运行，切换到bash重新执行..."
        exec bash "$0" "$@"
        exit 0
    fi
    
    log 1 "将默认 shell 改回 bash..."
    sudo chsh -s "$(which bash)" "$REAL_USER"
    
    # 备份重要文件
    backup_file "$REAL_HOME/.zshrc"
    backup_file "$REAL_HOME/.zsh_history"
    
    # 删除相关目录和文件
    local files_to_remove=(
        "$REAL_HOME/.oh-my-zsh"
        "$REAL_HOME/.zshrc"
        "$REAL_HOME/.zsh_history"
        "$OH_MY_ZSH_CUSTOM"
        "$OH_MY_ZSH_CUSTOM/incr"
    )

    for file in "${files_to_remove[@]}"; do
        if [[ -e "$file" ]]; then
            log 1 "删除 $file..."
            sudo rm -rf "$file"
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

# 改进的主函数
main_zsh_setup() {
    # 检查用户权限
    check_permissions

    # 检查环境
    check_environment

    # 检查网络连接
    check_network

    # 解析参数
    case "$1" in
        install)
            install_zsh_and_ohmyzsh
            configure_ohmyzsh
            configure_powerlevel10k
            log 2 "Zsh 和 oh-my-zsh 已安装和配置完成。并已配置 Powerlevel10k 主题。安装了MesloLGS字体"
            log 2 "可以输入命令p10k configure手动配置其他主题。"
            ;;
        uninstall)
            uninstall_powerlevel10k
            uninstall_zsh_and_ohmyzsh
            ;;
        *)
            echo "用法: sudo $0 {install|uninstall}"
            exit 1
            ;;
    esac
}

# 检查参数并执行
if [[ "$#" -ne 1 ]]; then
    echo "用法: sudo $0 {install|uninstall}"
    exit 1
fi

# 导出全局变量
export REAL_USER
export REAL_HOME

# 如果脚本被直接运行（不是被source）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 执行主函数，传递所有参数
    main_zsh_setup "$@"
fi