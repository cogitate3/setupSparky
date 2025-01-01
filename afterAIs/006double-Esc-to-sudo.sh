#!/bin/bash

# Function: Add double-ESC key binding to prepend "sudo" to commands
double_esc_to_sudo() {
    # Check if the current shell is bash or zsh
    if [[ ${SHELL} =~ (bash|zsh) ]]; then
        # Check if the current command does not already start with "sudo"
        if [[ "${READLINE_LINE}" != sudo\ * ]]; then
            READLINE_POINT=0
            READLINE_LINE="sudo $READLINE_LINE"
            return 0
        fi
    fi
    return 1
}

# Function: Install the double-ESC-to-sudo configuration
install_double_esc_sudo() {
    local rc_file=""
    local shell_type=""

    # Detect shell type and set corresponding rc file
    if [ -n "$BASH_VERSION" ]; then
        rc_file="$HOME/.bashrc"
        shell_type="bash"
    elif [ -n "$ZSH_VERSION" ]; then
        rc_file="$HOME/.zshrc"
        shell_type="zsh"
    else
        echo "Unsupported shell. Only bash or zsh is supported."
        return 1
    fi

    # Backup rc file before modifying
    if [ -f "$rc_file" ]; then
        cp "$rc_file" "${rc_file}.backup_$(date +%Y%m%d%H%M%S)"
        echo "Backup of $rc_file created."
    else
        echo "$rc_file not found. Creating a new one."
        touch "$rc_file"
    fi

    # Check if the configuration already exists
    if ! grep -q "# BEGIN DOUBLE-ESC-SUDO CONFIG" "$rc_file"; then
        # Append the configuration to the rc file
        cat << EOF >> "$rc_file"

# BEGIN DOUBLE-ESC-SUDO CONFIG
double_esc_to_sudo() {
    if [[ \$SHELL =~ (bash|zsh) ]]; then
        if [[ "\$READLINE_LINE" != sudo\ * ]]; then
            READLINE_POINT=0
            READLINE_LINE="sudo \$READLINE_LINE"
            return 0
        fi
    fi
    return 1
}
bind -x '"\e\e":double_esc_to_sudo'
# END DOUBLE-ESC-SUDO CONFIG
EOF

        # Reload the rc file
        if [[ "$shell_type" == "bash" ]]; then
            source "$rc_file"
        elif [[ "$shell_type" == "zsh" ]]; then
            source "$rc_file"
        fi
        echo "Double-ESC to sudo configuration added to $rc_file."
    else
        echo "Double-ESC to sudo configuration already exists in $rc_file."
    fi

    echo "Please restart your shell or source your rc file for changes to take effect."
}

# Function: Uninstall the double-ESC-to-sudo configuration
uninstall_double_esc_sudo() {
    local rc_file=""
    if [ -n "$BASH_VERSION" ]; then
        rc_file="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        rc_file="$HOME/.zshrc"
    else
        echo "Unsupported shell. Only bash or zsh is supported."
        return 1
    fi

    if [ -f "$rc_file" ]; then
        # Confirm with the user before removing
        read -p "Are you sure you want to remove the double-ESC-to-sudo configuration? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Remove the configuration block
            sed -i '/# BEGIN DOUBLE-ESC-SUDO CONFIG/,/# END DOUBLE-ESC-SUDO CONFIG/d' "$rc_file"
            echo "Double-ESC to sudo configuration removed from $rc_file."
        else
            echo "Operation canceled."
        fi
    else
        echo "$rc_file not found."
        return 1
    fi
}

# Main logic: Determine how the script is executed
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 如果脚本是通过 source 加载的，仅加载函数，不执行任何操作
    echo "Double-ESC-to-sudo functions loaded. Use 'install_double_esc_sudo' or 'uninstall_double_esc_sudo' manually."
else
    # 如果脚本是直接运行的，提示用法或者交互式执行
    echo "This script provides 'install_double_esc_sudo' and 'uninstall_double_esc_sudo' functions."
    echo "Usage:"
    echo "  1. Source this script to load the functions: source ${BASH_SOURCE[0]}"
    echo "  2. Run 'install_double_esc_sudo' to enable the feature."
    echo "  3. Run 'uninstall_double_esc_sudo' to remove the feature."
    echo
    echo "Would you like to install the double-ESC-to-sudo feature now? (y/n):"

    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        install_double_esc_sudo
    else
        echo "Installation skipped. You can use the functions manually after sourcing this script."
    fi
fi