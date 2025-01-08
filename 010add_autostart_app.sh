#!/bin/bash

###############################################################################
# 函数名称：010add_autostart_app
# 函数作用：
#   将指定应用添加到自动启动，适配不同桌面环境
#
# 参数说明：
#   $1 : 显示名称 (Name=)
#   $2 : 完整可执行命令 (Exec=)
#   $3 : 是否最小化 (yes|no)
#   $@ : 其余参数将追加到 Exec 行
###############################################################################


###############################################################################
# 函数名称：detect_desktop_environment
# 函数作用：
#   检测当前运行的桌面环境
#
# 返回值：
#   输出检测到的桌面环境名称（大写）
###############################################################################
detect_desktop_environment() {
    # 首先检查当前会话类型
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        echo "${XDG_CURRENT_DESKTOP^^}" # 转换为大写
        return
    fi

    # 备用检测方法
    if [[ -n "$KDE_FULL_SESSION" ]]; then
        echo "KDE"
    elif [[ -n "$GNOME_DESKTOP_SESSION_ID" ]]; then
        echo "GNOME"
    elif [[ -n "$MATE_DESKTOP_SESSION_ID" ]]; then
        echo "MATE"
    elif [[ "$DESKTOP_SESSION" == "xfce" ]]; then
        echo "XFCE"
    else
        echo "UNKNOWN"
    fi
}

add_autostart_app() {
    local display_name="$1"
    local exec_cmd="$2"
    local minimize_flag="$3"
    shift 3
    local exec_args=("$@")

    # 获取 XDG 配置目录
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local sanitized_name="${display_name// /_}"
    local desktop_file="${autostart_dir}/${sanitized_name}.desktop"

    # 检测当前桌面环境
    local current_de=$(detect_desktop_environment)

    #-------------------------
    # 基础输入验证
    #-------------------------
    if [[ -z "$display_name" || -z "$exec_cmd" || -z "$minimize_flag" ]]; then
        echo "[ERROR] 参数不足。用法："
        echo "       add_autostart_app <显示名称> <完整可执行命令> <yes|no> [参数...]"
        return 1
    fi

    if [[ "$minimize_flag" != "yes" && "$minimize_flag" != "no" ]]; then
        echo "[ERROR] 第三个参数仅允许 yes 或 no"
        return 1
    fi

    # 命令检查
    if [[ "$exec_cmd" == /* ]]; then
        if [[ ! -x "$exec_cmd" ]]; then
            echo "[WARNING] 指定路径不存在或没有执行权限：$exec_cmd"
        fi
    elif ! command -v "$exec_cmd" >/dev/null 2>&1; then
        echo "[WARNING] 命令 $exec_cmd 不在PATH中，可能无法正常启动。"
    fi

    #-------------------------
    # 创建autostart目录
    #-------------------------
    if [[ ! -d "$autostart_dir" ]]; then
        mkdir -p "$autostart_dir" || {
            echo "[ERROR] 无法创建目录：$autostart_dir"
            return 2
        }
    fi

    #-------------------------
    # 构造 Exec 命令
    #-------------------------
    local exec_line="$exec_cmd"
    
    # 根据不同桌面环境添加最小化参数
    if [[ "$minimize_flag" == "yes" ]]; then
        case "$current_de" in
            "KDE")
                # KDE Plasma 使用窗口规则更可靠，但这里仍然添加通用参数
                exec_args+=("--minimize")
                ;;
            "GNOME")
                # GNOME 可以使用 gtk-launch 包装
                if command -v gtk-launch >/dev/null 2>&1; then
                    exec_line="gtk-launch $exec_cmd"
                fi
                ;;
            *)
                # 通用方案：尝试常见的最小化参数
                exec_args+=("--minimize" "--minimized" "-m")
                ;;
        esac
    fi

    # 添加其他参数
    for arg in "${exec_args[@]}"; do
        exec_line+=" \"$arg\""
    done

    #-------------------------
    # 写入 .desktop 文件
    #-------------------------
    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        echo "Type=Application"
        echo "Name=$display_name"
        echo "Exec=$exec_line"
        echo "Comment=Autostart entry for $display_name"
        echo "Terminal=false"
        echo "X-GNOME-Autostart-enabled=true"
        
        # 根据桌面环境添加特定配置
        case "$current_de" in
            "KDE")
                if [[ "$minimize_flag" == "yes" ]]; then
                    echo "X-KDE-AutostartMinimized=true"
                fi
                ;;
            "GNOME")
                # GNOME特定配置（如果有）
                ;;
            "XFCE")
                # XFCE特定配置（如果有）
                ;;
        esac

        # 通用标准字段
        echo "StartupNotify=true"
    } > "$desktop_file"

    # 设置权限
    chmod +x "$desktop_file"

    #-------------------------
    # 确认结果
    #-------------------------
    if [[ -f "$desktop_file" ]]; then
        echo "[INFO] 已创建自启动条目：$desktop_file"
        echo "[INFO] 当前桌面环境：$current_de"
        echo "[INFO] 执行命令：$exec_line"
        if [[ "$minimize_flag" == "yes" ]]; then
            echo "[INFO] 已尝试配置最小化启动（实际效果取决于应用程序和桌面环境支持）"
        fi
        return 0
    else
        echo "[ERROR] 创建失败：$desktop_file"
        return 3
    fi
}

###############################################################################
# 函数名称：toggle_autostart_app
# 函数作用：
#   启用或禁用指定的自启动条目（freedesktop.org 标准实现）
###############################################################################
toggle_autostart_app() {
    local name="$1"
    local action="$2"
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local sanitized_name="${name// /_}"
    local desktop_file="${autostart_dir}/${sanitized_name}.desktop"

    # 参数验证
    if [[ -z "$name" || -z "$action" ]]; then
        echo "[ERROR] 参数不足。用法："
        echo "       toggle_autostart_app <显示名称> <enable|disable>"
        return 1
    fi

    if [[ "$action" != "enable" && "$action" != "disable" ]]; then
        echo "[ERROR] 无效的操作类型。必须是 'enable' 或 'disable'"
        return 1
    fi

    # 检查文件是否存在
    if [[ ! -f "$desktop_file" ]]; then
        local found_file=$(grep -l "^Name=$name$" "$autostart_dir"/*.desktop 2>/dev/null)
        if [[ -n "$found_file" ]]; then
            desktop_file="$found_file"
        else
            echo "[ERROR] 未找到自启动条目：$name"
            return 2
        fi
    fi

    # 创建临时文件
    local temp_file=$(mktemp)
    if [[ ! -f "$temp_file" ]]; then
        echo "[ERROR] 无法创建临时文件"
        return 3
    fi

    # 修改配置（使用标准的 freedesktop.org 字段）
    local modified=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^X-GNOME-Autostart-enabled= ]]; then
            echo "X-GNOME-Autostart-enabled=$([[ "$action" == "enable" ]] && echo "true" || echo "false")"
            modified=true
        elif [[ "$line" =~ ^Hidden= ]]; then
            echo "Hidden=$([[ "$action" == "enable" ]] && echo "false" || echo "true")"
            modified=true
        else
            echo "$line"
        fi
    done < "$desktop_file" > "$temp_file"

    # 如果没找到相关字段，添加标准字段
    if [[ "$modified" == "false" ]]; then
        echo "X-GNOME-Autostart-enabled=$([[ "$action" == "enable" ]] && echo "true" || echo "false")" >> "$temp_file"
        echo "Hidden=$([[ "$action" == "enable" ]] && echo "false" || echo "true")" >> "$temp_file"
    fi

    # 替换原文件
    if mv "$temp_file" "$desktop_file"; then
        chmod +x "$desktop_file"
        echo "[INFO] 已${action == "enable" ? "启用" : "禁用"}自启动条目：$name"
        return 0
    else
        echo "[ERROR] 更新文件失败：$desktop_file"
        rm -f "$temp_file"
        return 3
    fi
}

###############################################################################
# 函数名称：list_autostart_apps
# 函数作用：
#   列出所有自启动条目（freedesktop.org 标准实现）
###############################################################################
list_autostart_apps() {
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local current_de=$(detect_desktop_environment)

    # 检查目录是否存在
    if [[ ! -d "$autostart_dir" ]]; then
        echo "[ERROR] 自启动目录不存在：$autostart_dir"
        return 1
    fi

    # 检查是否有.desktop文件
    local desktop_files=("$autostart_dir"/*.desktop)
    if [[ ! -e "${desktop_files[0]}" ]]; then
        echo "[INFO] 没有找到任何自启动条目"
        return 0
    fi

    # 打印环境信息
    echo "当前桌面环境: $current_de"
    echo "自启动目录: $autostart_dir"
    
    # 打印表头
    printf "\n%-30s %-40s %-10s %-20s\n" "名称" "执行命令" "状态" "类型"
    echo "--------------------------------------------------------------------------------"

    # 遍历所有.desktop文件
    for file in "${desktop_files[@]}"; do
        if [[ -f "$file" ]]; then
            local name=""
            local exec=""
            local enabled="启用"
            local type="Application"
            
            # 读取文件内容
            while IFS='=' read -r key value; do
                case "$key" in
                    "Name") name="$value" ;;
                    "Exec") exec="$value" ;;
                    "Type") type="$value" ;;
                    "X-GNOME-Autostart-enabled")
                        [[ "$value" == "false" ]] && enabled="禁用"
                        ;;
                    "Hidden")
                        [[ "$value" == "true" ]] && enabled="禁用"
                        ;;
                esac
            done < "$file"

            # 截断过长的值
            [[ ${#name} -gt 28 ]] && name="${name:0:25}..."
            [[ ${#exec} -gt 38 ]] && exec="${exec:0:35}..."

            # 打印信息
            printf "%-30s %-40s %-10s %-20s\n" "$name" "$exec" "$enabled" "$type"
        fi
    done

    echo "--------------------------------------------------------------------------------"
    echo "共找到 ${#desktop_files[@]} 个自启动条目"
    return 0
}

# # 首先source脚本
# source 400add_autostart_app.sh

# # 添加自启动项
# add_autostart_app "应用名称" "命令路径" "yes|no" [可选参数...]

# # 删除自启动项
# remove_autostart_app "应用名称"

# # 启用/禁用自启动项
# toggle_autostart_app "应用名称" "enable|disable"

# # 查看所有自启动项
# list_autostart_apps