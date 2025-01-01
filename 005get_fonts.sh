#!/bin/bash
# 加载日志函数脚本
source 001log2File.sh

# 定义一个大的关联数组，包含收集到的所有字体信息，设计一个函数给该关联数组切片，方面调用
declare -A original_code_fonts_array
# 常用原版编程字体
original_code_fonts_array["JetBrainsMono"]="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
original_code_fonts_array["CascadiaCode"]="https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
original_code_fonts_array["monaspace"]="https://github.com/githubnext/monaspace/releases/download/v1.101/monaspace-v1.101.zip"
original_code_fonts_array["NotoSerifCJKsc"]="https://github.com/notofonts/noto-cjk/releases/download/Serif2.003/09_NotoSerifCJKsc.zip"
original_code_fonts_array["Fira_Code"]="https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
original_code_fonts_array["SourceHanMono"]="https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc"
original_code_fonts_array["SourceCodePro-Regular.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Regular.otf"
original_code_fonts_array["SourceCodePro-Bold.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Bold.otf"
original_code_fonts_array["SourceCodePro-It.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-It.otf"
original_code_fonts_array["SourceCodePro-Light.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Light.otf"
original_code_fonts_array["SourceCodePro-Medium.otf"]="https://github.com/adobe-fonts/source-code-pro/raw/release/OTF/SourceCodePro-Medium.otf"

# 常用编程nerd字体
declare -A code_fonts_array
code_fonts_array["JetBrainsMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz"
code_fonts_array["CascadiaCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.tar.xz"
code_fonts_array["FiraCode"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.tar.xz"
code_fonts_array["SauceCodePro"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/SourceCodePro.tar.xz"
code_fonts_array["Meslo"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Meslo.tar.xz"

# 思源字体简繁合集
declare -A chinese_fonts_array
chinese_fonts_array["SourceHanSansCN"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip"
chinese_fonts_array["SourceHanSansTW"]="https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansTW.zip"
chinese_fonts_array["SourceHanSerifCN"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/14_SourceHanSerifCN.zip"
chinese_fonts_array["SourceHanSerifTW"]="https://github.com/adobe-fonts/source-han-serif/releases/download/2.003R/15_SourceHanSerifTW.zip"

# 思源字体简繁单独下载
declare -A single_chinese_fonts_array
single_chinese_fonts_array["SourceSans3-Black.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Black.otf"
single_chinese_fonts_array["SourceSans3-BlackIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-BlackIt.otf"
single_chinese_fonts_array["SourceSans3-Bold.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Bold.otf"
single_chinese_fonts_array["SourceSans3-BoldIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-BoldIt.otf"
single_chinese_fonts_array["SourceSans3-ExtraLight.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-ExtraLight.otf"
single_chinese_fonts_array["SourceSans3-ExtraLightIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-ExtraLightIt.otf"
single_chinese_fonts_array["SourceSans3-It.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-It.otf"
single_chinese_fonts_array["SourceSans3-Light.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Light.otf"
single_chinese_fonts_array["SourceSans3-LightIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-LightIt.otf"
single_chinese_fonts_array["SourceSans3-Medium.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Medium.otf"
single_chinese_fonts_array["SourceSans3-MediumIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-MediumIt.otf"
single_chinese_fonts_array["SourceSans3-Regular.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Regular.otf"
single_chinese_fonts_array["SourceSans3-Semibold.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-Semibold.otf"
single_chinese_fonts_array["SourceSans3-SemiboldIt.otf"]="https://github.com/adobe-fonts/source-sans/raw/release/OTF/SourceSans3-SemiboldIt.otf"
single_chinese_fonts_array["SourceSerif"]="https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip"

# nerd-fonts,https://github.com/ryanoasis/nerd-fonts
declare -A nerd_fonts_array
nerd_fonts_array["0xProto"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/0xProto.tar.xz"
nerd_fonts_array["3270"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/3270.tar.xz"
nerd_fonts_array["Agave"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Agave.tar.xz"
nerd_fonts_array["AnonymousPro"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/AnonymousPro.tar.xz"
nerd_fonts_array["Arimo"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Arimo.tar.xz"
nerd_fonts_array["AurulentSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/AurulentSansMono.tar.xz"
nerd_fonts_array["BigBlueTerminal"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/BigBlueTerminal.tar.xz"
nerd_fonts_array["BitstreamVeraSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/BitstreamVeraSansMono.tar.xz"
nerd_fonts_array["CascadiaMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaMono.tar.xz"
nerd_fonts_array["CodeNewRoman"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CodeNewRoman.tar.xz"
nerd_fonts_array["ComicShannsMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/ComicShannsMono.tar.xz"
nerd_fonts_array["CommitMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CommitMono.tar.xz"
nerd_fonts_array["Cousine"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Cousine.tar.xz"
nerd_fonts_array["DaddyTimeMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/DaddyTimeMono.tar.xz"
nerd_fonts_array["DejaVuSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/DejaVuSansMono.tar.xz"
nerd_fonts_array["DroidSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/DroidSansMono.tar.xz"
nerd_fonts_array["EnvyCodeR"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/EnvyCodeR.tar.xz"
nerd_fonts_array["FantasqueSansMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FantasqueSansMono.tar.xz"
nerd_fonts_array["FiraMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraMono.tar.xz"
nerd_fonts_array["Go-Mono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Go-Mono.tar.xz"
nerd_fonts_array["Gohu"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Gohu.tar.xz"
nerd_fonts_array["Hack"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.tar.xz"
nerd_fonts_array["Hasklig"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hasklig.tar.xz"
nerd_fonts_array["HeavyData"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/HeavyData.tar.xz"
nerd_fonts_array["IBMPlexMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/IBMPlexMono.tar.xz"
nerd_fonts_array["Inconsolata"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Inconsolata.tar.xz"
nerd_fonts_array["InconsolataGo"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/InconsolataGo.tar.xz"
nerd_fonts_array["InconsolataLGC"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/InconsolataLGC.tar.xz"
nerd_fonts_array["IntelOneMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/IntelOneMono.tar.xz"
nerd_fonts_array["iA-Writer"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/iA-Writer.tar.xz"
nerd_fonts_array["Iosevka"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Iosevka.tar.xz"
nerd_fonts_array["IosevkaTerm"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/IosevkaTerm.tar.xz"
nerd_fonts_array["IosevkaTermSlab"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/IosevkaTermSlab.tar.xz"
nerd_fonts_array["Lekton"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Lekton.tar.xz"
nerd_fonts_array["LiberationMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/LiberationMono.tar.xz"
nerd_fonts_array["Lilex"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Lilex.tar.xz"
nerd_fonts_array["MartianMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/MartianMono.tar.xz"
nerd_fonts_array["Monaspace"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Monaspace.tar.xz"
nerd_fonts_array["Monofur"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Monofur.tar.xz"
nerd_fonts_array["Monoid"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Monoid.tar.xz"
nerd_fonts_array["Mononoki"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Mononoki.tar.xz"
nerd_fonts_array["MPlus"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/MPlus.tar.xz"
nerd_fonts_array["Noto"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Noto.tar.xz"
nerd_fonts_array["OpenDyslexic"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/OpenDyslexic.tar.xz"
nerd_fonts_array["Overpass"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Overpass.tar.xz"
nerd_fonts_array["ProFont"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/ProFont.tar.xz"
nerd_fonts_array["ProggyClean"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/ProggyClean.tar.xz"
nerd_fonts_array["Recursive"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Recursive.tar.xz"
nerd_fonts_array["RobotoMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/RobotoMono.tar.xz"
nerd_fonts_array["ShareTechMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/ShareTechMono.tar.xz"
nerd_fonts_array["SourceCodePro"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/SourceCodePro.tar.xz"
nerd_fonts_array["SpaceMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/SpaceMono.tar.xz"
nerd_fonts_array["Terminus"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Terminus.tar.xz"
nerd_fonts_array["Tinos"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Tinos.tar.xz"
nerd_fonts_array["Ubuntu"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Ubuntu.tar.xz"
nerd_fonts_array["UbuntuMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/UbuntuMono.tar.xz"
nerd_fonts_array["UbuntuSans"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/UbuntuSans.tar.xz"
nerd_fonts_array["VictorMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/VictorMono.tar.xz"
nerd_fonts_array["ZedMono"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/ZedMono.tar.xz"
nerd_fonts_array["NerdFontsSymbolsOnly"]="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/NerdFontsSymbolsOnly.tar.xz"

# 过程函数：根据起止索引获取关联数组的子集，并返回一个关联数组
# 参数1：关联数组的名称，参数2：起始索引，参数3：结束索引，假如参数2和3都是0，则返回组成关联数组的第0个
#!/bin/bash

# 函数：根据起止索引获取关联数组的子集
get_subset_by_range() {
    local -n assoc_array="$1"   # 关联数组的名称（使用 namevar）
    local start="$2"            # 起始索引
    local end="$3"              # 结束索引
    # 检查关联数组是否为关联数组
    if [[ ! ${!assoc_array@a} == A ]]; then # ${!assoc_array@a} 用于检查变量 assoc_array 是否是关联数组。如果是，则返回 A，否则返回其他值。
        echo "错误：参数 1 必须是关联数组的名称。" >&2 # 将错误信息输出到标准错误流 (stderr）
        return 1 # 函数返回 1 表示出错。
    fi   

    # 检查起止索引是否为整数
    if ! [[ "$start" =~ ^-?[0-9]+$ ]] || ! [[ "$end" =~ ^-?[0-9]+$ ]]; then # =~ 是正则表达式匹配。^-?[0-9]+$ 匹配整数，包括正数、负数和零。
        echo "错误：起始和结束索引必须是整数。" >&2
        return 1
    fi   

    local -a keys=("${!assoc_array[@]}") # 获取关联数组的所有键。${!assoc_array[@]} 会展开为关联数组的所有键。
    local num_keys="${#keys[@]}" # 获取键的数量。${#keys[@]} 返回数组 keys 的元素个数   
    # 处理负数索引。例如，-1 表示最后一个元素，-2 表示倒数第二个元素，以此类推。
    if (( start < 0 )); then
        start=$(( num_keys + start )) # 将负数索引转换为正数索引。
    fi
    if (( end < 0 )); then
        end=$(( num_keys + end )) # 将负数索引转换为正数索引。
    fi

    # 确保start和end在范围内，防止越界访问。
    if (( start < 0 )); then start=0; fi # 如果 start 小于 0，则将其设置为 0。
    if (( end >= num_keys )); then end=$((num_keys - 1)); fi # 如果 end 大于等于键的数量，则将其设置为最后一个键的索引。

    # 交换 start 和 end，以支持反向选择。例如，如果 start 是 3，end 是 1，则交换它们，使 start 变为 1，end 变为 3。
    if (( start > end )); then
        local tmp="$start" # 使用一个临时变量 tmp 来存储 start 的值。
        start="$end" #   将 end 的值赋给 start。
        end="$tmp" # 将 tmp（原来的 start 值）赋给 end。
    fi

    declare -A subset_array # 用于存储子集的关联数组。-A 声明一个关联数组。

    # 遍历选定的键
    for (( i = start; i <= end; i++ )); do # for 循环，从 start 遍历到 end。
        local key="${keys[$i]}" # 获取当前索引 i 对应的键。
        subset_array[$key]="${assoc_array[$key]}" # 将原关联数组中对应键的值复制到子集关联数组中。
    done

    # 将子集关联数组的名称通过 namevar 返回。这里返回的是变量名，而不是变量的值。
    echo "$subset_array"
}

# 示例用法：

# 获取子集 (正向选择)
subset=$(get_subset_by_range my_array 1 3) # 调用函数，并将返回的子集数组名赋值给 subset 变量。
if [[ $? -eq 0 ]]; then # $? 是上一个命令的退出状态。0 表示成功，非 0 表示出错。
    declare -n subset_array="$subset" # 使用 namevar 声明 subset_array，使其成为 subset 所代表的关联数组的别名。
    echo "正向选择 (1 到 3)："
    for key in "${!subset_array[@]}"; do # 遍历子集关联数组的键。
        echo "$key: ${subset_array[$key]}" # 输出键和值。
    done
fi

# 其他示例用法类似，只是使用了不同的起止索引和错误处理。
# ... (其他示例代码)

# 输出：
# 正向选择 (1 到 3)：
# apple: red
# banana: yellow
# grape: purple
# 反向选择 (3 到 1)：
# grape: purple
# banana: yellow
# apple: red
# 包含负数索引 (-3 到 -1)：
# banana: yellow
# grape: purple
# orange: orange
# 越界索引 (1 到 10)：
# apple: red
# banana: yellow
# grape: purple
# orange: orange
# 测试错误处理：参数类型错误被正确捕获。


# 函数：安装字体
# 参数：font_info - 关联数组，包含字体名称和下载URL
install_fonts() {
    # 声明关联数组参数
    declare -n font_info=$1

    # 检查并安装必要的命令
    if ! command -v file >/dev/null 2>&1; then
        log 1 "安装 file 命令..."
        if ! sudo apt-get install -y file; then
            log 3 "安装 file 命令失败"
            return 1
        fi
    fi

    sudo apt install -y --install-recommends fnt 

    # 定义字体安装目录
    local install_dir="/usr/share/fonts/truetype"
    # 创建临时目录
    local tmp_dir=$(mktemp -d)
    # 脚本退出时删除临时目录
    trap 'rm -rf "$tmp_dir"' EXIT

    # 检查并创建安装目录
    if [ ! -d "$install_dir" ]; then
        if ! sudo mkdir -p "$install_dir"; then
            log 3 "创建字体目录失败"
            return 1
        fi
    fi

    # 获取已安装字体列表
    log 1 "获取已安装字体列表..."
    local installed_fonts
    installed_fonts=$(fc-list | awk -F: '{print $1}' | xargs -I {} basename {})

    # 用于统计安装结果
    local total_installed=0
    local total_skipped=0

    # 遍历字体信息数组
    for font_name in "${!font_info[@]}"; do
        local font_url="${font_info[$font_name]}"
        local download_file="$tmp_dir/${font_name}_download"
        
        # 下载字体文件
        log 1 "下载 ${font_name} 字体..."
        local retry_count=0
        local max_retries=3
        local download_success=false

        while (( retry_count < max_retries )) && [[ "$download_success" == "false" ]]; do
            if wget -q --show-progress "$font_url" -O "$download_file"; then
                download_success=true
            else
                ((retry_count++))
                if (( retry_count < max_retries )); then
                    log 2 "下载 ${font_name} 失败，第 ${retry_count} 次重试..."
                    sleep 2  # 等待2秒后重试
                fi
            fi
        done

        if [[ "$download_success" == "false" ]]; then
            log 3 "下载 ${font_name} 失败，已重试 ${retry_count} 次"
            continue
        fi

        # 检查文件类型
        local file_type=""
        if command -v file >/dev/null 2>&1; then
            file_type=$(file -b "$download_file")
        fi
        
        # 创建临时解压目录
        local extract_dir="$tmp_dir/${font_name}"
        mkdir -p "$extract_dir"
        
        # 处理压缩文件
        if [[ "$file_type" == *"Zip archive"* ]] || [[ "$download_file" == *.zip ]] || 
           [[ "$file_type" == *"gzip compressed"* ]] || [[ "$download_file" == *.tar.gz ]]; then
            log 1 "解压 ${font_name}..."

            # 根据文件类型或扩展名选择解压方法
            if [[ "$file_type" == *"Zip archive"* ]] || [[ "$download_file" == *.zip ]]; then
                if ! unzip -q "$download_file" -d "$extract_dir"; then
                    log 3 "解压 ${font_name} 失败"
                    rm -rf "$extract_dir"
                    continue
                fi
            elif [[ "$file_type" == *"gzip compressed"* ]] || [[ "$download_file" == *.tar.gz ]]; then
                if ! tar -xzf "$download_file" -C "$extract_dir"; then
                    log 3 "解压 ${font_name} 失败"
                    rm -rf "$extract_dir"
                    continue
                fi
            fi
            
            # 移动下载文件到解压目录，以便统一处理
            mv "$download_file" "$extract_dir/"
        else
            # 如果是单个字体文件，直接移动到解压目录
            mv "$download_file" "$extract_dir/"
        fi

        # 查找所有字体文件并处理
        log 1 "检查 ${font_name} 的字体文件..."
        while IFS= read -r font_file; do
            local base_name=$(basename "$font_file")
            
            log 1 "检查文件类型是否为字体文件"
            local is_font_file=false
            local font_file_type=""
            
            if command -v file >/dev/null 2>&1; then
                font_file_type=$(file -b "$font_file")
                if [[ "$font_file_type" == *"TrueType"* ]] || 
                   [[ "$font_file_type" == *"OpenType"* ]] || 
                   [[ "$font_file_type" == *"font"* ]]; then
                    is_font_file=true
                fi
            fi
            
            log  1 "如果 file 命令不可用或未识别为字体，检查文件扩展名"
            if [[ "$is_font_file" == "false" ]]; then
                case "${font_file,,}" in
                    *.ttf|*.otf|*.ttc)
                        is_font_file=true
                        ;;
                esac
            fi
            
            # 如果不是字体文件，跳过
            if [[ "$is_font_file" == "false" ]]; then
                continue
            fi

            log 1 "检查是否已安装 ${base_name}..." 
            if echo "$installed_fonts" | grep -q "$base_name"; then
                log 2 "字体文件 ${base_name} 已安装，跳过"
                ((total_skipped++))
            else
                if sudo mv "$font_file" "$install_dir/"; then
                    log 1 "安装字体文件 ${base_name} 成功"
                    ((total_installed++))
                else
                    log 3 "安装字体文件 ${base_name} 失败"
                fi
            fi
        done < <(find "$extract_dir" -type f)

        # 清理临时目录
        rm -rf "$extract_dir"
    done

    # 更新字体缓存
    log 1 "更新字体缓存..."
    if ! command -v fc-cache >/dev/null 2>&1; then
        log 3 "缺少 fc-cache 命令"
        return 1
    fi
    if ! sudo fc-cache -f >/dev/null 2>&1; then
        log 3 "更新字体缓存失败"
        return 1
    fi

    log 1 "字体安装完成：安装 ${total_installed} 个，跳过 ${total_skipped} 个"
    return 0
}

# 如果脚本被直接运行（不是被source），则运行示例代码
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 调用安装函数
    install_fonts code_fonts_array
fi

# # 更简单的安装方法，对Debian系统适用
# sudo apt install -y --install-recommends \
# fnt \
# fonts-jetbrains-mono fonts-cascadia-code \
# fonts-hack-otf fonts-hack-ttf  fonts-adobe-sourcesans3 \
# fonts-lxgw-wenkai fonts-wqy-microhei fonts-wqy-zenhei \
# fonts-noto-cjk-extra fonts-noto-mono fonts-firacode