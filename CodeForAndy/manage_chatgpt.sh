#!/bin/bash

## https://github.com/0xacx/chatGPT-shell-cli

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Get real user when script is run with sudo
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    elif [ -n "$USER" ]; then
        echo "$USER"
    else
        error_exit "Could not determine the real user"
    fi
}

# Get real user's home directory
get_real_home() {
    local real_user
    real_user=$(get_real_user)
    local home_dir
    
    if [ "$real_user" = "root" ]; then
        error_exit "This script should not be run as the root user directly. Please use 'sudo' instead."
    fi
    
    home_dir=$(getent passwd "$real_user" | cut -d: -f6)
    if [ -z "$home_dir" ]; then
        error_exit "Could not determine home directory for user $real_user"
    fi
    
    echo "$home_dir"
}

# Check sudo privileges
check_sudo() {
    if ! sudo -v &>/dev/null; then
        error_exit "This script requires sudo privileges. Please run with sudo or grant sudo access."
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
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
}

# Function to install glow
install_glow() {
    echo "Installing glow for Markdown rendering..."
    
    # Check if system is Debian-based
    if ! command -v apt-get >/dev/null 2>&1; then
        error_exit "This script currently only supports Debian-based systems"
    fi

    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings || error_exit "Failed to create keyrings directory"
    
    # Download and install GPG key
    echo "Adding Charm repository GPG key..."
    if ! curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg; then
        error_exit "Failed to add Charm GPG key"
    fi
    
    # Add repository
    echo "Adding Charm repository..."
    if ! echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null; then
        error_exit "Failed to add Charm repository"
    fi
    
    # Update package list
    echo "Updating package list..."
    if ! sudo apt-get update; then
        error_exit "Failed to update package list"
    fi
    
    # Install glow
    echo "Installing glow..."
    if ! sudo apt-get install -y glow; then
        error_exit "Failed to install glow"
    fi
    
    # Verify installation
    if ! command -v glow >/dev/null 2>&1; then
        error_exit "Glow installation verification failed"
    fi
    
    echo "Glow installed successfully!"
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

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            if [[ "$action" == "add" ]]; then
                if ! grep -q "source $env_file" "$config"; then
                    # Use real user to modify their own config files
                    sudo -u "$real_user" tee -a "$config" >/dev/null <<< "source $env_file" || \
                        error_exit "Failed to update $config"
                    updated=true
                fi
            elif [[ "$action" == "remove" ]]; then
                # Use real user to modify their own config files
                sudo -u "$real_user" sed -i "/source $env_file/d" "$config" || \
                    error_exit "Failed to update $config"
                updated=true
            fi
        fi
    done

    if $updated; then
        echo "Shell configurations have been updated for user $real_user"
        echo "Please restart your shell or run 'source ~/.bashrc' or 'source ~/.zshrc' to apply changes."
    else
        echo "No shell configurations were updated for user $real_user"
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
    echo "Operating for user: $real_user (home: $real_home)"

    # Validate input
    [[ -z "$action" ]] && error_exit "Action parameter is required. Use 'install' or 'uninstall'"
    [[ "$action" != "install" && "$action" != "uninstall" ]] && \
        error_exit "Invalid action: $action. Use 'install' or 'uninstall'"

    # Check dependencies
    check_dependencies

    # Ensure proper ownership of created files
    fix_ownership() {
        local path="$1"
        sudo chown "$real_user:$(id -gn "$real_user")" "$path"
    }

    if [[ "$action" == "install" ]]; then
        echo "Installing chatgpt.sh..."
        
        # Verify sudo access at the start
        check_sudo
        
        # First install glow if not present
        if ! command -v glow >/dev/null 2>&1; then
            echo "Glow is not installed. Installing..."
            install_glow
        else
            echo "Glow is already installed."
        fi

        # Check write permissions
        if [[ ! -w "$(dirname "$install_path")" ]]; then
            error_exit "No write permission to $(dirname "$install_path"). Try running with sudo."
        fi

        # Download chatgpt.sh
        local temp_file=$(mktemp)
        if ! curl -s -o "$temp_file" https://raw.githubusercontent.com/0xacx/chatGPT-shell-cli/main/chatgpt.sh; then
            rm -f "$temp_file"
            error_exit "Failed to download chatgpt.sh"
        fi

        # Verify download
        if [[ ! -s "$temp_file" ]]; then
            rm -f "$temp_file"
            error_exit "Downloaded file is empty"
        fi

        # Move to final location
        if ! mv "$temp_file" "$install_path"; then
            rm -f "$temp_file"
            error_exit "Failed to install chatgpt.sh to $install_path"
        fi

        # Make executable
        chmod +x "$install_path" || error_exit "Failed to make chatgpt.sh executable"

        # Handle API key
        while true; do
            read -p "Enter your OpenAI API key: " openai_key
            if [[ -z "$openai_key" ]]; then
                echo "API key cannot be empty. Please try again."
                continue
            fi
            if [[ ! "$openai_key" =~ ^sk-[A-Za-z0-9]{48}$ ]]; then
                echo "Warning: API key format looks incorrect. Continue anyway? (y/n)"
                read -r response
                [[ "$response" != "y" ]] && continue
            fi
            break
        done

        # Create backup directory if it doesn't exist
        sudo -u "$real_user" mkdir -p "$backup_dir" || error_exit "Failed to create backup directory"

        # Backup existing env file if it exists
        if [[ -f "$env_file" ]]; then
            sudo -u "$real_user" cp "$env_file" "${env_file}.backup" || \
                error_exit "Failed to backup existing env file"
        fi

        # Save configurations with proper ownership
        {
            echo "export OPENAI_KEY=$openai_key"
            echo "export MARKDOWN_RENDER=glow"
        } | sudo -u "$real_user" tee "$env_file" >/dev/null || error_exit "Failed to save configurations"

        # Update shell configurations
        update_shell_configs "$env_file" "add"

        echo "Installation completed successfully!"

    elif [[ "$action" == "uninstall" ]]; then
        echo "Uninstalling chatgpt.sh..."
        
        # Verify sudo access
        check_sudo
        
        # Create backup directory
        sudo -u "$real_user" mkdir -p "$backup_dir" || error_exit "Failed to create backup directory"

        # Backup existing files
        if [[ -f "$install_path" ]]; then
            sudo -u "$real_user" cp "$install_path" "$backup_dir/chatgpt.sh.backup" || \
                error_exit "Failed to backup chatgpt.sh"
        fi
        
        if [[ -f "$env_file" ]]; then
            sudo -u "$real_user" cp "$env_file" "$backup_dir/chatgpt_env.backup" || \
                error_exit "Failed to backup env file"
        fi

        # Remove files
        rm -f "$install_path" || error_exit "Failed to remove $install_path"
        sudo -u "$real_user" rm -f "$env_file" || error_exit "Failed to remove $env_file"

        # Ask if user wants to remove glow
        read -p "Do you want to remove glow Markdown renderer as well? (y/n) " remove_glow
        if [[ "$remove_glow" == "y" ]]; then
            sudo apt-get remove -y glow || echo "Warning: Failed to remove glow"
        fi

        # Update shell configurations
        update_shell_configs "$env_file" "remove"

        echo "Uninstallation completed successfully!"
        echo "Backups saved in $backup_dir"
    fi
}



# 检查是否使用sudo运行脚本
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        echo "ERROR: This script must be run with sudo privileges." >&2
        echo "Usage: sudo bash $0 <install|uninstall>" >&2
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
main() {
    # 验证sudo权限
    check_root_privileges

    # 验证参数数量
    if [ "$#" -ne 1 ]; then
        print_usage
        exit 1
    fi

    # 验证参数有效性
    case "$1" in
        install|uninstall)
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
    main "$@"
fi