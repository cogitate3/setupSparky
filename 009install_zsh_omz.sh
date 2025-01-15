#!/bin/bash
###############################################################################
# 脚本名称：install_zsh_omz.sh
# 作用：安装 zsh omz
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 版本：1.0.1
# 用法：
#   安装: ./install_zsh_omz.sh install
#   卸载: ./install_zsh_omz.sh uninstall
###############################################################################

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
# force_bash "$@"

# 引入日志相关配置
source 001log2File.sh
log "/tmp/logs/install_zsh_omz.log" 1 "第一条消息，同时设置日志文件"
log 2 "日志记录在${CURRENT_LOG_FILE}"

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
    zsh_path="$(which zsh)"
    if ! grep -q "$zsh_path" /etc/shells; then
        log 1 "添加 zsh 到 /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi
    
    if [[ "$SHELL" != "$zsh_path" ]]; then
        log 1 "更改默认 shell 为 zsh..."
        sudo chsh -s "$zsh_path" "$REAL_USER"
        # 直接修改 /etc/passwd 以确保更改生效
        if [ -f /etc/passwd ]; then
            sudo sed -i "s|^\($REAL_USER:.*:\)/bin/bash$|\1$zsh_path|" /etc/passwd
            sudo sed -i "s|^\($REAL_USER:.*:\)/bin/sh$|\1$zsh_path|" /etc/passwd
        fi
        log 2 "shell 更改完成，需要重新登录才能生效"
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

url_encode() {
    echo "$1" | sed 's/ /%20/g'
}


install_MesloLGS_fonts() {
    log 1 "正在安装 MesloLGS NF 字体..."
    
    # 安装字体相关依赖
    log 1 "安装字体相关依赖..."
    __install_if_missing "fontconfig" || return 1
    __install_if_missing "xfonts-utils" || return 1
    
    local font_dir="/usr/share/fonts/meslo"
    local font_cache_dir="/var/cache/fontconfig"
    
    # 清理旧的字体文件
    log 1 "清理旧的字体文件..."
    sudo rm -rf "$font_dir"
    
    # 不再删除整个字体缓存目录，仅在后续使用 fc-cache 刷新缓存
    # sudo rm -rf "$font_cache_dir"
    
    # 建立字体目录并设置权限（系统惯例：root:root, 755）
    sudo mkdir -p "$font_dir"
    sudo chown root:root "$font_dir"
    sudo chmod 755 "$font_dir"
    
    # 字体文件数组
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )

    # 下载和安装字体
    local success=true
    local retry_count=3
    local current_try=1
    


    for font in "${fonts[@]}"; do
        while [[ $current_try -le $retry_count ]]; do
            log 1 "下载字体: $font (尝试 $current_try/$retry_count)"
            
            # 保存 curl 的完整输出和错误信息
            local curl_output
            local curl_error
            curl_output=$(sudo curl -L \
                --retry 3 \
                --retry-delay 5 \
                --retry-max-time 60 \
                --connect-timeout 30 \
                --max-time 120 \
                --progress-bar \
                -w "\n%{http_code}" \
                -o "$font_dir/$font" "$(url_encode "https://github.com/romkatv/powerlevel10k-media/raw/master/${font}")" 2>&1)
                
            local http_code=${curl_output##*$'\n'}
            
            if [[ $? -eq 0 ]] && [[ "$http_code" == "200" ]]; then
                log 2 "成功下载: $font"
                sudo chmod 644 "$font_dir/$font"
                break
            else
                # 详细的错误信息
                log 3 "下载 $font 失败 (尝试 $current_try/$retry_count)"
                if [[ "$http_code" != "200" ]]; then
                    log 3 "HTTP 状态码: $http_code"
                    case $http_code in
                        404) log 3 "错误：文件不存在" ;;
                        403) log 3 "错误：访问被拒绝" ;;
                        500) log 3 "错误：服务器内部错误" ;;
                        502|503|504) log 3 "错误：服务器暂时不可用" ;;
                        *) log 3 "错误：未知的 HTTP 错误" ;;
                    esac
                fi
                
                # 网络连接错误检查
                if echo "$curl_output" | grep -qi "could not resolve"; then
                    log 3 "错误：无法解析域名，请检查网络连接"
                elif echo "$curl_output" | grep -qi "connection timed out"; then
                    log 3 "错误：连接超时，请检查网络状态"
                elif echo "$curl_output" | grep -qi "certificate"; then
                    log 3 "错误：SSL 证书验证失败"
                fi
                
                ((current_try++))
                if [[ $current_try -le $retry_count ]]; then
                    log 1 "5秒后重试..."
                    sleep 5
                else
                    log 3 "达到最大重试次数，下载失败"
                    success=false
                    break 2  # 跳出外层循环
                fi
            fi
        done
        current_try=1  # 重置重试计数器，准备下载下一个文件
    done

    if $success; then
        # 更新字体缓存
        log 1 "更新字体缓存..."
        
        # 首先尝试使用 root 权限更新字体缓存
        if ! sudo fc-cache -f -v "$font_dir" 2>/dev/null; then
            log 2 "root 权限更新缓存失败，尝试使用当前用户权限..."
            # 如果失败，使用当前用户权限更新
            if ! fc-cache -f -v "$font_dir" 2>/dev/null; then
                log 3 "字体缓存更新失败"
                return 1
            fi
        fi
        
        # 等待字体缓存更新完成
        sleep 2
        
        # 使用多种方式验证字体安装
        log 1 "验证字体安装..."
        
        # 1. 检查字体文件是否存在
        local all_fonts_found=true
        for font in "${fonts[@]}"; do
            if [[ ! -f "$font_dir/$font" ]]; then
                all_fonts_found=false
                log 3 "字体文件缺失: $font"
                break
            fi
        done
        
        # 2. 使用 fc-list 检查字体是否被系统识别
        local font_recognized=false
        if fc-list | grep -i "MesloLGS NF" > /dev/null; then
            font_recognized=true
            log 2 "系统已识别 MesloLGS NF 字体"
        else
            log 3 "系统未能识别 MesloLGS NF 字体"
        fi
        
        # 3. 显示详细的字体信息
        log 1 "字体详细信息:"
        fc-list | grep -i "MesloLGS NF"
        
        # 4. 检查字体缓存
        log 1 "检查字体缓存:"
        fc-cache -v 2>&1 | grep -i "meslo"
        
        if $all_fonts_found && $font_recognized; then
            log 2 "MesloLGS NF 字体安装成功"
            # 检查是否在 WSL 环境中
            if grep -qi microsoft /proc/version; then
                log 1 "检测到 WSL 环境，请在 Windows 终端中手动安装字体文件"
                log 1 "字体文件位置: $(wslpath -w "$font_dir")"
                printf "WSL 中无法像传统 Linux 系统一样直接安装字体。WSL 运行在 Windows 之上，字体渲染由 Windows 系统完成。\n请在 Windows 中双击字体文件进行安装。\n"
                
                # 在 WSL 环境中提供额外的验证步骤说明
                log 1 "要在 Windows 中验证字体安装："
                log 1 "1. 打开 Windows 设置 -> 个性化 -> 字体"
                log 1 "2. 在搜索框中输入 'MesloLGS'"
                log 1 "3. 或使用 Windows 终端，在配置文件中将字体设置为 'MesloLGS NF'"
            else
                # 在原生 Linux 中提供额外的验证步骤
                log 1 "要在应用程序中验证字体："
                log 1 "1. 运行 'fc-list | grep -i meslo' 查看完整字体信息"
                log 1 "2. 某些应用程序可能需要重启才能识别新字体"
                log 1 "3. 在终端模拟器中，字体名称应该显示为 'MesloLGS NF'"
            fi
            
            # 确保所有用户可读字体
            sudo chmod -R +r "$font_dir"
            return 0
        else
            log 3 "字体安装失败"
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
    local font_dir="/usr/share/fonts/meslo"
    local font_cache_dir="/var/cache/fontconfig"
    
    # 检查是否在 WSL 环境中
    if grep -qi microsoft /proc/version; then
        log 1 "检测到 WSL 环境"
        log 1 "请在 Windows 中手动卸载字体："
        log 1 "1. 打开 Windows 设置 -> 个性化 -> 字体"
        log 1 "2. 搜索 'MesloLGS'"
        log 1 "3. 选择字体并点击卸载"
        # 仍然删除 WSL 中的字体文件
        if [[ -d "$font_dir" ]]; then
            log 1 "删除 WSL 中的字体文件..."
            sudo rm -rf "$font_dir"
        fi
        return 0
    fi
    
    if [[ -d "$font_dir" ]]; then
        # 使用 root 权限删除整个字体目录
        log 1 "删除字体目录..."
        sudo rm -rf "$font_dir"
        
        # 强制更新字体缓存
        log 1 "更新字体缓存..."
        if ! sudo fc-cache -f -v 2>/dev/null; then
            log 2 "root 权限更新缓存失败，尝试使用当前用户权限..."
            fc-cache -f -v 2>/dev/null
        fi
        
        # 等待缓存更新完成
        sleep 2
        
        # 验证卸载结果
        if fc-list | grep -qi "MesloLGS"; then
            log 3 "字体未完全卸载，仍然在系统中发现 MesloLGS 字体"
            # 显示剩余字体的位置
            log 1 "剩余字体位置："
            fc-list | grep -i "MesloLGS"
            return 1
        else
            log 2 "MesloLGS NF 字体卸载成功"
            log 1 "提示：某些应用程序可能需要重启才能反映字体变化"
            return 0
        fi
    else
        log 2 "字体目录不存在，无需卸载"
        return 0
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

    log 1 "下载github.com/cogitate3/setupSparkyLinux 的.p10k.zsh"
    if ! sudo -u "$REAL_USER" curl -L \
        --retry 3 \
        --retry-delay 5 \
        --retry-max-time 60 \
        --connect-timeout 30 \
        --max-time 120 \
        --progress-bar \
        -o "$REAL_HOME/.p10k.zsh" \
        "https://github.com/cogitate3/setupSparkyLinux/blob/develop/config/.p10k.zsh"; then
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

    log 2 ".zshrc 已更新，将在下次启动 zsh 时生效，重新打开终端就会切换到zsh环境了"

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

# # 改进的主函数
# main_zsh_setup() {
#     # 检查用户权限
#     # check_permissions

#     # 检查环境
#     check_environment

#     # 检查网络连接
#     check_network

#     # 解析参数
#     case "$1" in
#         install)
#             install_zsh_and_ohmyzsh
#             configure_ohmyzsh
#             configure_powerlevel10k
#             log 2 "Zsh 和 oh-my-zsh 已安装和配置完成。并已配置 Powerlevel10k 主题。安装了MesloLGS字体"
#             log 2 "可以输入命令p10k configure手动配置其他主题。"
#             log 2 "可以输入命令tail -f ${CURRENT_LOG_FILE}，查看详细安装记录"
#             ;;
#         uninstall)
#             uninstall_powerlevel10k
#             uninstall_zsh_and_ohmyzsh
#             ;;
#         *)
#             echo "用法: sudo bash $0 {install|uninstall}"
#             exit 1
#             ;;
#     esac
# }

# # 检查参数并执行
# if [[ "$#" -ne 1 ]]; then
#     echo "用法: sudo bash $0 {install|uninstall}"
#     exit 1
# fi

# # 导出全局变量
# export REAL_USER
# export REAL_HOME

# # 如果脚本被直接运行（不是被source）
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     # 执行主函数，传递所有参数
#     main_zsh_setup "$@"
# fi