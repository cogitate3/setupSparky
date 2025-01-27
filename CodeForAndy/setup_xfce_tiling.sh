#!/bin/bash
###############################################################################
# 脚本名称：setup_xfce_tiling.sh
# XFCE4 四向窗口平铺一键配置脚本 (键名修正版)
# 功能：Win+←/→/↑/↓ 实现左/右/上/下半屏平铺
# 源代码：https://github.com/0xacx/chatGPT-shell-cli
# 版本：1.0
# 用法：
#   安装: ./setup_xfce_tiling.sh 
###############################################################################


# 更新：修正键名为首字母大写格式

# 退出状态码
SUCCESS=0
ERR_ROOT=1
ERR_DEP=2
ERR_SCRIPT=3
ERR_KEYBIND=4

# 配置参数 (可按需修改)
FRAME_OFFSET=4               # 窗口边框补偿像素
TILE_PERCENT=50              # 分屏比例(50表示50%)
SCRIPTS_DIR="/usr/local/bin" # 脚本安装目录

# 样式定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'
BOLD='\033[1m'

# 检查root权限
check_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}错误：请使用root权限运行此脚本 (sudo $0)${NC}" >&2
        exit $ERR_ROOT
    }
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}[1/5] 正在检查依赖...${NC}"
    local deps=("xdotool" "wmctrl")
    local missing=()

    for dep in "${deps[@]}"; do
        ! command -v "$dep" &>/dev/null && missing+=("$dep")
    done

    [[ ${#missing[@]} -gt 0 ]] && {
        echo -e "正在安装 ${missing[*]}..."
        apt-get update >/dev/null 2>&1 || {
            echo -e "${RED}软件源更新失败！请检查网络连接。${NC}" >&2
            exit $ERR_DEP
        }
        apt-get install -y "${missing[@]}" >/dev/null 2>&1 || {
            echo -e "${RED}依赖安装失败！请手动安装：${missing[*]}${NC}" >&2
            exit $ERR_DEP
        }
    }
}

# 生成平铺脚本模板
generate_script_template() {
    local direction=$1
    cat <<EOF
#!/bin/bash
# 窗口平铺脚本 - $direction方向

# 获取活动窗口和屏幕参数
ACTIVE_WIN=\$(xdotool getactivewindow)
SCREEN_WIDTH=\$(xdotool getdisplaygeometry | awk '{print \$1}')
SCREEN_HEIGHT=\$(xdotool getdisplaygeometry | awk '{print \$2}')

# 移除最大化状态
wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz >/dev/null 2>&1

# 计算窗口尺寸和位置
case "$direction" in
    left)
        WIDTH=\$(( (SCREEN_WIDTH * $TILE_PERCENT / 100) - $FRAME_OFFSET*2 ))
        X=0
        Y=0
        HEIGHT=\$(( SCREEN_HEIGHT - $FRAME_OFFSET*2 ))
        ;;
    right)
        WIDTH=\$(( (SCREEN_WIDTH * $TILE_PERCENT / 100) - $FRAME_OFFSET*2 ))
        X=\$(( SCREEN_WIDTH - WIDTH - $FRAME_OFFSET*2 ))
        Y=0
        HEIGHT=\$(( SCREEN_HEIGHT - $FRAME_OFFSET*2 ))
        ;;
    up)
        HEIGHT=\$(( (SCREEN_HEIGHT * $TILE_PERCENT / 100) - $FRAME_OFFSET*2 ))
        X=0
        Y=0
        WIDTH=\$(( SCREEN_WIDTH - $FRAME_OFFSET*2 ))
        ;;
    down)
        HEIGHT=\$(( (SCREEN_HEIGHT * $TILE_PERCENT / 100) - $FRAME_OFFSET*2 ))
        X=0
        Y=\$(( SCREEN_HEIGHT - HEIGHT - $FRAME_OFFSET*2 ))
        WIDTH=\$(( SCREEN_WIDTH - $FRAME_OFFSET*2 ))
        ;;
esac

# 应用窗口设置
xdotool windowsize \$ACTIVE_WIN \$WIDTH \$HEIGHT
xdotool windowmove \$ACTIVE_WIN \$X \$Y

# 记录日志
logger -t "WindowTiling" "方向: $direction | 位置: \${X}x\${Y} | 尺寸: \${WIDTH}x\${HEIGHT}"
EOF
}

# 创建平铺脚本
create_tiling_scripts() {
    echo -e "${YELLOW}[2/5] 正在生成平铺脚本..."
    local directions=("left" "right" "up" "down")

    for dir in "${directions[@]}"; do
        local script_path="$SCRIPTS_DIR/tile_${dir}.sh"
        generate_script_template "$dir" > "$script_path"
        chmod +x "$script_path" || {
            echo -e "${RED}创建 $script_path 失败！${NC}" >&2
            exit $ERR_SCRIPT
        }
        echo -e "已生成：${BOLD}$script_path${NC}"
    done
}

# 清除旧快捷键绑定
clean_old_keybinds() {
    echo -e "${YELLOW}[3/5] 清理旧快捷键配置..."
    local keys=("Left" "Right" "Up" "Down")

    for key in "${keys[@]}"; do
        xfconf-query -c xfce4-keyboard-shortcuts \
            -p "/commands/custom/<Super>${key}" -r >/dev/null 2>&1
    done
}

# 设置快捷键绑定
set_keybindings() {
    echo -e "${YELLOW}[4/5] 绑定新快捷键..."
    declare -A keymap=(
        ["Left"]="tile_left.sh"
        ["Right"]="tile_right.sh"
        ["Up"]="tile_up.sh"
        ["Down"]="tile_down.sh"
    )

    for key in "${!keymap[@]}"; do
        local command="$SCRIPTS_DIR/${keymap[$key]}"
        xfconf-query -c xfce4-keyboard-shortcuts \
            -p "/commands/custom/<Super>${key}" \
            -s "$command" --create -t string >/dev/null 2>&1 || {
                echo -e "${RED}绑定 <Super>${key} 失败！${NC}" >&2
                exit $ERR_KEYBIND
            }
        echo -e "已绑定：${GREEN}Win+${key} → ${keymap[$key]}${NC}"
    done
}

# 最终验证
final_check() {
    echo -e "${YELLOW}[5/5] 执行最终验证..."
    ! sudo -u $SUDO_USER xfconf-query -c xfce4-keyboard-shortcuts -lv | grep -q "tile_" && {
        echo -e "${RED}错误：快捷键绑定验证失败！${NC}" >&2
        exit $ERR_KEYBIND
    }

    echo -e "\n${GREEN}✓ 所有配置已完成！请测试以下快捷键：${NC}"
    echo -e "-----------------------------------------"
    echo -e "  Win + ← : 左半屏平铺 (宽度${TILE_PERCENT}%)"
    echo -e "  Win + → : 右半屏平铺 (宽度${TILE_PERCENT}%)"
    echo -e "  Win + ↑ : 上半屏平铺 (高度${TILE_PERCENT}%)"
    echo -e "  Win + ↓ : 下半屏平铺 (高度${TILE_PERCENT}%)"
    echo -e "-----------------------------------------"
    echo -e "提示：可能需要重新登录或执行 ${BOLD}xfwm4 --replace${NC}"
}

# 主流程
main() {
    check_root
    echo -e "${GREEN}=== XFCE4 窗口平铺配置工具 v2.3 ===${NC}"
    
    install_dependencies       # 步骤1：安装依赖
    create_tiling_scripts      # 步骤2：生成脚本
    clean_old_keybinds         # 步骤3：清理旧配置
    set_keybindings            # 步骤4：绑定快捷键
    final_check                # 步骤5：最终验证

    exit $SUCCESS
}

# 执行主程序
main