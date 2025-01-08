#!/bin/bash

# 版本和配置
SCRIPT_VERSION="1.0.1"
# CURRENT_VERSION="3.0.2"  # 删除这行，不再硬编码
# SOURCE_HAN_SANS_VERSION="2.004R"   # 删除这行，不再硬编码
CONFIG_DIR="/etc/font-manager"
CONFIG_FILE="${CONFIG_DIR}/config"
LAST_UPDATE_CHECK=0

# Nerd Fonts 配置
NERD_FONTS=(
    "JetBrainsMono"
    "FiraCode"
    "Hack"
    "SourceCodePro"
    "UbuntuMono"
    "DejaVuSansMono"
    "RobotoMono"
    "IBMPlexMono"
    "Meslo"
    "Inconsolata"
)

# 思源字体配置
SOURCE_HAN_TYPES=(
    # "serif"  # 思源宋体
    "sans"   # 思源黑体
)

SOURCE_HAN_REGIONS=(
    "CN"  # 简体中文
    "TW"  # 繁体中文
    "JP"  # 日文
    "KR"  # 韩文
)

# 配置文件加载函数
load_config() {
    # 设置默认版本号
    CURRENT_VERSION="3.3.0"  # Nerd Fonts 初始版本
    SOURCE_HAN_SANS_VERSION="2.004R"  # 思源黑体初始版本
    
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        # 如果配置文件不存在，获取最新版本号作为初始版本
        local latest_nerd_version
        latest_nerd_version=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -oP '"tag_name": "\K(.+)(?=")')
        if [ -n "$latest_nerd_version" ]; then
            CURRENT_VERSION=${latest_nerd_version#v}
        fi
        
        local latest_sans_version
        latest_sans_version=$(curl -s "https://api.github.com/repos/adobe-fonts/source-han-sans/releases/latest" | grep -oP '"tag_name": "\K(.+)(?=")')
        if [ -n "$latest_sans_version" ]; then
            SOURCE_HAN_SANS_VERSION=$latest_sans_version
        fi
        
        # 保存初始配置
        save_config
    fi

    # 设置下载 URL
    SOURCE_HAN_SANS_BASE_URL="https://github.com/adobe-fonts/source-han-sans/releases/download/${SOURCE_HAN_SANS_VERSION}"
    NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${CURRENT_VERSION}"
}

# 配置文件保存函数
save_config() {
    mkdir -p "$CONFIG_DIR"
    {
        echo "LAST_UPDATE_CHECK=$(date +%s)"
        echo "CURRENT_VERSION=\"$CURRENT_VERSION\""
        echo "SOURCE_HAN_SANS_VERSION=\"$SOURCE_HAN_SANS_VERSION\""
    } > "$CONFIG_FILE"
}

# 检查更新时间函数
should_check_update() {
    local current_time
    local time_diff
    current_time=$(date +%s)
    time_diff=$((current_time - LAST_UPDATE_CHECK))
    
    # 24小时 = 86400秒
    [ "$time_diff" -ge 86400 ]
}

# 版本比较函数
compare_versions() {
    local ver1=$1
    local ver2=$2
    
    # 移除版本号中的 'v' 前缀（如果存在）
    ver1=${ver1#v}
    ver2=${ver2#v}
    
    # 移除 'R' 后缀（如果存在）
    ver1=${ver1%R}
    ver2=${ver2%R}
    
    if [[ "$ver1" == "$ver2" ]]; then
        echo 0
        return
    fi
    
    local IFS=.
    local i ver1_array=($ver1) ver2_array=($ver2)
    
    # 填充数组长度，使其相等
    for ((i=${#ver1_array[@]}; i<${#ver2_array[@]}; i++)); do
        ver1_array[i]=0
    done
    for ((i=${#ver2_array[@]}; i<${#ver1_array[@]}; i++)); do
        ver2_array[i]=0
    done
    
    # 比较版本号
    for ((i=0; i<${#ver1_array[@]}; i++)); do
        if ((10#${ver1_array[i]} > 10#${ver2_array[i]})); then
            echo 1
            return
        elif ((10#${ver1_array[i]} < 10#${ver2_array[i]})); then
            echo -1
            return
        fi
    done
    
    echo 0
}

# 日志函数
log_message() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        INFO)
            echo "[$timestamp] [INFO] $message"
            ;;
        ERROR)
            echo "[$timestamp] [ERROR] $message" >&2
            ;;
        WARNING)
            echo "[$timestamp] [WARNING] $message" >&2
            ;;
    esac
}

# 下载重试机制
download_with_retry() {
    local url=$1
    local output=$2
    local description=$3
    local max_retries=3
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ]; do
        log_message "INFO" "下载 $description (尝试 $((retry_count + 1))/$max_retries)"
        if wget -q --show-progress "$url" -O "$output"; then
            success=true
            break
        fi
        ((retry_count++))
        [ $retry_count -lt $max_retries ] && sleep 3
    done
    
    if [ "$success" = true ]; then
        log_message "INFO" "$description 下载完成"
        return 0
    else
        log_message "ERROR" "$description 下载失败"
        return 1
    fi
}

# 并行下载管理器
parallel_download_manager() {
    local commands=("$@")
    local max_parallel=3
    local running=0
    local pids=()
    local exit_codes=()
    local failed=0
    
    for cmd in "${commands[@]}"; do
        # 检查正在运行的进程数
        while [ $running -ge $max_parallel ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}"
                    exit_codes[$i]=$?
                    unset "pids[$i]"
                    ((running--))
                fi
            done
            sleep 0.5
        done
        
        # 启动新的下载进程
        eval "$cmd" &
        pids+=($!)
        ((running++))
    done
    
    # 等待所有进程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
        local exit_code=$?
        exit_codes+=($exit_code)
        [ $exit_code -ne 0 ] && ((failed++))
    done
    
    return $failed
}

# Nerd Fonts 安装函数
install_nerd_font() {
    local font_name=$1
    local temp_dir=$(mktemp -d)
    local download_path="$temp_dir/${font_name}.zip"
    local font_url="${NERD_FONTS_BASE_URL}/${font_name}.zip"
    local install_dir="/usr/local/share/fonts/nerd-fonts/${font_name}"
    
    log_message "INFO" "开始安装 $font_name"
    
    # 下载字体
    if ! download_with_retry "$font_url" "$download_path" "$font_name"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 创建安装目录
    mkdir -p "$install_dir"
    
    # 解压字体
    log_message "INFO" "正在解压 $font_name..."
    if ! unzip -qo "$download_path" -d "$install_dir"; then
        log_message "ERROR" "$font_name 解压失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 设置权限
    chmod 644 "$install_dir"/*.[ot]tf 2>/dev/null
    
    # 更新字体缓存
    fc-cache -f "$install_dir"
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 验证安装
    if ! verify_font_installation "$font_name"; then
        log_message "WARNING" "$font_name 安装验证未通过"
        return 1
    fi
    
    log_message "INFO" "$font_name 安装完成"
    return 0
}

# 8. 修改字体安装函数(简化版)
install_source_han() {
    local region=$2
    local temp_dir=$(mktemp -d)
    local download_path="$temp_dir/SourceHanSans${region}.zip"
    local font_url="${SOURCE_HAN_SANS_BASE_URL}/SourceHanSans${region}.zip"
    local install_dir="/usr/local/share/fonts/source-han-sans/${region}"
    
    log_message "INFO" "开始安装思源黑体 ($region)"
    
    # 下载字体
    if ! download_with_retry "$font_url" "$download_path" "思源黑体 ($region)"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 创建安装目录
    mkdir -p "$install_dir"
    
    # 解压字体
    log_message "INFO" "正在解压思源黑体 ($region)..."
    if ! unzip -qo "$download_path" -d "$install_dir"; then
        log_message "ERROR" "思源黑体 ($region) 解压失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 设置权限
    chmod 644 "$install_dir"/*.otf 2>/dev/null
    
    # 更新字体缓存
    fc-cache -f "$install_dir"
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 验证安装
    if ! verify_source_han_installation "$region"; then
        log_message "WARNING" "思源黑体 ($region) 安装验证未通过"
        return 1
    fi

    log_message "INFO" "思源黑体 ($region) 安装完成"
    return 0
}

# 验证 Nerd Font 安装
verify_font_installation() {
    local font_name=$1
    local install_dir="/usr/local/share/fonts/nerd-fonts/${font_name}"
    local success=true
    
    log_message "INFO" "正在验证 $font_name 安装..."
    
    # 检查目录结构
    if [ ! -d "$install_dir" ]; then
        log_message "ERROR" "$font_name 安装目录不存在"
        return 1
    fi
    
    # 检查字体文件
    local font_count=$(find "$install_dir" -name "*.[ot]tf" | wc -l)
    if [ "$font_count" -eq 0 ]; then
        log_message "ERROR" "$font_name 未找到字体文件"
        return 1
    fi
    
    # 验证字体注册
    if ! fc-list | grep -i "$font_name" > /dev/null; then
        log_message "ERROR" "$font_name 未正确注册到系统"
        return 1
    fi
    
    log_message "INFO" "$font_name 验证通过"
    return 0
}

# 9. 修改验证函数(简化版)
verify_source_han_installation() {
    local region=$1
    local install_dir="/usr/local/share/fonts/source-han-sans/${region}"
    
    log_message "INFO" "正在验证思源黑体 ($region) 安装..."
    
    # 检查目录结构
    if [ ! -d "$install_dir" ]; then
        log_message "ERROR" "思源黑体 ($region) 安装目录不存在"
        return 1
    fi
    
    # 检查OTF文件
    local otf_count=$(find "$install_dir" -name "*.otf" | wc -l)
    if [ "$otf_count" -eq 0 ]; then
        log_message "ERROR" "思源黑体 ($region) 未找到字体文件"
        return 1
    fi
    
    # 验证字体注册
    if ! fc-list | grep -i "Source Han Sans.*${region}" > /dev/null; then
        log_message "ERROR" "思源黑体 ($region) 未正确注册到系统"
        return 1
    fi
    
    log_message "INFO" "思源黑体 ($region) 验证通过"
    return 0
}

# 验证所有 Nerd Fonts
verify_all_nerd_fonts() {
    local failed=0
    
    log_message "INFO" "开始验证所有已安装的 Nerd Fonts..."
    
    for font in "${NERD_FONTS[@]}"; do
        if [ -d "/usr/local/share/fonts/nerd-fonts/${font}" ]; then
            if ! verify_font_installation "$font"; then
                ((failed++))
            fi
        fi
    done
    
    [ $failed -eq 0 ] && return 0 || return 1
}

# 验证所有思源字体
verify_all_source_han() {
    local type=$1    # serif 或 sans
    local failed=0
    
    log_message "INFO" "开始验证所有已安装的思源${type}体..."
    
    for region in "${SOURCE_HAN_REGIONS[@]}"; do
        if [ -d "/usr/local/share/fonts/source-han-${type}/${region}" ]; then
            if ! verify_source_han_installation "$type" "$region"; then
                ((failed++))
            fi
        fi
    done
    
    [ $failed -eq 0 ] && return 0 || return 1
}

# Nerd Font 卸载函数
uninstall_nerd_font() {
    local font_name=$1
    local install_dir="/usr/local/share/fonts/nerd-fonts/${font_name}"
    
    if [ ! -d "$install_dir" ]; then
        log_message "ERROR" "$font_name 未安装"
        return 1
    fi
    
    log_message "INFO" "正在卸载 $font_name..."
    
    # 创建备份
    local backup_dir="${install_dir}_backup_$(date +%Y%m%d_%H%M%S)"
    mv "$install_dir" "$backup_dir"
    
    # 更新字体缓存
    fc-cache -f
    
    log_message "INFO" "$font_name 卸载完成"
    echo "备份已保存至: $backup_dir"
    
    read -p "是否删除备份？[y/N] " choice
    case $choice in
        [Yy]*)
            rm -rf "$backup_dir"
            log_message "INFO" "$font_name 备份已删除"
            ;;
        *)
            log_message "INFO" "$font_name 备份已保留"
            ;;
    esac
    
    return 0
}

# 14. 思源黑体卸载函数(简化版)
uninstall_source_han() {
    local region=$1
    local install_dir="/usr/local/share/fonts/source-han-sans/${region}"
    
    if [ ! -d "$install_dir" ]; then
        log_message "ERROR" "思源黑体 ($region) 未安装"
        return 1
    fi
    
    log_message "INFO" "正在卸载思源黑体 ($region)..."
    
    # 创建备份
    local backup_dir="${install_dir}_backup_$(date +%Y%m%d_%H%M%S)"
    mv "$install_dir" "$backup_dir"
    
    # 更新字体缓存
    fc-cache -f
    
    log_message "INFO" "思源黑体 ($region) 卸载完成"
    echo "备份已保存至: $backup_dir"
    
    read -p "是否删除备份？[y/N] " choice
    case $choice in
        [Yy]*)
            rm -rf "$backup_dir"
            log_message "INFO" "思源黑体 ($region) 备份已删除"
            ;;
        *)
            log_message "INFO" "思源黑体 ($region) 备份已保留"
            ;;
    esac
    
    return 0
}

# 15. 批量卸载思源黑体函数
uninstall_all_source_han() {
    log_message "WARNING" "即将卸载所有思源黑体"
    read -p "是否继续？[y/N] " choice
    case $choice in
        [Yy]*)
            local base_dir="/usr/local/share/fonts/source-han-sans"
            if [ -d "$base_dir" ]; then
                local backup_dir="${base_dir}_backup_$(date +%Y%m%d_%H%M%S)"
                mv "$base_dir" "$backup_dir"
                fc-cache -f
                log_message "INFO" "所有思源黑体卸载完成"
                echo "备份已保存至: $backup_dir"
                
                read -p "是否删除备份？[y/N] " del_choice
                case $del_choice in
                    [Yy]*)
                        rm -rf "$backup_dir"
                        log_message "INFO" "思源黑体备份已删除"
                        ;;
                    *)
                        log_message "INFO" "思源黑体备份已保留"
                        ;;
                esac
            else
                log_message "INFO" "未安装任何思源黑体"
            fi
            ;;
        *)
            log_message "INFO" "取消卸载"
            ;;
    esac
}

# 5. 修改主菜单显示
show_main_menu() {
    clear
    echo "================================================"
    echo "        字体安装管理器 v${SCRIPT_VERSION}"
    echo "================================================"
    echo "1) 安装 Nerd Fonts"
    echo "2) 安装思源黑体"
    echo "3) 验证安装"
    echo "4) 卸载字体"
    echo "5) 查看统计"
    echo "6) 检查更新"
    echo "0) 退出"
    echo "------------------------------------------------"
}

# Nerd Fonts 安装菜单
show_nerd_fonts_menu() {
    echo "================================================"
    echo "            Nerd Fonts 安装"
    echo "================================================"
    echo "可用字体："
    local i=1
    for font in "${NERD_FONTS[@]}"; do
        echo "$i) $font"
        ((i++))
    done
    echo "A) 安装所有"
    echo "B) 返回主菜单"
    echo "------------------------------------------------"
}

# 4. 修改思源字体安装菜单
show_source_han_menu() {
    echo "================================================"
    echo "            思源黑体安装"
    echo "================================================"
    echo "选择区域："
    echo "1) 简体中文 (CN)"
    echo "2) 繁体中文 (TW)"
    echo "3) 日文 (JP)"
    echo "4) 韩文 (KR)"
    echo "A) 安装所有区域"
    echo "B) 返回主菜单"
    echo "------------------------------------------------"
}

# 区域选择菜单
show_region_menu() {
    local type_name=$1
    echo "================================================"
    echo "            ${type_name}区域选择"
    echo "================================================"
    echo "1) 简体中文 (CN)"
    echo "2) 繁体中文 (TW)"
    echo "3) 日文 (JP)"
    echo "4) 韩文 (KR)"
    echo "A) 安装所有区域"
    echo "B) 返回上级菜单"
    echo "------------------------------------------------"
}

# 10. 修改卸载菜单
show_uninstall_menu() {
    echo "================================================"
    echo "            字体卸载"
    echo "================================================"
    echo "1) 卸载 Nerd Fonts"
    echo "2) 卸载思源黑体"
    echo "B) 返回主菜单"
    echo "------------------------------------------------"
}

# Nerd Fonts 卸载菜单
show_nerd_fonts_uninstall_menu() {
    echo "================================================"
    echo "            Nerd Fonts 卸载"
    echo "================================================"
    local installed_fonts=()
    local i=1
    
    for font in "${NERD_FONTS[@]}"; do
        if [ -d "/usr/local/share/fonts/nerd-fonts/${font}" ]; then
            installed_fonts+=("$font")
            echo "$i) $font"
            ((i++))
        fi
    done
    
    if [ ${#installed_fonts[@]} -eq 0 ]; then
        echo "未安装任何 Nerd Fonts"
        return 1
    fi
    
    echo "A) 卸载所有"
    echo "B) 返回上级菜单"
    echo "------------------------------------------------"
    
    return 0
}

# 13. 思源黑体卸载菜单(简化版)
show_source_han_uninstall_menu() {
    echo "================================================"
    echo "            思源黑体卸载"
    echo "================================================"
    local found=false
    local i=1
    
    for region in "${SOURCE_HAN_REGIONS[@]}"; do
        if [ -d "/usr/local/share/fonts/source-han-sans/${region}" ]; then
            found=true
            echo "$i) $region"
        fi
        ((i++))
    done
    
    if [ "$found" = false ]; then
        echo "未安装任何思源黑体"
        return 1
    fi
    
    echo "A) 卸载所有"
    echo "B) 返回上级菜单"
    echo "------------------------------------------------"
    
    return 0
}

# 字体统计信息显示
show_fonts_statistics() {
    echo "================================================"
    echo "            字体安装统计"
    echo "================================================"
    
    # Nerd Fonts 统计
    local nerd_fonts_count=0
    local nerd_fonts_size=0
    local nerd_fonts_dir="/usr/local/share/fonts/nerd-fonts"
    if [ -d "$nerd_fonts_dir" ]; then
        nerd_fonts_count=$(find "$nerd_fonts_dir" -name "*.[ot]tf" | wc -l)
        nerd_fonts_size=$(du -sh "$nerd_fonts_dir" | cut -f1)
    fi
    
    # # 思源宋体统计
    # local serif_count=0
    # local serif_size=0
    # local serif_dir="/usr/local/share/fonts/source-han-serif"
    # if [ -d "$serif_dir" ]; then
    #     serif_count=$(find "$serif_dir" -name "*.otf" | wc -l)
    #     serif_size=$(du -sh "$serif_dir" | cut -f1)
    # fi
    
    # 思源黑体统计
    local sans_count=0
    local sans_size=0
    local sans_dir="/usr/local/share/fonts/source-han-sans"
    if [ -d "$sans_dir" ]; then
        sans_count=$(find "$sans_dir" -name "*.otf" | wc -l)
        sans_size=$(du -sh "$sans_dir" | cut -f1)
    fi
    
    # 输出统计信息
    echo "Nerd Fonts:"
    echo "  版本: v${CURRENT_VERSION}"
    echo "  字体文件数: $nerd_fonts_count"
    echo "  占用空间: $nerd_fonts_size"
    echo ""
    # echo "思源宋体:"
    # echo "  版本: ${SOURCE_HAN_SERIF_VERSION}"
    # echo "  字体文件数: $serif_count"
    # echo "  占用空间: $serif_size"
    # echo ""
    echo "思源黑体:"
    echo "  版本: ${SOURCE_HAN_SANS_VERSION}"
    echo "  字体文件数: $sans_count"
    echo "  占用空间: $sans_size"
    echo ""
    echo "总计:"
    echo "  字体文件数: $((nerd_fonts_count + serif_count + sans_count))"
    echo "  总占用空间: $(du -sh /usr/local/share/fonts | cut -f1)"
    echo "------------------------------------------------"
}

# 等待用户输入
wait_for_input() {
    echo ""
    read -p "按回车键继续..."
}

# 主程序入口
main() {
    # 检查权限
    if [ "$(id -u)" != "0" ]; then
        log_message "ERROR" "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    # 加载配置
    load_config
    
    # 检查必要的命令
    for cmd in wget unzip fc-cache; do
        if ! command -v $cmd >/dev/null 2>&1; then
            log_message "ERROR" "未找到必要的命令: $cmd"
            exit 1
        fi
    done
    
    local choice
    while true; do
        show_main_menu
        read -p "请选择操作 [0-6]: " choice
        case $choice in
            1) handle_nerd_fonts_installation ;;
            2) handle_source_han_installation ;;
            3) handle_verification ;;
            4) handle_uninstallation ;;
            5) 
                show_fonts_statistics
                wait_for_input
                ;;
            6) check_updates ;;
            0) 
                log_message "INFO" "程序退出"
                exit 0
                ;;
            *) 
                log_message "WARNING" "无效的选择"
                wait_for_input
                ;;
        esac
    done
}

# Nerd Fonts 安装处理
handle_nerd_fonts_installation() {
    local choice
    while true; do
        show_nerd_fonts_menu
        read -p "请选择要安装的字体 [1-${#NERD_FONTS[@]}/A/B]: " choice
        case $choice in
            [1-9]|1[0-9])
                local index=$((choice-1))
                if [ $index -lt ${#NERD_FONTS[@]} ]; then
                    install_nerd_font "${NERD_FONTS[$index]}"
                    wait_for_input
                else
                    log_message "WARNING" "无效的选择"
                fi
                ;;
            [Aa])
                log_message "INFO" "开始安装所有 Nerd Fonts..."
                local commands=()
                for font in "${NERD_FONTS[@]}"; do
                    commands+=("install_nerd_font '$font'")
                done
                parallel_download_manager "${commands[@]}"
                wait_for_input
                ;;
            [Bb])
                return
                ;;
            *)
                log_message "WARNING" "无效的选择"
                ;;
        esac
    done
}

# 7. 修改安装处理函数
handle_source_han_installation() {
    local choice
    while true; do
        show_source_han_menu
        read -p "请选择区域 [1-4/A/B]: " choice
        case $choice in
            [1-4])
                local region=${SOURCE_HAN_REGIONS[$((choice-1))]}
                install_source_han "sans" "$region"
                wait_for_input
                ;;
            [Aa])
                log_message "INFO" "开始安装所有区域的思源黑体..."
                local commands=()
                for region in "${SOURCE_HAN_REGIONS[@]}"; do
                    commands+=("install_source_han 'sans' '$region'")
                done
                parallel_download_manager "${commands[@]}"
                wait_for_input
                ;;
            [Bb])
                return
                ;;
            *)
                log_message "WARNING" "无效的选择"
                wait_for_input
                ;;
        esac
    done
}

# 思源字体区域选择处理
handle_source_han_region_selection() {
    local type=$1
    local type_name
    [ "$type" = "serif" ] && type_name="思源宋体" || type_name="思源黑体"
    
    local choice
    while true; do
        show_region_menu "$type_name"
        read -p "请选择区域 [1-4/A/B]: " choice
        case $choice in
            [1-4])
                local region=${SOURCE_HAN_REGIONS[$((choice-1))]}
                install_source_han "$type" "$region"
                wait_for_input
                ;;
            [Aa])
                log_message "INFO" "开始安装所有区域的${type_name}..."
                local commands=()
                for region in "${SOURCE_HAN_REGIONS[@]}"; do
                    commands+=("install_source_han '$type' '$region'")
                done
                parallel_download_manager "${commands[@]}"
                wait_for_input
                ;;
            [Bb])
                return
                ;;
            *)
                log_message "WARNING" "无效的选择"
                ;;
        esac
    done
}

# 验证处理
handle_verification() {
    echo "================================================"
    echo "            字体验证"
    echo "================================================"
    
    local failed=0
    
    # 验证 Nerd Fonts
    if [ -d "/usr/local/share/fonts/nerd-fonts" ]; then
        verify_all_nerd_fonts || ((failed++))
    fi
    
    # 验证思源宋体
    if [ -d "/usr/local/share/fonts/source-han-serif" ]; then
        verify_all_source_han "serif" || ((failed++))
    fi
    
    # 验证思源黑体
    if [ -d "/usr/local/share/fonts/source-han-sans" ]; then
        verify_all_source_han "sans" || ((failed++))
    fi
    
    if [ $failed -eq 0 ]; then
        log_message "INFO" "所有字体验证通过"
    else
        log_message "WARNING" "有 $failed 项验证失败"
    fi
    
    wait_for_input
}

# 11. 修改卸载处理函数
handle_uninstallation() {
    local choice
    while true; do
        show_uninstall_menu
        read -p "请选择要卸载的字体类型 [1-2/B]: " choice
        case $choice in
            1) handle_nerd_fonts_uninstallation ;;
            2) handle_source_han_uninstallation ;;
            [Bb]) return ;;
            *)
                log_message "WARNING" "无效的选择"
                wait_for_input
                ;;
        esac
    done
}


# Nerd Fonts 卸载处理
handle_nerd_fonts_uninstallation() {
    local choice
    while true; do
        if ! show_nerd_fonts_uninstall_menu; then
            wait_for_input
            return
        fi
        
        read -p "请选择要卸载的字体 [1-9/A/B]: " choice
        case $choice in
            [1-9])
                local installed_fonts=()
                for font in "${NERD_FONTS[@]}"; do
                    if [ -d "/usr/local/share/fonts/nerd-fonts/${font}" ]; then
                        installed_fonts+=("$font")
                    fi
                done
                
                local index=$((choice-1))
                if [ $index -lt ${#installed_fonts[@]} ]; then
                    uninstall_nerd_font "${installed_fonts[$index]}"
                    wait_for_input
                else
                    log_message "WARNING" "无效的选择"
                fi
                ;;
            [Aa])
                uninstall_all_fonts_of_type "nerd"
                wait_for_input
                return
                ;;
            [Bb])
                return
                ;;
            *)
                log_message "WARNING" "无效的选择"
                ;;
        esac
    done
}

# 12. 思源黑体卸载处理函数(简化版)
handle_source_han_uninstallation() {
    local choice
    while true; do
        show_source_han_uninstall_menu
        read -p "请选择要卸载的区域 [1-4/A/B]: " choice
        case $choice in
            [1-4])
                local region=${SOURCE_HAN_REGIONS[$((choice-1))]}
                uninstall_source_han "$region"
                wait_for_input
                ;;
            [Aa])
                uninstall_all_source_han
                wait_for_input
                return
                ;;
            [Bb])
                return
                ;;
            *)
                log_message "WARNING" "无效的选择"
                ;;
        esac
    done
}

# 检查更新
check_updates() {
    log_message "INFO" "正在检查更新..."
    
    # 检查是否需要更新
    if ! should_check_update; then
        log_message "INFO" "距离上次检查更新未满24小时"
        wait_for_input
        return 0
    fi

    # 检查网络连接
    if ! ping -c 1 api.github.com &>/dev/null; then
        log_message "ERROR" "无法连接到 GitHub，请检查网络连接"
        wait_for_input
        return 1
    fi
    
    local has_updates=false

    # 检查 Nerd Fonts 更新
    log_message "INFO" "检查 Nerd Fonts 更新..."
    local latest_nerd_version
    latest_nerd_version=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -oP '"tag_name": "\K(.+)(?=")')
    
    if [ -n "$latest_nerd_version" ]; then
        latest_nerd_version=${latest_nerd_version#v}  # 移除版本号前的'v'
        if [ "$latest_nerd_version" != "$CURRENT_VERSION" ]; then
            has_updates=true
            log_message "INFO" "发现 Nerd Fonts 新版本: $latest_nerd_version (当前版本: $CURRENT_VERSION)"
        fi
    fi

    # 检查思源黑体更新
    log_message "INFO" "检查思源黑体更新..."
    local latest_sans_version
    latest_sans_version=$(curl -s "https://api.github.com/repos/adobe-fonts/source-han-sans/releases/latest" | grep -oP '"tag_name": "\K(.+)(?=")')
    
    if [ -n "$latest_sans_version" ]; then
        if [ "$latest_sans_version" != "$SOURCE_HAN_SANS_VERSION" ]; then
            has_updates=true
            log_message "INFO" "发现思源黑体新版本: $latest_sans_version (当前版本: $SOURCE_HAN_SANS_VERSION)"
        fi
    fi

    if [ "$has_updates" = true ]; then
        read -p "是否现在更新？[y/N] " choice
        case $choice in
            [Yy]*)
                # 更新版本信息
                [ -n "$latest_nerd_version" ] && CURRENT_VERSION="$latest_nerd_version"
                [ -n "$latest_sans_version" ] && SOURCE_HAN_SANS_VERSION="$latest_sans_version"
                save_config
                log_message "INFO" "版本信息已更新，请重新运行脚本以安装新版本"
                ;;
            *)
                log_message "INFO" "取消更新"
                ;;
        esac
    else
        log_message "INFO" "所有字体均为最新版本"
    fi
    
    # 更新最后检查时间
    save_config
    wait_for_input
}

# 启动主程序
main "$@"
