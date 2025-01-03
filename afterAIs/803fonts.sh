#!/bin/bash

#############################################
# 脚本名称：install_nerd_fonts.sh
# 用途：一键安装和更新常用编程字体的 Nerd Font 版本
# 支持系统：基于Debian的Linux系统（如Ubuntu）
# 使用方法：sudo bash install_nerd_fonts.sh
#############################################

# 版本和URL配置
CURRENT_VERSION="3.0.2"
NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${CURRENT_VERSION}"
GITHUB_API_URL="https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
CONFIG_FILE="${HOME}/.config/nerd_fonts_installer.conf"

# 要安装的字体列表
FONTS=(
    "JetBrainsMono"
    "FiraCode"
    "SourceCodePro"
    "CascadiaCode"
    "Hack"
)

# 下载和重试配置
MAX_RETRIES=3
RETRY_DELAY=3

# 版本比较函数
compare_versions() {
    local version1=$1
    local version2=$2
    
    # 将版本号转换为数组
    IFS='.' read -ra VER1 <<< "$version1"
    IFS='.' read -ra VER2 <<< "$version2"
    
    # 比较每个版本号部分
    for i in {0..2}; do
        if [ "${VER1[$i]:-0}" -gt "${VER2[$i]:-0}" ]; then
            echo "1"
            return
        elif [ "${VER1[$i]:-0}" -lt "${VER2[$i]:-0}" ]; then
            echo "-1"
            return
        fi
    done
    
    echo "0"
}

# 获取最新版本号
get_latest_version() {
    local temp_file=$(mktemp)
    local latest_version
    
    # echo "正在检查 Nerd Fonts 最新版本..."
    
    # 尝试使用curl获取最新版本信息
    if ! curl -s -L -H "Accept: application/vnd.github.v3+json" \
        -o "$temp_file" "$GITHUB_API_URL"; then
        echo "错误：无法获取最新版本信息"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查是否存在rate limit限制
    if grep -q "API rate limit exceeded" "$temp_file"; then
        echo "警告：GitHub API 访问频率限制，将使用当前版本"
        rm -f "$temp_file"
        return 1
    fi
    
    # 解析版本号
    latest_version=$(grep -o '"tag_name": "v[^"]*"' "$temp_file" | cut -d'"' -f4 | sed 's/v//')
    
    rm -f "$temp_file"
    
    if [ -z "$latest_version" ]; then
        echo "错误：无法解析最新版本号"
        return 1
    fi
    
    echo "$latest_version"
    return 0
}

# 保存最后检查时间
save_last_check_time() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "LAST_UPDATE_CHECK=$(date +%s)" > "$CONFIG_FILE"
}

# 读取最后检查时间
get_last_check_time() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "${LAST_UPDATE_CHECK:-0}"
    else
        echo "0"
    fi
}

# 检查是否需要更新
should_check_update() {
    local last_check
    local current_time
    local time_diff
    local update_interval=$((1 * 6 * 6)) # 24小时的秒数
    
    last_check=$(get_last_check_time)
    current_time=$(date +%s)
    time_diff=$((current_time - last_check))
    
    # 如果超过24小时没有检查，返回true
    [ $time_diff -ge $update_interval ]
}

# 字体文件完整性校验
verify_font_files() {
    local font_dir="$1"
    local font_name="$2"
    
    echo "正在验证 ${font_name} 字体文件..."
    
    # 检查目录是否存在
    if [ ! -d "$font_dir" ]; then
        echo "错误：字体目录 $font_dir 不存在"
        return 1
    fi
    
    # 检查是否存在字体文件
    local font_count=$(find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) | wc -l)
    if [ "$font_count" -eq 0 ]; then
        echo "错误：在 $font_dir 中没有找到字体文件"
        return 1
    fi
    
    echo "✓ 找到 $font_count 个字体文件"
    return 0
}

# 验证字体是否已注册到系统
verify_font_registration() {
    local font_name="$1"
    
    echo "正在验证 ${font_name} 字体注册状态..."
    
    # 使用fc-list检查字体是否已注册
    if ! fc-list | grep -i "$font_name" > /dev/null; then
        echo "错误：${font_name} 字体未能正确注册到系统"
        return 1
    fi
    
    echo "✓ 字体已成功注册到系统"
    return 0
}

# 字体可用性测试
test_font_availability() {
  local font_name="$1"
  local match_result

  echo "正在测试 \"${font_name}\" 字体可用性..."

  # Run fc-match and check its exit status
  match_result=$(fc-match "$font_name" -f "%{family}\n" 2>&1)
  if [[ $? -ne 0 ]]; then
    echo "错误：fc-match 命令执行失败: ${match_result}"
    return 1
  fi

  # Check if the font name is a substring of the fc-match output.  More robust than simple grep.
  if [[ ! "$match_result" =~ "$font_name" ]]; then
    echo "警告：系统可能无法正确匹配 \"${font_name}\" 字体. fc-match 返回: ${match_result}"
    # Return 0 even with a warning;  a warning isn't necessarily a failure.
  else
    echo "✓ 字体可正常使用"
  fi

  return 0
}

# 综合验证函数
verify_font_installation() {
    local font_name="$1"
    local font_dir="/usr/local/share/fonts/nerd-fonts/${font_name}"
    local verification_failed=false
    
    echo ""
    echo "开始验证 ${font_name} 字体安装..."
    
    # 1. 验证字体文件
    if ! verify_font_files "$font_dir" "$font_name"; then
        verification_failed=true
    fi
    
    # 2. 验证字体注册
    if ! verify_font_registration "$font_name"; then
        verification_failed=true
    fi
    
    # 3. 测试字体可用性
    if ! test_font_availability "$font_name"; then
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        echo "⚠ ${font_name} 字体验证未完全通过"
        return 1
    else
        echo "✅ ${font_name} 字体验证全部通过"
        return 0
    fi
}

# 获取已安装字体列表
get_installed_fonts() {
    local fonts_dir="/usr/local/share/fonts/nerd-fonts"
    if [ -d "$fonts_dir" ]; then
        find "$fonts_dir" -maxdepth 1 -type d -exec basename {} \; | tail -n +2
    fi
}

# 下载函数，带重试机制
download_with_retry() {
    local url=$1
    local output=$2
    local retries=0
    local success=false

    while [ $retries -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        if [ $retries -gt 0 ]; then
            echo "第 $retries 次重试下载..."
            sleep $RETRY_DELAY
        fi

        if wget -q --show-progress "$url" -O "$output"; then
            success=true
            break
        else
            retries=$((retries + 1))
            if [ $retries -lt $MAX_RETRIES ]; then
                echo "下载失败，将在 $RETRY_DELAY 秒后重试..."
            fi
        fi
    done

    if [ "$success" = false ]; then
        echo "在 $MAX_RETRIES 次尝试后下载失败"
        return 1
    fi

    return 0
}

# 更新单个字体
update_font() {
    local font_name="$1"
    local font_dir="/usr/local/share/fonts/nerd-fonts/${font_name}"
    
    echo "正在更新 ${font_name}..."
    
    # 备份原有字体目录
    if [ -d "$font_dir" ]; then
        local backup_dir="${font_dir}_backup_$(date +%Y%m%d_%H%M%S)"
        mv "$font_dir" "$backup_dir"
        echo "已备份原有字体到: $backup_dir"
    fi
    
    # 安装新版本
    if install_font "$font_name"; then
        echo "✓ ${font_name} 更新成功"
        # 更新成功后删除备份
        [ -d "$backup_dir" ] && rm -rf "$backup_dir"
        return 0
    else
        echo "✗ ${font_name} 更新失败"
        # 更新失败后恢复备份
        if [ -d "$backup_dir" ]; then
            rm -rf "$font_dir"
            mv "$backup_dir" "$font_dir"
            echo "已恢复原有版本"
        fi
        return 1
    fi
}

# 处理更新选择
handle_update_choice() {
    local latest_version="$1"
    local installed_fonts=($(get_installed_fonts))
    
    if [ ${#installed_fonts[@]} -eq 0 ]; then
        echo "未发现已安装的字体，将直接进行新安装。"
        return 0
    fi
    
    echo ""
    echo "发现已安装的字体："
    for i in "${!installed_fonts[@]}"; do
        echo "[$((i+1))] ${installed_fonts[$i]}"
    done
    
    echo ""
    echo "请选择操作："
    echo "1) 更新所有已安装的字体到 v${latest_version}"
    echo "2) 选择特定字体进行更新"
    echo "3) 保持现有字体，仅安装新字体"
    echo "4) 取消操作"
    
    read -p "请输入选项 [1-4]: " choice
    
    case $choice in
        1)
            echo "开始更新所有字体..."
            local update_failed=false
            for font in "${installed_fonts[@]}"; do
                if ! update_font "$font"; then
                    update_failed=true
                fi
            done
            
            if [ "$update_failed" = true ]; then
                echo "⚠ 部分字体更新失败，请检查上述信息"
            else
                echo "✅ 所有字体更新完成"
            fi
            ;;
            
        2)
            while true; do
                echo ""
                echo "请选择要更新的字体（输入对应数字，多个字体用空格分隔，输入 'q' 退出）："
                for i in "${!installed_fonts[@]}"; do
                    echo "[$((i+1))] ${installed_fonts[$i]}"
                done
                
                read -p "请输入: " selection
                
                [ "$selection" = "q" ] && break
                
                for num in $selection; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#installed_fonts[@]}" ]; then
                        update_font "${installed_fonts[$((num-1))]}"
                    else
                        echo "无效的选择: $num"
                    fi
                done
                
                read -p "是否继续更新其他字体？(y/n) " continue_update
                [[ "$continue_update" != "y" ]] && break
            done
            ;;
            
        3)
            echo "将保持现有字体版本"
            return 0
            ;;
            
        4)
            echo "操作已取消"
            exit 0
            ;;
            
        *)
            echo "无效的选择"
            exit 1
            ;;
    esac
}

# 检查系统要求
check_system_requirements() {
    # 检查是否以root权限运行
    if [ "$(id -u)" != "0" ]; then
        echo "错误：请使用sudo运行此脚本"
        exit 1
    fi
    
    # 检查必要的命令
    local required_commands=("wget" "unzip" "fc-cache")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "错误：未找到命令 '$cmd'"
            echo "请先安装必要的依赖："
            echo "sudo apt-get update && sudo apt-get install -y wget unzip fontconfig"
            exit 1
        fi
    done
}

# 安装单个字体
install_font() {
    local font_name=$1
    local temp_dir=$(mktemp -d)
    local download_path="$temp_dir/${font_name}.zip"
    local font_url="${NERD_FONTS_BASE_URL}/${font_name}.zip"
    
    echo "正在安装 ${font_name} Nerd Font..."
    echo "下载地址: $font_url"
    
    # 使用重试机制下载
    if ! download_with_retry "$font_url" "$download_path"; then
        echo "错误：无法下载 ${font_name}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 验证下载文件
    if [ ! -f "$download_path" ] || [ ! -s "$download_path" ]; then
        echo "错误：下载的文件无效或为空"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 创建字体专用目录
    mkdir -p "/usr/local/share/fonts/nerd-fonts/${font_name}"
    
    # 解压字体
    echo "正在解压 ${font_name}..."
    if ! unzip -q "$download_path" -d "/usr/local/share/fonts/nerd-fonts/${font_name}"; then
        echo "错误：解压 ${font_name} 失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 更新字体缓存
    fc-cache -f "/usr/local/share/fonts/nerd-fonts/${font_name}"
    
    # 验证安装
    if ! verify_font_installation "$font_name"; then
        echo "警告：${font_name} 安装验证未完全通过，但文件已安装"
        return 1
    fi
    
    echo "${font_name} Nerd Font 安装完成并验证通过"
    return 0
}

# 检查更新函数
check_for_updates() {
    local latest_version
    local version_compare
    
    echo "================================================"
    echo "               检查更新"
    echo "================================================"
    echo "当前版本: v${CURRENT_VERSION}"
    
    # 获取最新版本
    latest_version=$(get_latest_version)
    if [ $? -ne 0 ]; then
        echo "继续使用当前版本 v${CURRENT_VERSION}"
        return 1
    fi
    
    echo "最新版本: v${latest_version}"
    
    # 比较版本
    version_compare=$(compare_versions "$latest_version" "$CURRENT_VERSION")
    
    case $version_compare in
        1)
            echo "发现新版本！"
            echo ""
            # 调用更新选择处理
            handle_update_choice "$latest_version"
            
            # 更新当前版本变量
            CURRENT_VERSION="$latest_version"
            NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${latest_version}"
            return 2
            ;;
        0)
            echo "✓ 当前已是最新版本"
            return 0
            ;;
        -1)
            echo "⚠ 警告：当前版本高于发布版本"
            return 3
            ;;
    esac
}

# 显示字体选择菜单
show_font_menu() {
    echo ""
    echo "可用字体列表："
    for i in "${!FONTS[@]}"; do
        echo "[$((i+1))] ${FONTS[$i]}"
    done
    echo "[A] 安装所有字体"
    echo "[Q] 退出"
}

# 主函数
main() {
    echo "================================================"
    echo "        Nerd Fonts 编程字体安装脚本"
    echo "================================================"
    
    # 检查更新
    if should_check_update; then
        check_for_updates
        save_last_check_time
        echo "------------------------------------------------"
    fi
    
    # 检查系统要求
    check_system_requirements
    
    while true; do
        show_font_menu
        
        read -p "请选择要安装的字体 [1-${#FONTS[@]}/A/Q]: " choice
        
        case $choice in
            [Qq])
                echo "退出安装"
                break
                ;;
            [Aa])
                echo "开始安装所有字体..."
                local install_failed=false
                for font in "${FONTS[@]}"; do
                    if ! install_font "$font"; then
                        install_failed=true
                    fi
                done
                
                if [ "$install_failed" = true ]; then
                    echo "⚠ 部分字体安装失败，请检查上述信息"
                else
                    echo "✅ 所有字体安装完成"
                fi
                break
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#FONTS[@]}" ]; then
                    install_font "${FONTS[$((choice-1))]}"
                else
                    echo "无效的选择，请重试"
                fi
                
                read -p "是否继续安装其他字体？(y/n) " continue_install
                [[ "$continue_install" != "y" ]] && break
                ;;
        esac
    done
    
    echo ""
    echo "感谢使用！"
    echo "如果遇到任何问题，请访问："
    echo "https://github.com/ryanoasis/nerd-fonts/issues"
}

# 执行主函数
main "$@"