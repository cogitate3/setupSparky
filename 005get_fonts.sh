#!/bin/bash
# 辅助函数：下载并安装zip格式的字体

# 辅助字体，下载并安装zip格式的字体
download_and_install_zip() {
    local font_name="$1"
    local font_url="$2"
    local font_file="$3"
    local tmp_dir="$4"
    local install_dir="$5"

    log 1 "下载 ${font_name} 字体..."
    if ! wget -q --show-progress "$font_url" -O "$font_file"; then
        log 3 "下载 ${font_name} 失败"
        return 1
    fi

    log 1 "解压 ${font_name}..."
    if ! unzip -q "$font_file" -d "$tmp_dir/${font_name}"; then
        log 3 "解压 ${font_name} 失败"
        return 1
    fi

    # 移动所有字体文件（支持ttf和otf）
    local font_count=0
    while IFS= read -r font; do
        sudo mv "$font" "$install_dir/"
        ((font_count++))
    done < <(find "$tmp_dir/${font_name}" -type f \( -name "*.ttf" -o -name "*.otf" \))

    if [ "$font_count" -eq 0 ]; then
        log 3 "未找到任何字体文件"
        return 1
    fi

    log 1 "${font_name} 安装成功，共安装 ${font_count} 个字体文件"
    return 0
}

# 辅助函数：下载并安装ttc格式的字体
download_and_install_ttc() {
    local font_name="$1"
    local font_url="$2"
    local font_file="$3"
    local install_dir="$4"

    log 1 "下载 ${font_name} 字体..."
    if ! wget -q --show-progress "$font_url" -O "$font_file"; then
        log 3 "下载 ${font_name} 失败"
        return 1
    fi

    # 直接移动ttc文件
    if ! sudo mv "$font_file" "$install_dir/"; then
        log 3 "移动 ${font_name} 失败"
        return 1
    fi

    log 1 "${font_name} 安装成功"
    return 0
}


# 函数：安装字体
function install_fonts() {
    local font_list=("JetBrainsMono" "CascadiaCode" "SourceHanMono")
    local font_url
    local font_file
    local install_dir="/usr/share/fonts/truetype"
    local tmp_dir="/tmp/fonts"

    log 1 "创建临时目录和安装目录"
    rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
    # Check if the fonts directory exists, create it if not
    if [ ! -d "$install_dir" ]; then
        sudo mkdir -p "$install_dir" || { log 3 "创建字体目录失败"; return 1; }
    fi

    for font_name in "${font_list[@]}"; do
        case "$font_name" in
            "JetBrainsMono")
                # JetBrains Mono - 最新版本包含所有变体
                font_url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
                font_file="$tmp_dir/${font_name}.zip"
                download_and_install_zip "$font_name" "$font_url" "$font_file" "$tmp_dir" "$install_dir"
                ;;
            "CascadiaCode")
                # Cascadia Code - 包含等宽和非等宽变体
                font_url="https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
                font_file="$tmp_dir/${font_name}.zip"
                download_and_install_zip "$font_name" "$font_url" "$font_file" "$tmp_dir" "$install_dir"
                ;;
            "SourceHanMono")
                # Source Han Mono - 思源等宽字体，支持中日韩
                font_url="https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc"
                font_file="$tmp_dir/${font_name}.ttc"
                download_and_install_ttc "$font_name" "$font_url" "$font_file" "$install_dir"
                ;;
        esac
    done

    log 1 "清理临时文件"
    rm -rf "$tmp_dir"

    log 1 "更新字体缓存..."
    if ! sudo fc-cache -fv; then
        log 3 "更新字体缓存失败"
        return 1
    fi
    log 2 "JetBrainsMono, CascadiaCode, SourceHanMono字体安装完成"
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_fonts
fi