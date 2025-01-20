#!/bin/bash
###############################################################################
# 脚本名称：setup_chatgpt.sh
# 作用：安装/卸载 chatGPT 终端
# 作者：CodeParetoImpove cogitate3 Claude.ai
# 源代码：https://github.com/0xacx/chatGPT-shell-cli
# 版本：1.3
# 用法：
#   安装: ./setup_chatgpt.sh install
#   卸载: ./setup_chatgpt.sh uninstall
###############################################################################

source "$(dirname "$0")/log.sh"
# 设置日志文件
mkdir -p "$HOME/logs"

# 先设置日志
log "$HOME/logs/$(basename "$0").log" 1 "第一条消息，同时设置日志文件路径"
log 1 "日志记录在${CURRENT_LOG_FILE}"

# Get real user when script is run with sudo
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    elif [ -n "$USER" ]; then
        echo "$USER"
    else
        log 3 "Could not determine the real user"
        exit 1
    fi
}

# Get real user's home directory
get_real_home() {
    local real_user
    real_user=$(get_real_user)
    local home_dir

    if [ "$real_user" = "root" ]; then
        log 3 "This script should not be run as the root user directly. Please use 'sudo' instead."
        exit 1
    fi

    home_dir=$(getent passwd "$real_user" | cut -d: -f6)
    if [ -z "$home_dir" ]; then
        log 3 "Could not determine home directory for user $real_user"
        exit 1
    fi

    echo "$home_dir"
}

# Check sudo privileges
check_sudo() {
    if ! sudo -v &>/dev/null; then
        log 3 "This script requires sudo privileges. Please run with sudo or grant sudo access."
        exit 1
    fi

    # Keep sudo alive
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

# Check dependencies function
check_dependencies() {
    local missing_deps=()
    for cmd in curl grep sed chmod sudo gpg; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log 3 "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Function to install glow
install_glow() {
    log 1 "Installing glow for Markdown rendering..."

    # Check if system is Debian-based
    if ! command -v apt-get >/dev/null 2>&1; then
        log 3 "This script currently only supports Debian-based systems"
        exit 1
    fi

    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings || {
        log 3 "Failed to create keyrings directory"
        exit 1
    }

    # Download and install GPG key
    log 1 "Adding Charm repository GPG key..."
    if ! curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg; then
        log 3 "Failed to add Charm GPG key"
        exit 1
    fi

    # Add repository
    log 1 "Adding Charm repository..."
    if ! echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null; then
        log 3 "Failed to add Charm repository"
        exit 1
    fi

    # Update package list
    log 1 "Updating package list..."
    if ! sudo apt-get update; then
        log 3 "Failed to update package list"
        exit 1
    fi

    # Install glow
    log 1 "Installing glow..."
    if ! sudo apt-get install -y glow; then
        log 3 "Failed to install glow"
        exit 1
    fi

    # Verify installation
    if ! command -v glow >/dev/null 2>&1; then
        log 3 "Glow installation verification failed"
        exit 1
    fi

    log 1 "Glow installed successfully!"
}

# Function to update shell config files
update_shell_configs() {
    local env_file="$1"
    local action="$2" # "add" or "remove"
    local updated=false
    local real_home
    real_home=$(get_real_home)
    local real_user
    real_user=$(get_real_user)

    # List of supported shell config files
    local shell_configs=("$real_home/.bashrc" "$real_home/.zshrc")

    # 转义环境文件路径中的特殊字符
    local escaped_env_file
    escaped_env_file=$(echo "$env_file" | sed 's/[\/&]/\\&/g')

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            if [[ "$action" == "add" ]]; then
                if ! grep -q "source $env_file" "$config"; then
                    # Use real user to modify their own config files
                    sudo -u "$real_user" tee -a "$config" >/dev/null <<<"source $env_file" ||
                        {
                            log 3 "Failed to update $config"
                            exit 1
                        }
                    updated=true
                fi
            elif [[ "$action" == "remove" ]]; then
                # Use real user to modify their own config files
                if ! sudo -u "$real_user" sed -i "/source ${escaped_env_file}/d" "$config"; then
                    log 3 "Failed to update $config"
                    exit 1
                fi
                updated=true
            fi
        fi
    done

    if $updated; then
        log 1 "Shell configurations have been updated for user $real_user"
        log 1 "Please restart your shell or run 'source ~/.bashrc' or 'source ~/.zshrc' to apply changes."
    else
        log 1 "No shell configurations were updated for user $real_user"
    fi
}

# Main function
manage_chatgpt_sh() {
    local action="$1"
    local install_path="/usr/local/bin/chatgpt.sh"

    # Get correct home directory
    local real_home
    real_home=$(get_real_home)
    local env_file="$real_home/.chatgpt_env"
    local backup_dir="$real_home/.chatgpt_backup"

    # Validate real user and home directory
    local real_user
    real_user=$(get_real_user)
    log 1 "Operating for user: $real_user (home: $real_home)"

    # Validate input
    [[ -z "$action" ]] && {
        log 3 "Action parameter is required. Use 'install' or 'uninstall'"
        exit 1
    }
    [[ "$action" != "install" && "$action" != "uninstall" ]] &&
        {
            log 3 "Invalid action: $action. Use 'install' or 'uninstall'"
            exit 1
        }

    # Check dependencies
    check_dependencies

    # Ensure proper ownership of created files
    fix_ownership() {
        local path="$1"
        sudo chown "$real_user:$(id -gn "$real_user")" "$path"
    }

    if [[ "$action" == "install" ]]; then
        log 1 "Installing chatgpt.sh..."

        # Verify sudo access at the start
        check_sudo

        # First install glow if not present
        if ! command -v glow >/dev/null 2>&1; then
            log 1 "Glow is not installed. Installing..."
            install_glow
        else
            log 1 "Glow is already installed."
        fi

        # Check write permissions
        if [[ ! -w "$(dirname "$install_path")" ]]; then
            log 3 "No write permission to $(dirname "$install_path"). Try running with sudo."
            exit 1
        fi

        # Download chatgpt.sh
        local temp_file=$(mktemp)
        if ! curl -s -o "$temp_file" https://raw.githubusercontent.com/0xacx/chatGPT-shell-cli/main/chatgpt.sh; then
            rm -f "$temp_file"
            log 3 "Failed to download chatgpt.sh"
            exit 1
        fi

        # Verify download
        if [[ ! -s "$temp_file" ]]; then
            rm -f "$temp_file"
            log 3 "Downloaded file is empty"
            exit 1
        fi

        # Move to final location
        if ! mv "$temp_file" "$install_path"; then
            rm -f "$temp_file"
            log 3 "Failed to install chatgpt.sh to $install_path"
            exit 1
        fi

        # Set permissions (755 = rwxr-xr-x)
        if ! chmod 755 "$install_path"; then
            log 3 "Failed to set executable permissions for chatgpt.sh"
            exit 1
        fi

        # Ensure the script is owned by root but readable/executable by all
        if ! chown root:root "$install_path"; then
            log 3 "Failed to set ownership for chatgpt.sh"
            exit 1
        fi

        # Handle API key
        while true; do
            read -p "Enter your OpenAI API key: " openai_key
            if [[ -z "$openai_key" ]]; then
                log 1 "API key cannot be empty. Please try again."
                continue
            fi
            if [[ ! "$openai_key" =~ ^sk-[A-Za-z0-9]{48}$ ]]; then
                log 1 "Warning: API key format looks incorrect. Continue anyway? (y/n)"
                read -r response
                [[ "$response" != "y" ]] && continue
            fi
            break
        done

        # Create backup directory if it doesn't exist
        sudo -u "$real_user" mkdir -p "$backup_dir" || {
            log 3 "Failed to create backup directory"
            exit 1
        }

        # Backup existing env file if it exists
        if [[ -f "$env_file" ]]; then
            sudo -u "$real_user" cp "$env_file" "${env_file}.backup" ||
                {
                    log 3 "Failed to backup existing env file"
                    exit 1
                }
        fi

        # Save configurations with proper ownership
        {
            echo "export OPENAI_KEY=$openai_key"
            echo "export MARKDOWN_RENDER=glow"
        } | sudo -u "$real_user" tee "$env_file" >/dev/null || {
            log 3 "Failed to save configurations"
            exit 1
        }

        # Update shell configurations
        update_shell_configs "$env_file" "add"

        log 1 "Installation completed successfully!"

    elif [[ "$action" == "uninstall" ]]; then
        log 1 "Uninstalling chatgpt.sh..."

        # Verify sudo access
        check_sudo

        # Create backup directory
        sudo -u "$real_user" mkdir -p "$backup_dir" || {
            log 3 "Failed to create backup directory"
            exit 1
        }

        # Backup existing files
        if [[ -f "$install_path" ]]; then
            # 使用sudo进行复制，然后修改所有权
            if ! sudo cp "$install_path" "$backup_dir/chatgpt.sh.backup"; then
                log 3 "Failed to backup chatgpt.sh"
                exit 1
            fi
            # 修改备份文件的所有权
            if ! sudo chown "$real_user:$(id -gn "$real_user")" "$backup_dir/chatgpt.sh.backup"; then
                log 3 "Failed to change ownership of backup file"
                exit 1
            fi
        fi

        if [[ -f "$env_file" ]]; then
            if ! sudo cp "$env_file" "$backup_dir/chatgpt_env.backup"; then
                log 3 "Failed to backup env file"
                exit 1
            fi
            if ! sudo chown "$real_user:$(id -gn "$real_user")" "$backup_dir/chatgpt_env.backup"; then
                log 3 "Failed to change ownership of env backup file"
                exit 1
            fi
        fi

        # Remove files (使用sudo)
        if ! sudo rm -f "$install_path"; then
            log 3 "Failed to remove $install_path"
            exit 1
        fi
        if ! sudo -u "$real_user" rm -f "$env_file"; then
            log 3 "Failed to remove $env_file"
            exit 1
        fi

        # Ask if user wants to remove glow
        read -p "Do you want to remove glow Markdown renderer as well? (y/n) " remove_glow
        if [[ "$remove_glow" == "y" ]]; then
            sudo apt-get remove -y glow || log 2 "Failed to remove glow"
        fi

        # Update shell configurations
        update_shell_configs "$env_file" "remove"

        log 1 "Uninstallation completed successfully!"
        log 1 "Backups saved in $backup_dir"
    fi
}

# 检查是否使用sudo运行脚本
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        log 1 "ERROR: This script must be run with sudo privileges." >&2
        log 1 "Usage: sudo bash $0 <install|uninstall>" >&2
        exit 1
    fi
}

# 打印使用说明
print_usage() {
    echo "Usage: sudo bash $0 <action>"
    echo
    echo "Actions:"
    echo "  install    Install chatGPT shell client"
    echo "  uninstall  Remove chatGPT shell client"
    echo
    echo "Example:"
    echo "  sudo bash $0 install"
}

# 主函数
setup_chatgpt() {
    # 验证sudo权限
    check_root_privileges

    # 验证参数数量
    if [ "$#" -ne 1 ]; then
        print_usage
        exit 1
    fi

    # 验证参数有效性
    case "$1" in
    install | uninstall)
        manage_chatgpt_sh "$1"
        ;;
    *)
        print_usage
        exit 1
        ;;
    esac
}

# 执行主函数，传入所有参数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_chatgpt "$@"
fi
