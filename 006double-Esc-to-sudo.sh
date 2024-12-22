#!/bin/bash

# 这是一个函数，用于实现双击 ESC 键转换为 sudo 命令
double_esc_to_sudo() {
    # 判断当前 shell 类型是否是 bash 或 zsh
    if [[ ${SHELL} =~ (bash|zsh) ]]; then
        # 判断当前输入的命令行是否已经以 sudo 开头
        if [[ "${READLINE_LINE}" != sudo\ * ]]; then
            # 如果不是，以 sudo 开头重新构造命令行
            READLINE_POINT=0
            READLINE_LINE="sudo $READLINE_LINE"
            return 0
        fi
    fi
    return 1
}

# 这是一个函数，用于设置双击 ESC 键转换为 sudo 命令的配置
setup_double_esc_sudo() {
    # 定义 rc 文件路径和 shell 类型
    local rc_file
    local shell_type

    # 判断当前 shell 类型
    if [ -n "$BASH_VERSION" ]; then
        # 如果是 bash，设置 rc 文件路径和 shell 类型
        rc_file="$HOME/.bashrc"
        shell_type="bash"
    elif [ -n "$ZSH_VERSION" ]; then
        # 如果是 zsh，设置 rc 文件路径和 shell 类型
        rc_file="$HOME/.zshrc"
        shell_type="zsh"
    else
        # 如果是其他 shell 类型，输出错误信息并返回
        echo "Unsupported shell."
        return 1
    fi

    # 判断 rc 文件是否存在
    if [ -f "$rc_file" ]; then
        # grep -q 命令用于在文件中搜索指定的文本模式
        # -q 参数表示安静模式，不输出任何内容，只返回查找结果（找到返回0，未找到返回1）
        # 这里在 rc_file 中查找特定的注释标记，用来判断配置是否已经存在
        # ! 符号表示取反，所以整个if语句的意思是：如果在配置文件中没有找到这个标记，则执行下面的代码块
        if ! grep -q "# BEGIN DOUBLE-ESC-SUDO CONFIG" "$rc_file"; then
            # 添加新的配置，带有标记注释
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

            # 根据 shell 类型，重新加载 rc 文件
            if [[ "$shell_type" == "bash" ]]; then
                source "$rc_file"
            elif [[ "$shell_type" == "zsh" ]]; then
                source "$rc_file"
            fi
            # 输出配置添加成功信息
            echo "Double-ESC to sudo configuration added to $rc_file."
        else
            # 输出配置已经存在信息
            echo "Double-ESC to sudo configuration already exists in $rc_file."
        fi
    else
        # 输出 rc 文件不存在信息并返回
        echo "$rc_file not found."
        return 1
    fi
    # 输出提示信息，需要重启 shell 或重新加载 rc 文件才能生效
    echo "Please restart your shell or source your rc file for changes to take effect."
}



# 函数：取消上述设置，恢复.bashrc或.zshrc文件
cancel_double_esc_sudo() {
    local rc_file
    if [ -n "$BASH_VERSION" ]; then
        rc_file="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        rc_file="$HOME/.zshrc"
    else
        echo "Unsupported shell."
        return 1
    fi
    if [ -f "$rc_file" ]; then
        sed -i '/# BEGIN DOUBLE-ESC-SUDO CONFIG/,/# END DOUBLE-ESC-SUDO CONFIG/d' "$rc_file"
        echo "Double-ESC to sudo configuration removed from $rc_file."
    else
        echo "$rc_file not found."
        return 1
    fi
}

# 这是一个重要的判断语句，用于确定脚本是如何被执行的：
# 1. ${BASH_SOURCE[0]} 是一个数组，包含了当前脚本文件的名称
# 2. ${0} 是当前正在执行的脚本名称
# 3. 如果这两个值不相等，说明脚本是被 source 命令或 . 命令引用执行的
# 4. 如果相等，说明脚本是被直接执行的（比如 ./script.sh）
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 如果脚本是被 source 引用的，就直接返回，不继续执行后面的代码
    # 这通常用于防止某些命令被重复执行
    return 0
fi

# 调用 setup_double_esc_sudo 函数，设置双击 ESC 键转换为 sudo 命令的配置
setup_double_esc_sudo