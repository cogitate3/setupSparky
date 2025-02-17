#!/bin/bash

# 日志相关配置
# source 001log2File.sh 003get_download_link.sh里面引入了001log2File.sh和002get_assets_links.sh
source 003get_download_link.sh
source 005get_fonts.sh
source 006double-Esc-to-sudo.sh
# 先设置日志
log "/tmp/logs/901.log" 1 "第一条消息，同时设置日志文件"
log 2 "日志记录在${CURRENT_LOG_FILE}"


# check_root函数
check_root() {
    if [ $(id -u) -ne 0 ]; then
        log 3 "必须使用root权限运行此脚本"
        exit 1
    fi
    log 1 "Root权限检查通过"
}

# 过程函数：检查和安装依赖的函数
check_and_install_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    # 检查每个依赖是否已安装
    for dep in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii\s*$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    # 如果有缺失的依赖，尝试安装它们
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log 1 "安装缺失的依赖: ${missing_deps[*]}"
        if ! sudo apt update; then
            log 3 "更新软件包列表失败"
            return 1
        fi
        if ! sudo apt install -y "${missing_deps[@]}"; then
            log 3 "安装依赖失败: ${missing_deps[*]}"
            return 1
        fi
        log 1 "依赖安装成功"
    else
        log 1 "所有依赖已满足"
    fi
    return 0
}

# 过程函数：检查deb包依赖的函数，对于下载的deb包
check_deb_dependencies() {
    local deb_file="$1"
    
    # 检查文件是否存在
    if [ ! -f "$deb_file" ]; then
        log 3 "deb文件不存在: $deb_file"
        return 1
    fi
    
    # 获取依赖列表
    log 1 "检查 $deb_file 的依赖..."
    local deps=$(dpkg-deb -f "$deb_file" Depends | tr ',' '\n' | sed 's/([^)]*)//g' | sed 's/|.*//g' | tr -d ' ')
    
    # 显示依赖
    log 1 "包含以下依赖:"
    echo "$deps" | while read -r dep; do
        if [ ! -z "$dep" ]; then
            log 1 "- $dep"
        fi
    done
    
    # 检查并安装依赖
    if ! check_and_install_dependencies $deps; then
        log 3 "依赖安装失败"
        return 1
    fi
    
    return 0
}

# 过程函数：检查已安装软件的依赖，对于仓库中的软件
show_package_dependencies() {
    local package_name="$1"
    
    log 1 "检查 $package_name 的依赖..."
    
    # 检查包是否在仓库中
    if ! apt-cache show "$package_name" > /dev/null 2>&1; then
        log 3 "软件包 $package_name 在仓库中未找到"
        return 1
    fi
    
    # 获取并显示依赖
    log 1 "包含以下依赖:"
    apt-cache depends "$package_name" | grep Depends | cut -d: -f2 | while read -r dep; do
        if [ ! -z "$dep" ]; then
            log 1 "- $dep"
        fi
    done
    
    return 0
}

# 过程函数：多列对齐显示
display_items() {
    local cols="$1"          # 第一个参数为显示的列数
    shift                     # 移除第一个参数，剩余参数为数组
    local items=("$@")        # 将剩余参数作为数组
    green_inline() {
    printf "\033[32m%s\033[0m" "$@" # 格式化文本为绿色
    }
    # 格式化数组内容
    local formatted_items=()
    for item in "${items[@]}"; do
        formatted_items+=("$(green_inline "$item")")
    done

    # 使用 paste 和 column 命令实现多列显示
    # 1. printf "%s\n" "${formatted_items[@]}" : 将格式化后的数组项每项单独输出为一行
    # 2. paste - $(printf -- '- %.0s' $(seq 1 $((cols - 1)))) : 
    #    - seq 1 $((cols - 1)) 生成从1到(列数-1)的序列
    #    - printf -- '- %.0s' 对每个序列数字生成一个 '-' 作为占位符
    #    - paste 命令将多行内容合并为多列，'-' 代表标准输入，每个额外的 '-' 创建一个新列
    # 3. column -t -s $'\t' : 
    #    - -t 选项让 column 命令创建一个表格式的输出
    #    - -s $'\t' 指定制表符为列之间的分隔符
    # 整体效果：将一列数据转换为多列对齐的表格输出
    printf "%s\n" "${formatted_items[@]}" | paste - $(printf -- '- %.0s' $(seq 1 $((cols - 1)))) | column -t -s $'\t'
}

# 过程函数：统一检查软件是否已安装的函数
# 返回0表示已安装，返回1表示未安装
check_if_installed() {
    local package_name="$1"
    
    # 检查常见的包管理器
    if dpkg -l | grep -q "^ii\s*$package_name"; then
        return 0
    fi
    
    if snap list 2>/dev/null | grep -q "^$package_name "; then
        return 0
    fi
    
    if flatpak list 2>/dev/null | grep -q "$package_name"; then
        return 0
    fi
    
    # 最后检查命令是否存在
    if command -v "$package_name" &> /dev/null; then
        return 0
    fi
    
    return 1
}

# 过程函数：统一获取软件版本的函数
get_package_version() {
    local package_name="$1"
    local version_command="$2"
    
    if [ -n "$version_command" ]; then
        # 如果提供了特定的版本命令，使用它
        eval "$version_command"
    else
        # 默认使用dpkg获取版本
        dpkg -l "$package_name" 2>/dev/null | grep "^ii" | awk '{print $3}'
    fi
}


# 主要安装和卸载函数开始
# 桌面系统增强必备
# 函数：安装 Plank 快捷启动器
function install_plank() {
    log 1 “检查是否已安装”
    if check_if_installed "plank"; then
        log 2 "Plank 已安装"
        return 0
    fi

    # 检查并安装依赖,把中文字体放到此处，省事
    local dependencies=("curl" "fonts-wqy-zenhei" "fonts-noto-cjk" "fonts-wqy-microhei" "xfonts-wqy")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装 Plank 失败"
        return 1
    fi

    # 安装 Plank
    if ! sudo apt install -y plank; then
        log 3 "安装 Plank 失败"
        return 1
    fi

    # 验证安装
    if ! check_if_installed "plank"; then
        log 3 "Plank 安装失败"
        return 1
    fi

    log 2 "Plank 快捷启动器安装完成"
}

# 函数：卸载 Plank 快捷启动器
function uninstall_plank() {

    log 1 “检查是否已安装”
    if ! check_if_installed "plank"; then
        log 2 "Plank 未安装"
        return 0
    fi

    # 卸载 Plank
    if ! sudo apt purge -y plank; then
        log 3 "卸载 Plank 失败"
        return 1
    fi

    log 2 "Plank 快捷启动器卸载完成"
}

# 函数：安装 angrysearch 类似everything的快速查找工具
function install_angrysearch() {
    # 检测是否已安装
    if check_if_installed "angrysearch"; then
        # 获取本地版本
        local_version="1.0.4"
        # local_version=$(dpkg -l | grep  "^ii\s*angrysearch" | awk '{print $3}')
        log 2 "angrysearch已安装，本地版本: $local_version"
        
        # 获取远程最新版本

        get_download_link "https://github.com/DoTheEvo/ANGRYsearch/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            # 如果远程本地版本包含远程版本，则说明是最新版本。例如本地1.0.4.1，远程1.0.4，说明已经是最新版
            # 例如本地是1.0.4.1，远程是1.0.5，说明是最新版本
            # 第壹次安装时，两者肯定时相同的，后面只有远程的版本号更新过，才会出现不一致。则只可能说明有新版了。
            log 2 "angrysearch 已经是最新版本，无需更新，返回主菜单"
            return 0
        fi
        log 1 "发现新版本，开始更新..."
    else
        log 2 "angrysearch未安装，开始下载"
        # LATEST_VERSION="v1.0.4"
    fi
    
    log 1 "获取远程最新版本下载链接..."
    get_assets_links "https://github.com/DoTheEvo/ANGRYsearch/releases"
    get_download_link "https://github.com/DoTheEvo/ANGRYsearch/releases"
    # 从LATEST_VERSION中提取版本号（去掉v前缀）
    remote_version=${LATEST_VERSION#v}
    log 1 "远程最新版本: $remote_version"
    log 1 "angrysearch github releases只提供源代码的压缩包，无法使用get_download_link函数获得最新版下载链接，手动设置远程最新版本下载链接"
    DOWNLOAD_URL="https://github.com/DoTheEvo/ANGRYsearch/archive/refs/tags/${LATEST_VERSION}.tar.gz"
    angrysearch_download_link=${DOWNLOAD_URL}
    log 1 "手动设置的远程最新版本下载链接: ${angrysearch_download_link}"
    

    # 下载并安装
    install_package ${angrysearch_download_link}
    if [ $? -eq 2 ]; then
        # 下面的目录来自函数install_package，程序都是下载到/tmp/downloads中
        cd /tmp/downloads
        
        extracted_dir=$(tar -tzf ${LATEST_VERSION}.tar.gz | head -1 | cut -f1 -d"/")
        log 1 "获取解压目录名: ${extracted_dir}"
        
        tar -zxvf "${ARCHIVE_FILE}"
        cd "${extracted_dir}"
        sudo ./install.sh
        
        # 验证安装结果
        if check_if_installed "angrysearch"; then
            log 2 "angrysearch 安装完成"
            return 0
        else
            log 3 "angrysearch 安装失败"
            return 1
        fi
    fi
    return 1
}

# 函数：卸载 angrysearch 类似everything的快速查找工具
function uninstall_angrysearch() {

    if ! check_if_installed "angrysearch"; then
        log 2 "检测到angrysearch未安装"
        return 0
    else
        log 1 "检测到angrysearch已安装，开始卸载"
    fi

    # 卸载 AngrySearch
    sudo rm -rfv $(find /usr -path "*angrysearch*")
    log 2 "angrysearch卸载完成"
}

# 函数：安装 Pot-desktop 翻译工具
function install_pot_desktop() {
   # 检测是否已安装
    if check_if_installed "pot"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*pot" | awk '{print $3}')
        log 1 "pot-desktop已安装，本地版本: $local_version"
    else
        log 1 "未找到pot-desktop，开始获得下载链接，请耐心等待"
    fi
    
    # 获取下载链接
    get_download_link "https://github.com/pot-app/pot-desktop/releases"
    # 从LATEST_VERSION中提取版本号（去掉v前缀）
    remote_version=${LATEST_VERSION#v}
    log 1 "远程最新版本: $remote_version"
        
    # 比较版本号，检查本地版本是否包含远程版本
    if [[ "$local_version" == *"$remote_version"* ]]; then
        log 1 "pot-desktop已经是最新版本，无需更新，返回主菜单"
        return 0
    else
        log 1 "发现新版本，开始更新..."
    fi
    
    # 检查并安装依赖
    local dependencies=("xapp" "libxapp1" "libxapp-gtk3-module")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装 pot-desktop 失败"
        return 1
    fi
    # 获取下载链接
    DOWNLOAD_URL=""
    get_download_link "https://github.com/pot-app/pot-desktop/releases" ".*amd64.*\.deb$"
    # .*：表示任意字符（除换行符外）出现零次或多次。
    # linux-x86-64：匹配字符串“linux-x86-64”。
    # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
    # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
    # $：表示字符串的结尾。
    pot_desktop_download_link=${DOWNLOAD_URL}
    install_package ${pot_desktop_download_link}

    # 验证安装结果
    if check_if_installed "pot"; then
        log 2 "pot-desktop 安装完成"
        return 0
    else
        log 3 "pot-desktop 安装失败"
        return 1
    fi
}

# 卸载pot-desktop的函数
function uninstall_pot_desktop() {
    log 1 “检查是否已安装”
    if ! check_if_installed "pot"; then
        log 1 "pot-desktop未安装"
        return 0
    fi

    # 获取实际的包名
    pkg_name=$(dpkg -l | grep -i pot | awk '{print $2}')
    if [ -z "$pkg_name" ]; then
        log 3 "未找到已安装的pot-desktop"
    fi

    log 1 "找到pot-desktop包名: ${pkg_name}"
    if sudo apt purge -y "$pkg_name"; then
        log 2 "pot-desktop卸载成功"
        # 清理依赖
        sudo apt autoremove -y
        return 0
    else
        log 3 "pot-desktop卸载失败"
        return 1
    fi
}

# 函数：安装 Geany 简洁清凉的文字编辑器
function install_geany() {
    log 1 “检查是否已安装”
    if check_if_installed "geany"; then
        log 1 "Geany已经安装"
        version=$(get_package_version "geany" "geany --version")
        log 1 "Geany版本: $version"
        return 0
    fi

    log 2 "开始安装geany..."
    
    # 更新软件包列表并安装geany
    log 1 "更新软件包列表并安装Geany..."
    sudo apt update
    if ! sudo apt install -y geany geany-plugins geany-plugin-markdown; then
        log 3 "安装geany失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "geany"; then
        version=$(get_package_version "geany" "geany --version")
        log 2 "Geany安装成功,版本是: $version"
        return 0
    else
        log 3 "Geany安装验证失败"
        return 1
    fi

    log 2 "Geany安装成功"
    return 0
}

# 函数：卸载 Geany 简洁清凉的文字编辑器
function uninstall_geany() {
    log 1 “检查是否已安装”
    if ! check_if_installed "geany"; then
        log 2 "Geany 未安装"
        return 0
    fi

    # 卸载 Geany
    if ! sudo apt purge -y geany geany-plugins geany-plugin-markdown; then
        log 3 "卸载 Geany 失败"
        return 1
    fi

    # 清理配置文件和依赖
    sudo apt purge -y geany geany-plugins geany-plugin-markdown
    sudo apt autoremove -y
    
    log 2 "Geany 卸载成功"
    return 0
}
# 函数：安装 stretchly 定时休息桌面
function install_stretchly() {
    # 检测是否已安装
    if check_if_installed "stretchly"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*stretchly" | awk '{print $3}')
        log 2 "stretchly已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/hovancik/stretchly/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 2 "stretchly 已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 2 "发现新版本，开始更新..."
            # 获取最新的下载链接,要先将之前保存的下载链接清空
            DOWNLOAD_URL=""
            get_download_link "https://github.com/hovancik/stretchly/releases" ".*amd64\.deb$"
            # .*：表示任意字符（除换行符外）出现零次或多次。
            # linux-x86-64：匹配字符串“linux-x86-64”。
            # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
            # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
            # $：表示字符串的结尾。
            stretchly_download_link=${DOWNLOAD_URL}
            install_package ${stretchly_download_link}
        fi
        return 0
    else
        # 获取最新的下载链接,要先将之前保存的下载链接清空
        log 1 "开始安装stretchly..."
        DOWNLOAD_URL=""
        get_download_link "https://github.com/hovancik/stretchly/releases" ".*amd64\.deb$"
        # .*：表示任意字符（除换行符外）出现零次或多次。
        # linux-x86-64：匹配字符串“linux-x86-64”。
        # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
        # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
        # $：表示字符串的结尾。
        stretchly_download_link=${DOWNLOAD_URL}
        install_package ${stretchly_download_link}
    fi
}

function uninstall_stretchly() {
    log 1 “检查是否已安装”
    if ! check_if_installed "stretchly"; then
        log 2 "stretchly未安装"
        return 0
    else
        log 1 "找到stretchly包名: ${stretchly}"
        log 1 "卸载stretchly..."
        sudo apt purge -y stretchly
        sudo apt-get autoremove -y
        sudo apt-get autoclean
        log 2 "stretchly卸载完成"
    fi

}

# 函数：安装和更新 ab-download-manager 下载工具
function install_ab_download_manager() {
    # 检查是否已经安装了ab-download-manager
    if check_if_installed "abdownloadmanager"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*abdownloadmanager" | awk '{print $3}')
        log 2 "ab-download-manager已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/amir1376/ab-download-manager/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 2 "ab-download-manager 已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 1 "发现新版本，开始更新..."
            # 检查必要的依赖
            local deps=("wget")
            if ! check_and_install_dependencies "${deps[@]}"; then
                log 3 "安装依赖失败，无法继续安装ab-download-manager"
                return 1
            fi

            # 获取最新的下载链接
            get_download_link "https://github.com/amir1376/ab-download-manager/releases" ".*linux_x64.*\.deb$"
            ab_download_manager_download_link=${DOWNLOAD_URL}
            install_package ${ab_download_manager_download_link}
        fi
        return 0
    fi
    
    log 1 "开始安装ab-download-manager..."
    
    # 检查必要的依赖
    local deps=("wget")
    if ! check_and_install_dependencies "${deps[@]}"; then
        log 3 "安装依赖失败，无法继续安装ab-download-manager"
        return 1
    fi

    # 获取最新的下载链接

    get_download_link "https://github.com/amir1376/ab-download-manager/releases" ".*linux_x64.*\.deb$"
    ab_download_manager_download_link=${DOWNLOAD_URL}
    install_package ${ab_download_manager_download_link}
}

# 函数：卸载 ab-download-manager 下载工具
function uninstall_ab_download_manager() {
    # 检查是否已经安装了ab-download-manager
    if ! check_if_installed "abdownloadmanager"; then
        log 2 "ab-download-manager未安装"
        return 0
    fi

    log 1 "检测到已安装ab-download-manager，开始卸载..."
    
    if ! sudo apt purge -y abdownloadmanager; then
        log 3 "卸载ab-download-manager失败"
        return 1
    fi
    
    # 清理配置文件和依赖
    sudo apt autoremove -y
    
    log 2 "ab-download-manager卸载成功"
    return 0
}

# 函数：安装和更新 localsend 局域网传输工具
function install_localsend() {
    # 检测是否已经安装了localsend
    if check_if_installed "localsend"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*localsend" | awk '{print $3}')
        log 2 "localsend已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/localsend/localsend/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 2 "localsend 已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 2 "发现新版本，开始更新..."
            DOWNLOAD_URL=""
            get_download_link "https://github.com/localsend/localsend/releases" ".*linux-x86-64.*\.deb$"            
            localsend_download_link=${DOWNLOAD_URL}
            install_package ${localsend_download_link}
        fi
        log 2 "localsend已经安装"
        return 0
    else
        # 获取最新的下载链接,要先将之前保存的下载链接清空
        DOWNLOAD_URL=""
        get_download_link "https://github.com/localsend/localsend/releases" ".*linux-x86-64.*\.deb$"
        # .*：表示任意字符（除换行符外）出现零次或多次。
        # linux-x86-64：匹配字符串“linux-x86-64”。
        # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
        # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
        # $：表示字符串的结尾。
        localsend_download_link=${DOWNLOAD_URL}
        install_package ${localsend_download_link}
        return 0
    fi
}

# 函数： 卸载 localsend 局域网传输工具
function uninstall_localsend() {
    # 检查是否已经安装了localsend
    if ! check_if_installed "localsend"; then
        log 2 "localsend未安装"
        return 0
    fi

    log 1 "开始卸载localsend..."
    sudo apt purge -y localsend
    if [ $? -ne 0 ]; then
        log 3 "卸载localsend失败"
        return 1
    fi
    log 2 "localsend卸载成功"
    return 0
}

# 函数：安装 SpaceFM 双面板文件管理器
function install_spacefm() {
    log 1 “检查是否已安装”
    if check_if_installed "spacefm"; then
        version=$(get_package_version "spacefm" "spacefm --version")
        log 2 "spacefm已经安装最新版本: $version , 返回主菜单"
        return 0
    fi

    log 1 "开始安装spacefm..."
    
    # 更新软件包列表并安装spacefm
    log 1 "更新软件包列表并安装spacefm..."
    sudo apt update
    if ! sudo apt install -y spacefm; then
        log 3 "安装spacefm失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "spacefm"; then
        version=$(get_package_version "spacefm" "spacefm --version")
        log 2 "spacefm安装成功, 版本是: $version"
        return 0
    else
        log 3 "spacefm安装验证失败"
        return 1
    fi

    log 2 "spacefm安装成功"
    return 0
}

# 函数：卸载 SpaceFM 双面板文件管理器
function uninstall_spacefm() {
    log 1 “检查是否已安装”
    if ! check_if_installed "spacefm"; then
        log 2 "spacefm未安装"
        return 0
    fi

    log 1 "开始卸载spacefm..."
    sudo apt purge -y spacefm
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载spacefm失败"
        return 1
    fi

    log 2 "spacefm卸载成功"
    return 0
}

# 函数：安装 Krusader 双面板文件管理器
function install_krusader() {
    log 1 "检查软件是否已安装"
    if check_if_installed "krusader"; then
        version=$(get_package_version "krusader" "krusader --version")
        log 2 "Krusader 已安装最新版本: $version , 返回主菜单"
        return 0
    fi
    
    # 更新软件包列表并安装 Krusader
    log 1 "更新软件包列表并安装 Krusader..."
    sudo apt update
    if ! sudo apt install -y krusader; then
        log 3 "安装 Krusader 失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "krusader"; then
        log 2 "Krusader 安装成功"
        return 0
    else
        log 3 "Krusader 安装验证失败"
        return 1
    fi
}

# 函数：卸载 Krusader 双面板文件管理器
function uninstall_krusader() {
    log 1 "开始检查软件卸载状态..."
    if ! check_if_installed "krusader"; then
        log 2 "Krusader 未安装"
        return 0
    fi
    
    # 卸载 Krusader
    log 1 "卸载 Krusader..."
    sudo apt purge -y krusader
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载 Krusader 失败"
        return 1
    fi
    
    log 2 "Krusader 卸载成功"
    return 0
}

# 函数：安装 Konsole KDE's Terminal Emulator
function install_konsole() {
    log 1 "开始检查软件安装状态..."
    if check_if_installed "konsole"; then
        version=$(get_package_version "konsole" "konsole --version")
        log 2 "Konsole已安装最新版本: $version , 返回主菜单"
        return 0
    fi
    
    # 更新软件包列表并安装 Konsole
    log 1 "更新软件包列表并安装 Konsole..."
    sudo apt update
    if ! sudo apt install -y konsole; then
        log 3 "安装 Konsole 失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "konsole"; then
        log 2 "Konsole 安装成功"
        return 0
    else
        log 3 "Konsole 安装验证失败"
        return 1
    fi
}

# 函数：卸载 Konsole KDE's Terminal Emulator
function uninstall_konsole() {
    log 1 "开始检查软件卸载状态..."
    if ! check_if_installed "konsole"; then
        log 2 "Konsole 未安装"
        return 0
    fi
    
    # 卸载 Konsole
    log 1 "卸载 Konsole..."
    sudo apt purge -y konsole
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载 Konsole 失败"
        return 1
    fi
    
    log 2 "Konsole 卸载成功"
    return 0
}


# 桌面系统进阶常用软件
# 函数：安装和更新 Tabby 可同步终端
function install_tabby() {
    # 检测是否已安装
    if check_if_installed "tabby"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*tabby" | awk '{print $3}')
        log 2 "Tabby已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/Eugeny/tabby/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 2 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 2 "tabby 已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 2 "发现新版本，开始下载安装..."
            # 获取最新的下载链接,要先将之前保存的下载链接清空
            DOWNLOAD_URL=""
            get_download_link "https://github.com/Eugeny/tabby/releases" ".*linux-x64.*\.deb$"
            # .*：表示任意字符（除换行符外）出现零次或多次。
            # linux-x86-64：匹配字符串“linux-x86-64”。
            # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
            # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
            # $：表示字符串的结尾。
            tabby_download_link=${DOWNLOAD_URL}
            install_package ${tabby_download_link}
        fi
        return 0
    else
        # 获取最新的下载链接,要先将之前保存的下载链接清空
        DOWNLOAD_URL=""
        get_download_link "https://github.com/Eugeny/tabby/releases" ".*linux-x64.*\.deb$"
        # .*：表示任意字符（除换行符外）出现零次或多次。
        # linux-x86-64：匹配字符串“linux-x86-64”。
        # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
        # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
        # $：表示字符串的结尾。
        tabby_download_link=${DOWNLOAD_URL}
        install_package ${tabby_download_link}
    fi
}

# 函数：卸载 Tabby 可同步终端
function uninstall_tabby() {
    # 检测是否已安装
    if ! check_if_installed "tabby-terminal"; then
        log 2 "Tabby未安装"
        return 0
    else
        log 1 "检测到已安装Tabby，开始卸载..."
        # 获取实际的包名
        pkg_name=$(dpkg -l | grep -i tabby | awk '{print $2}')
        if [ -z "$pkg_name" ]; then
            log 3 "未找到已安装的Tabby"
            return 1
        fi
        log 1 "找到Tabby包名: ${pkg_name}"
        if sudo apt purge -y "$pkg_name"; then
            log 2 "Tabby卸载成功"
            return 0
        else
            log 3 "Tabby卸载失败"
            return 1
        fi
    fi
}

# 函数：安装warp terminal
function install_warp_terminal() {
    log 1 "开始检查软件安装状态..."
    if check_if_installed "warp"; then
        version=$(dpkg -l | grep "^ii\s*warp" | awk '{print $3}')
        log 2 "warp terminal 已安装，版本是: $version , 返回主菜单"
        return 0
    fi
    
    log 1 "更新软件包列表并安装 warp..."
    local download_url=$(curl -s "https://app.warp.dev/download?package=deb" | grep -oP '<a href="\K[^"]*' | head -n 1)
    if ! install_package "$download_url"; then
        log 3 "安装 warp 失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "warp"; then
        log 2 "warp terminal 安装成功"
        return 0
    else
        log 3 "warp terminal 安装失败"
        return 1
    fi
}

# 函数：卸载warp terminal
function uninstall_warp_terminal() {
    log 1 "开始检查软件卸载状态..."
    if ! check_if_installed "warp"; then
        log 2 "warp terminal 未安装"
        return 0
    fi
    
    # 卸载 warp
    log 1 "检测到已安装warp terminal，开始卸载..."
    sudo apt purge -y warp
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载 warp terminal 失败"
        return 1
    fi
    
    log 2 "warp terminal 卸载成功"
    return 0
}

# 函数：安装 telegram 最好的聊天软件
function install_telegram() {
    log 1 "开始检查软件安装状态..."
    if check_if_installed "telegram-desktop"; then
        version=$(dpkg -l | grep "^ii\s*telegram-desktop" | awk '{print $3}')
        log 2 "Telegram 已安装，版本是: $version , 返回主菜单"
        return 0
    fi
    
    # 更新软件包列表并安装 Telegram
    log 1 "更新软件包列表并安装 Telegram..."
    sudo apt update
    if ! sudo apt install -y telegram-desktop; then
        log 3 "安装 Telegram 失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "telegram-desktop"; then
        log 2 "Telegram 安装成功"
        return 0
    else
        log 3 "Telegram 安装验证失败"
        return 1
    fi
}

# 函数：卸载 Telegram 最好的聊天软件
function uninstall_telegram() {
    log 1 "开始检查软件卸载状态..."
    if ! check_if_installed "telegram-desktop"; then
        log 2 "Telegram 未安装"
        return 0
    fi
    
    # 卸载 Telegram
    log 1 "检测到已安装Telegram，开始卸载..."
    sudo apt purge -y telegram-desktop
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载 Telegram 失败"
        return 1
    fi
    
    log 2 "Telegram 卸载成功"
    return 0
}


# 函数：安装 Brave 浏览器函数
function install_brave() {
    log 1 “检查是否已安装”
    if check_if_installed "brave-browser"; then
        version=$(get_package_version "brave-browser" "brave-browser --version")
        log 2 "Brave浏览器已安装, 版本是: $version"
        return 0
    fi
    
    log 1 "开始安装Brave浏览器..."
    
    # 检查必要的依赖
    local deps=("curl" "apt-transport-https" "software-properties-common")
    if ! check_and_install_dependencies "${deps[@]}"; then
        log 3 "安装依赖失败，无法继续安装Brave浏览器"
        return 1
    fi

    # 下载Brave GPG密钥
    log 1 "下载Brave GPG密钥..."
    if [ ! -d "/usr/share/keyrings" ]; then
        log 1 "创建 keyrings 目录..."
        sudo mkdir -p /usr/share/keyrings
    fi

    if ! curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null; then
        log 3 "下载Brave GPG密钥失败"
        log 3 "请检查网络连接或访问 https://brave.com/linux/ 获取最新安装指南"
        return 1
    fi

    # 验证GPG密钥权限
    log 1 "设置GPG密钥权限..."
    sudo chmod a+r /usr/share/keyrings/brave-browser-archive-keyring.gpg
    if [ $? -ne 0 ]; then
        log 3 "设置GPG密钥权限失败"
        return 1
    fi

    # 添加Brave软件源
    log 1 "添加Brave软件源..."
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
    if [ $? -ne 0 ]; then
        log 3 "添加Brave软件源失败"
        return 1
    fi

    # 更新软件包列表
    log 1 "更新软件包列表..."
    sudo apt update
    if [ $? -ne 0 ]; then
        log 3 "更新软件包列表失败"
        return 1
    fi

    # 安装Brave浏览器
    log 1 "安装Brave浏览器..."
    sudo apt install -y brave-browser
    if [ $? -ne 0 ]; then
        log 3 "安装Brave浏览器失败"
        log 3 "可能的原因："
        log 3 "1. 网络连接问题"
        log 3 "2. 软件源问题"
        log 3 "3. 依赖包问题"
        log 3 "解决方案："
        log 3 "1. 检查网络连接"
        log 3 "2. 运行 'sudo apt update' 确认软件源可用"
        log 3 "3. 查看 /var/log/apt/term.log 获取详细错误信息"
        return 1
    fi

    # 验证安装
    if check_if_installed "brave-browser"; then
        version=$(get_package_version "brave-browser" "brave-browser --version")
        log 2 "Brave浏览器安装成装, 版本: $version"
        return 0
    else
        log 3 "Brave浏览器安装验证失败"
        return 1
    fi
}

# 函数：卸载 Brave 浏览器的函数
function uninstall_brave() {
    log 1 “检查是否已安装”
    if ! check_if_installed "brave-browser"; then
        log 2 "Brave浏览器未安装"
        return 0
    fi

    # 卸载Brave浏览器
    log 1 "检测到已安装Brave浏览器，开始卸载..."
    sudo apt purge -y brave-browser
    if [ $? -ne 0 ]; then
        log 3 "卸载Brave浏览器失败"
        return 1
    fi

    # 删除软件源
    log 1 "删除Brave软件源..."
    sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list
    if [ $? -ne 0 ]; then
        log 3 "删除Brave软件源文件失败"
    fi

    # 删除GPG密钥
    log 1 "删除Brave GPG密钥..."
    sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
    if [ $? -ne 0 ]; then
        log 3 "删除Brave GPG密钥失败"
    fi

    # 清理不需要的依赖
    log 1 "清理不需要的依赖..."
    sudo apt autoremove -y
    
    log 2 "Brave浏览器卸载完成"
    return 0
}

# 函数：安装 VLC 视频播放器
function install_VLC() {
    # 检查是否已安装
    if check_if_installed "vlc"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*vlc" | awk '{print $3}')
        log 2 "VLC已安装，本地版本: $local_version"
        return 0    
    fi

    # 更新软件包列表并安装VLC
    log 1 "更新软件包列表并安装VLC..."
    sudo apt-get update && sudo apt-get install -y vlc
    if [ $? -ne 0 ]; then
        log 3 "安装VLC失败"
        return 1
    fi

    # 验证安装
    if check_if_installed "vlc"; then
        version=$(get_package_version "vlc" "vlc --version")
        log 2 "VLC安装成功,版本: $version"
        return 0
    else
        log 3 "VLC安装验证失败"
        return 1
    fi

    return 0
}

# 函数：卸载 VLC 视频播放器
function uninstall_VLC() {
    # 检查是否已安装
    if ! check_if_installed "vlc"; then
        log 2 "VLC未安装"
        return 0
    fi

    # 卸载VLC
    log 1 "检测到已安装VLC，开始卸载..."
    sudo apt purge -y vlc
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载VLC失败"
        return 1
    fi

    log 2 "VLC卸载成功"
    return 0
}

# 函数：安装 Windsurf IDE 编程工具
function install_windsurf() {
    log 1 “检查是否已安装Windsurf” 
    if check_if_installed "windsurf"; then
        version=$(get_package_version "windsurf" "windsurf --version")
        log 2 "Windsurf 已经安装, 版本: $version"
        return 0
    fi

    # 检查并安装必要的依赖
    local dependencies=("curl" "gnupg")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装依赖失败，无法继续安装 Windsurf"
        return 1
    fi

    # 下载并安装 Windsurf
    log 1 "正在安装 Windsurf..."
    
    # 添加Windsurf GPG密钥
    log 1 "下载Windsurf GPG密钥..."
    curl -fsSL "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | sudo gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
    
    # 添加Windsurf软件源
    log 1 "添加Windsurf源列表..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null
    
    # 更新软件包列表
    log 1 "更新软件包列表..."
    if ! sudo apt-get update; then
        log 3 "更新软件包列表失败"
        return 1
    fi

    # 安装Windsurf
    log 1 "正在安装Windsurf..."
    if ! sudo apt-get upgrade -y windsurf; then
        log 3 "安装Windsurf失败，请检查依赖关系"
        return 1
    fi

    # 检查安装是否成功
    if check_if_installed "windsurf"; then
        log 2 "Windsurf 安装成功"
        return 0
    else
        log 3 "Windsurf 安装失败，请查看日志获取详细信息"
        return 1
    fi

}

# 函数：卸载 Windsurf IDE 编程工具
function uninstall_windsurf() {
    # 检查是否已安装 
    if ! check_if_installed "windsurf"; then
        log 2 "Windsurf未安装"
        return 0
    fi
    
    log 1 "检测到已安装Windsurf，开始卸载..."
    if ! sudo apt purge -y windsurf; then
        log 3 "卸载Windsurf失败"
        return 1
    fi
    
    # 清理配置文件和依赖
    sudo apt autoremove -y
    
    # 删除仓库配置
    sudo rm -f /etc/apt/sources.list.d/windsurf.list
    sudo rm -f /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
    
    log 2 "Windsurf卸载成功"
    return 0
}

# 函数：pipx安装 PDF Arranger PDF页面编辑器
function install_pdfarranger() {
    log 1 "检查是否已安装"
    if check_if_installed "pdfarranger"; then
        version=$(get_package_version "pdfarranger" "pdfarranger --version")
        log 2 "pdfarranger 已安装, 版本: $version"
        return 0
    fi

    log 1 "开始安装pdfarranger的依赖..."
    sudo apt update
    sudo apt-get install -y python3-pip python3-wheel python3-gi python3-gi-cairo \
    gir1.2-gtk-3.0 gir1.2-poppler-0.18 gir1.2-handy-1 python3-setuptools \
    gir1.2-gdkpixbuf-2.0 pkg-config libcairo2-dev libgirepository1.0-dev
    if [ $? -ne 0 ]; then
        log 3 "安装pdfarrangerde的依赖失败"
        return 1
    fi
    log 1 "pdfarranger的依赖安装成功"
    
    log 1 "开始安装pdfarranger..."
    sudo apt install pipx
    pipx ensurepath
    pipx install https://github.com/pdfarranger/pdfarranger/zipball/main
    # pip3 install --user --upgrade https://github.com/pdfarranger/pdfarranger/zipball/main
    pipx inject pdfarranger pygobject
    if [ $? -ne 0 ]; then
        log 3 "安装pdfarranger失败"
        return 1
    fi
    log 2 "pdfarranger 安装成功"
    return 0
}

# 卸载：PDF Arranger PDF页面编辑器
function uninstall_pdfarranger() {
    # 检查是否已安装
    if ! check_if_installed "pdfarranger"; then
        log 2 "pdfarranger未安装"
        return 0
    fi

    log 1 "检测到已安装pdfarranger，开始卸载..."
    pipx uninstall pdfarranger
    if [ $? -ne 0 ]; then
        log 3 "卸载pdfarranger失败"
        return 1
    fi
    log 2 "pdfarranger卸载成功"
    return 0
}

# # 函数：安装 WPS Office
# function install_wps() {
#     # 检查是否已安装
#     if check_if_installed "wps-office"; then
#         log 2 "WPS Office 已安装"
#         return 0
#     fi

#     cd ~/Downloads
#     wget https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11664/wps-office_11.1.0.11664_amd64.deb
#     sudo dpkg -i wps-office_11.1.0.11664_amd64.deb
#     sudo apt-mark hold wps-office  # 阻止 WPS 自动更新
#     log 2 "WPS Office 安装完成。已阻止自动更新"
# }

# # 函数：卸载 WPS Office
# function uninstall_wps() {
#     log 1 “检查是否已安装”
#     if ! check_if_installed "wps-office"; then
#         log 1 "WPS Office 未安装"
#         return 0
#     fi

#     sudo apt-mark unhold wps-office
#     sudo apt purge -y wps-office
#     sudo apt autoremove -y
#     log 1 "WPS Office 卸载完成"
# }


# 命令行增强工具
# 函数：安装 neofetch 命令行系统信息工具
function install_neofetch() {
    log 1 "检查是否已安装"
    if check_if_installed "neofetch"; then
        log 2 "neofetch 已安装"
        return 0
    fi

    log 1 "开始安装neofetch..."
    sudo apt install -y neofetch
    if [ $? -ne 0 ]; then
        log 3 "安装neofetch失败"
        return 1
    fi
    log 2 "neofetch 安装成功"
    return 0
}

# 函数：卸载 neofetch 命令行系统信息工具
function uninstall_neofetch() {
    log 1 "检查是否已安装"
    if ! check_if_installed "neofetch"; then
        log 2 "neofetch未安装"
        return 0
    fi

    log 1 "开始卸载neofetch..."
    sudo apt purge -y neofetch
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "卸载neofetch失败"
        return 1
    fi
    log 2 "neofetch卸载成功"
    return 0
}

# 函数：安装 micro 命令行编辑器
function install_micro() {
    log 1 "检查是否已经安装了micro"
    if check_if_installed "micro"; then
        local local_version=$(micro --version 2>&1 | grep -oP 'Version: \K[0-9.]+' || echo "unknown")
        log 1 "micro已安装，本地版本: $local_version"
    else
        log 1 "未找到micro，开始获得下载链接，请耐心等待"
    fi

    get_download_link "https://github.com/zyedidia/micro/releases"
    remote_version=${LATEST_VERSION#v}
    log 1 "远程最新版本: $remote_version"

    if [[ "$local_version" == *"$remote_version"* ]]; then
        log 1 "micro 已经是最新版本，无需更新，返回主菜单"
        return 0
    else
        log 1 "发现新版本，开始更新..."
    fi

    local install_dir="/tmp/micro_install"
    rm -rf "$install_dir" && mkdir -p "$install_dir"
    DOWNLOAD_URL=""
    get_download_link "https://github.com/zyedidia/micro/releases" .*linux64\.tar\.gz$ 
    micro_download_link=${DOWNLOAD_URL}

    log 1 "下载链接: ${micro_download_link}"
    
    install_package ${micro_download_link}
    
    if [ $? -eq 2 ]; then
        log 2 "下载文件 ${ARCHIVE_FILE} 是压缩包"
        log 1 "解压并安装"
        
        if [ ! -f "${ARCHIVE_FILE}" ]; then
            log 3 "压缩包文件 ${ARCHIVE_FILE} 不存在"
            return 1
        fi

        log 1 "开始解压 ${ARCHIVE_FILE}..."
        if ! tar -vxzf "${ARCHIVE_FILE}" -C "$install_dir" 2>&1; then
            log 3 "解压失败，可能是文件损坏或格式不正确"
            return 1
        fi

        # 找到最深层的micro-*目录
        deepest_dir=$(find "$install_dir" -type d -name "micro-*" | sort | tail -n 1)
        if [ -z "$deepest_dir" ]; then
            log 3 "未找到micro程序目录"
            return 1
        fi
        log 1 "解压完成，找到程序目录: $deepest_dir"
        # 删除旧文件
        sudo rm -rf /usr/local/bin/micro
        # sudo mkdir -p /usr/local/bin/micro

        # 复制所有文件到目标目录
        if ! sudo cp -r "$deepest_dir"/micro /usr/local/bin/; then
            log 3 "复制文件到 /usr/local/bin/micro 失败"
            return 1
        fi
        log 1 "移动目录到 /usr/local/bin 成功！"

        # 添加环境变量
        echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
        echo 'export PATH=$PATH:/usr/local/bin' >> ~/.zshrc

        log 1 "添加环境变量成功！ 根据当前shell类型source对应的配置文件"
        if [ -n "$BASH_VERSION" ]; then
            log 1 "当前是bash, 执行source ~/.bashrc"
            source $HOME/.bashrc
        elif [ -n "$ZSH_VERSION" ]; then
            log 1 "当前是zsh,source ~/.zshrc"
            source ~/.zshrc
        fi

        rm -rf "$install_dir" "${ARCHIVE_FILE}"

        if check_if_installed "micro"; then
            log 1 "micro 编辑器安装成功！"
            micro --version
        else
            log 3 "micro 编辑器安装失败。"
            return 1
        fi
    fi
}

# 函数：卸载 micro 命令行编辑器
function uninstall_micro() {
    # 检查是否已安装
    if ! check_if_installed "micro"; then
        log 1 "micro 未安装，返回主菜单"
        return 0
    fi

    log 1 "检测到micro已安装，开始卸载..."
    if [ -f /usr/local/bin/micro ]; then
        log 1 "删除 micro 成功..."
        if sudo rm -f /usr/local/bin/micro; then
            log 1 "成功删除 micro 可执行文件"
        else
            log 3 "删除 micro 可执行文件失败"
            return 1
        fi
    else
        log 1 "未找到 micro 可执行文件，可能已被删除"
    fi

    # 删除micro的环境变量，由于安装时加入的是export PATH=$PATH:/usr/local/bin'
    # 因此只需要删除export PATH=$PATH:/usr/local/bin，下面的代码不起作用，以后再处理吧
    log 1 "清理环境变量配置..."
    if grep -q 'micro' ~/.bashrc; then
        if sed -i '/micro/d' ~/.bashrc; then
            log 1 "成功从 .bashrc 中移除 micro 环境变量"
        else
            log 3 "从 .bashrc 移除环境变量失败"
        fi
    fi
    
    if grep -q 'micro' ~/.zshrc; then
        if sed -i '/micro/d' ~/.zshrc; then
            log 1 "成功从 .zshrc 中移除 micro 环境变量"
        else
            log 3 "从 .zshrc 移除环境变量失败"
        fi
    fi

    log 1 "micro 编辑器卸载完成"
}

# 函数：pipx安装 cheat.sh 命令行命令示例工具
function install_cheatsh() {
  # 检查并安装依赖
  local dependencies=("rlwrap" "curl")
  if ! check_and_install_dependencies "${dependencies[@]}"; then
      log 3 "安装依赖失败"
      return 1
  fi

  log 1 “检查是否已安装”
  if check_if_installed "cht.sh"; then
      log 1 "cheat.sh 已安装"
      return 0
  fi

  # 确保目标目录存在
  mkdir -p ~/.local/bin

  # 安装主程序
  if ! curl -Ls https://cht.sh/:cht.sh > ~/.local/bin/cht.sh || ! chmod +x ~/.local/bin/cht.sh; then
      log 3 "下载或安装 cht.sh 失败"
      rm -f ~/.local/bin/cht.sh
      return 1
  fi

  # 检查并添加 ~/.local/bin 到 PATH
  if ! echo $PATH | grep -q "$HOME/.local/bin"; then
      # 添加到 .bashrc
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
      # 添加到 .zshrc（如果存在）
      if [ -f ~/.zshrc ]; then
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
      fi
      # 立即更新当前会话的 PATH
      export PATH="$HOME/.local/bin:$PATH"
  fi

  # 验证主程序安装
  if ! check_if_installed "cht.sh"; then
      log 3 "cht.sh 安装失败"
      rm -f ~/.local/bin/cht.sh
      return 1
  fi

  # 验证主程序是否可执行
  if ! cht.sh --help &>/dev/null; then
      log 3 "cht.sh 执行测试失败"
      rm -f ~/.local/bin/cht.sh
      return 1
  fi

  # 创建目录
  if ! mkdir -p ~/.bash.d || ! mkdir -p ~/.zsh.d; then
      log 3 "创建补全目录失败"
      rm -f ~/.local/bin/cht.sh
      return 1
  fi

  # 设置 Bash 补全
  if ! curl -s --retry 3 --retry-delay 2 https://cheat.sh/:bash_completion > ~/.bash.d/cht.sh; then
      log 3 "下载 Bash 补全脚本失败"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh
      return 1
  fi
  
  if ! chmod +x ~/.bash.d/cht.sh; then
      log 3 "设置 Bash 补全脚本权限失败"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh
      return 1
  fi

  # 验证 Bash 补全文件
  if [ ! -s ~/.bash.d/cht.sh ] || ! grep -q "complete.*cht.sh" ~/.bash.d/cht.sh; then
      log 3 "Bash 补全脚本内容无效"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh
      return 1
  fi

  # 检查并创建 .bashrc
  touch ~/.bashrc 2>/dev/null || true
  if [ ! -f ~/.bashrc ]; then
      log 3 ".bashrc 文件不存在且无法创建"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh
      return 1
  fi

  if ! grep -q ". ~/.bash.d/cht.sh" ~/.bashrc; then
      if ! echo ". ~/.bash.d/cht.sh" >> ~/.bashrc; then
          log 3 "添加 Bash 补全配置到 .bashrc 失败"
          rm -f ~/.local/bin/cht.sh
          rm -rf ~/.bash.d/cht.sh
          return 1
      fi
  fi

  # 设置 ZSH 补全
  if ! curl -s https://cheat.sh/:zsh > ~/.zsh.d/_cht; then
      log 3 "下载 ZSH 补全脚本失败"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh ~/.zsh.d/_cht
      return 1
  fi

  if ! chmod +x ~/.zsh.d/_cht; then
      log 3 "设置 ZSH 补全脚本权限失败"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh ~/.zsh.d/_cht
      return 1
  fi

  # 验证 ZSH 补全文件
  if [ ! -s ~/.zsh.d/_cht ] || ! grep -q "#compdef.*cht.sh" ~/.zsh.d/_cht; then
      log 3 "ZSH 补全脚本内容无效"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh ~/.zsh.d/_cht
      return 1
  fi

  # 检查并创建 .zshrc
  touch ~/.zshrc 2>/dev/null || true
  if [ ! -f ~/.zshrc ]; then
      log 3 ".zshrc 文件不存在且无法创建"
      rm -f ~/.local/bin/cht.sh
      rm -rf ~/.bash.d/cht.sh ~/.zsh.d/_cht
      return 1
  fi

  if ! grep -q "fpath=(~/.zsh.d/ \$fpath)" ~/.zshrc; then
      if ! echo 'fpath=(~/.zsh.d/ $fpath)' >> ~/.zshrc; then
          log 3 "添加 ZSH 补全配置到 .zshrc 失败"
          rm -f ~/.local/bin/cht.sh
          rm -rf ~/.bash.d/cht.sh ~/.zsh.d/_cht
          return 1
      fi
  fi

  log 1 "cheat.sh 安装完成，包括 Bash 和 ZSH 的 Tab 补全功能"
  log 1 "请重新打开终端或执行 'source ~/.bashrc'（Bash）或 'source ~/.zshrc'（ZSH）以启用补全功能"
  log 1 "使用方法：cht.sh 命令 (例如 cht.sh curl)"
  return 0
}

# 函数：卸载 cheat.sh 命令行命令示例工具
function uninstall_cheatsh() {
  log 1 "检查是否已安装"
  if ! check_if_installed "cht.sh"; then
      log 1 "cheat.sh 未安装"
      return 0
  fi

  log 1 "卸载 cheat.sh..."
  # 删除主程序
  if ! rm ~/.local/bin/cht.sh; then
      log 3 "删除 cheat.sh 主程序失败"
      return 1
  fi
  log 1 "已删除 cheat.sh 主程序"
  log 1 "正在删除补全..."
  # 删除 Bash 补全
  if [ -f ~/.bash.d/cht.sh ]; then
      if ! rm ~/.bash.d/cht.sh; then
          log 3 "删除 Bash 补全失败"
          return 1
      fi
  fi
  
  # 从 .bashrc 中删除 cht.sh 相关配置
  if [ -f ~/.bashrc ]; then
      sed -i '/\. ~\/\.bash\.d\/cht\.sh/d' ~/.bashrc
  fi
  
  # 删除 ZSH 补全
  if [ -f ~/.zsh.d/_cht ]; then
      if ! rm ~/.zsh.d/_cht; then
          log 3 "删除 ZSH 补全失败"
          return 1
      fi
  fi

  log 1 "cheat.sh 卸载成功"
  return 0
}

# 函数：pipx安装 eg 命令行命令示例工具
function install_eg() {
  log 1 “检查是否已安装”
  if check_if_installed "eg"; then
      log 1 "eg 已安装"
      return 0
  fi

  log 1 "检测eg未安装，准备安装依赖..."
  local dependencies=("python3-full" "python3-pip" "pipx") 
  if ! check_and_install_dependencies "${dependencies[@]}"; then
      log 3 "安装依赖失败"
      return 1
  fi

  log 1 "开始安装eg..."
  pipx install eg
  log 1 "eg 安装完成。使用方法：eg 命令 (例如 eg curl)"
}

# 函数：卸载 eg 命令行命令示例工具
function uninstall_eg() {
    log 1 "检查是否已安装eg "
    if ! check_if_installed "eg"; then
        log 1 "eg 未安装, 无需卸载, 返回菜单"
        return 0
    fi

    log 1 "检测到已安装eg，开始卸载..."
    if ! pipx uninstall eg; then
        log 3 "卸载 eg 失败"
        return 1
    fi
    log 1 "eg 卸载成功"

    return 0
}

# 函数：安装 eggs 命令行系统备份
function install_eggs() {
    log 1 "检查是否已安装"
    if check_if_installed "eggs"; then
        log 1 "eggs 已安装"
        return 0
    fi

    log 1 "检测到未安装eggs，准备git clone安装代码到$HOME/Downloads/eggs_install目录来安装开始安装 eggs..."
    # 检查并安装依赖
    local dependencies=("squashfs-tools" "xorriso" "grub-pc-bin" "grub-efi-amd64-bin" "mtools")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装依赖失败"
        return 1
    fi


    log 1 "准备$HOME/Downloads/eggs_install文件夹来接收clone后的代码"
    local install_dir="$HOME/Downloads/eggs_install"
    if [ -d "$install_dir" ]; then
        rm -rf "$install_dir"
    fi
    mkdir -p "$install_dir" || { log 3 "无法创建目录 $install_dir"; return 1; }

    log 1 "开始git clone安装"
    for i in {1..3}; do
        git clone https://github.com/pieroproietti/get-eggs "$install_dir" && break || echo "Attempt $i failed. Retrying..." && sleep 5
    done

    # 检查 git clone 是否成功
    if [ ! -d "$install_dir/.git" ]; then
        log 3 "下载失败，无法找到 git 目录"
        return 1
    fi
    log 1 "git clone 完成"

    # 进入安装目录
    cd "$install_dir" || { log 3 "无法进入目录 $install_dir"; return 1; }
    log 2 "替换安装代码中的ppa.sh文件，加入对sparky7.5的支持，即在is_debian函数中添加orion-belt字符串"
    sed -i 's/        trixie | excalibur | noble )/        trixie | excalibur | noble | orion-belt )/' ppa.sh
    if ! sudo ./get-eggs.sh; then
        log 3 "eggs 安装失败"
        return 1
    fi

    log 1 "eggs 安装完成，还需要更改eggs的配置文件"
    sudo sed -i '/# bookworm derivated/a - id: sparky\n  distroLike: Debian\n  family: debian\n  ids:\n    - orion-belt # SparkyLinux 7' /usr/lib/penguins-eggs/conf/derivatives.yaml
    sudo eggs dad -d
    return 0
}

# 函数：卸载 eggs 命令行系统备份
function uninstall_eggs() {
    log 1 "检查是否已安装"
    if ! check_if_installed "eggs"; then
        log 1 "eggs 未安装"
        return 0
    fi

    # 卸载 eggs
    log 1 "开始卸载 eggs..."
    if ! sudo apt purge -y penguins-eggs; then
        log 3 "卸载 eggs 失败"
        return 1
    fi

    sudo rm -rf /etc/apt/sources.list.d/penguins-eggs-ppa.list
    sudo rm -rf /usr/share/keyrings/penguins-eggs-ppa.gpg
    log 1 "eggs 卸载完成，并删除软件库配置"
    return 0
}

# 函数：pipx安装 v2rayA 网络代理设置
# function install_v2raya() {
#     read -p "请选择安装方法 (1: 使用脚本, 2: 使用软件源): " method
#     case $method in
#         1)
#             # 检查并安装依赖
#             local dependencies=("curl")
#             if ! check_and_install_dependencies "${dependencies[@]}"; then
#                 log 3 "安装依赖失败"
#                 return 1
#             fi

#             curl -Ls https://mirrors.v2raya.org/go.sh | sudo bash
#             sudo systemctl disable v2ray --now
#             log 1 "v2rayA (脚本安装) 完成。systemd 服务已禁用"
#             ;;
#         2)
#             # 检查并安装依赖
#             local dependencies=("wget")
#             if ! check_and_install_dependencies "${dependencies[@]}"; then
#                 log 3 "安装依赖失败"
#                 return 1
#             fi

#             wget -qO - https://apt.v2raya.org/key/public-key.asc | sudo tee /etc/apt/trusted.gpg.d/v2raya.asc
#             echo "deb https://apt.v2raya.org/ v2raya main" | sudo tee /etc/apt/sources.list.d/v2raya.list
#             apt update && apt install -y v2raya
#             log 1 "v2rayA (软件源安装) 完成"
#             ;;
#         *) 
#             log 3 "无效的选项"
#             return 1
#             ;;
#     esac
# }

# # 函数：卸载 v2rayA 网络代理设置
# # function uninstall_v2rayA() {
    
# # }


## 添加各种软件库
# 函数：安装 snap和snapstore 软件库
function install_snap() {
    log 1 "检查 snap和snapstore 是否已安装"
    if check_if_installed "snap"; then
        log 2 "snapd已安装,版本是：\n$(snap --version)"
        return 0
    fi

    log 2 "检测到未安装snap软件库，开始安装..."
    sudo apt install -y snapd
    log 2 "snap 安装完成"

    # 更新 snap 路径 (对于某些发行版可能需要)
    sudo systemctl restart snapd.socket
    sudo systemctl enable snapd.socket
    # 等待 snapd 启动完成 (可选，但可以提高稳定性)
    sleep 5
  
    log 1 "检查 snap-store 是否已安装"
    if check_if_installed "snap-store"; then
        log 2 "snap-store 已安装"
    else
        log 2 "检测到未安装snap-store，开始安装..."
        sudo snap install snap-store
        log 2 "snap-store 安装完成"
    fi

    return 0
}

# 函数：卸载 snap 软件库
function uninstall_snap() {
    log 1 "检查 snap 是否已安装"
    if ! check_if_installed "snap"; then
        log 2 "snapstore 未安装"
        return 0
    fi

    log 2 "检测到已安装snap ，开始卸载..."
    sudo snap remove snap-store
    log 2 "snapstore 卸载完成"

    sudo apt purge -y snapd
    log 2 "snap 卸载完成"
    return 0
}

# 函数：pipx安装 Flatpak 软件库
function install_flatpak() {
    log 1 "检查 Flatpak 是否已安装..."

    if check_if_installed "flatpak"; then
        log 2 "检测到Flatpak已经安装，版本是$(flatpak --version)"
        return 0
    fi

    # 安装Flatpak
    log 1 "检测到未安装Flatpak，开始安装..."
    if ! sudo apt install -y flatpak; then
        log 3 "安装Flatpak失败，请检查网络连接和软件源"
        return 1
    fi

    # 检测桌面环境并安装对应插件
    desktop_env=$(echo "$DESKTOP_SESSION" | awk -F/ '{print $1}')
    log 1 "检测到桌面环境: $desktop_env"

    if [[ "$desktop_env" == "gnome" ]]; then
        log 1 "安装GNOME Software Flatpak插件..."
        if ! sudo apt install -y gnome-software-plugin-flatpak; then
            log 3 "安装GNOME Flatpak插件失败，Flatpak功能可能受限"
        fi
    elif [[ "$desktop_env" == "kde-plasma" ]]; then
        log 1 "安装KDE Plasma Discover Flatpak后端..."
        if ! sudo apt install -y plasma-discover-backend-flatpak; then
            log 3 "安装KDE Plasma Flatpak后端失败，Flatpak功能可能受限"
        fi
    elif [[ "$desktop_env" == "cinnamon" ]]; then
        log 1 "Cinnamon 环境下 Mintinstall 已内置 Flatpak 支持，无需额外安装插件。"
    else
        log 3 "未安装特定的Flatpak插件，您可能需要手动配置Flatpak 或使用命令行安装。"
    fi

    # 添加Flathub仓库
    log 1 "添加Flathub仓库..."
    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        log 3 "添加Flathub仓库失败，请检查网络连接"
        return 1
    fi

    log 2 "Flatpak安装完成，您需要重启系统以使更改生效"
    return 0
}

# 函数：卸载 Flatpak 软件库
function uninstall_flatpak() {
    log 1 "检查 flatpak 是否已安装"
    if ! check_if_installed "flatpak"; then
        log 2 "Flatpak未安装"
        return 0
    fi

    # 首先卸载所有已安装的Flatpak应用
    log 1 "检测到已安装Flatpak，首先卸载所有Flatpak应用..."
    flatpak uninstall --all || log 2 "没有找到已安装的Flatpak应用"

    # 移除所有远程仓库
    log 1 "移除所有Flatpak仓库..."
    # Get a list of remotes, excluding the header line
    localremotes=$(flatpak remotes | tail -n +2 | awk '{print $1}')

    # Loop through each remote and delete it
    for remote in $remotes; do
    echo "Deleting remote: $remote"
    flatpak remote-delete --force "$remote"
    done

    log "All remotes deleted." 

    # 卸载Flatpak和相关插件
    log 1 "卸载Flatpak及相关插件..."
    if ! sudo apt purge -y flatpak gnome-software-plugin-flatpak plasma-discover-backend-flatpak; then
        log 3 "卸载Flatpak失败"
        return 1
    fi

    # 清理配置文件和依赖
    log 1 "清理Flatpak配置和依赖..."
    sudo apt purge -y flatpak
    sudo apt autoremove -y

    # 清理Flatpak数据目录
    log 1 "清理Flatpak数据目录..."
    sudo rm -rf /var/lib/flatpak
    rm -rf ~/.local/share/flatpak
    rm -rf ~/.cache/flatpak

    log 2 "Flatpak完全卸载成功"
    return 0
}

# 函数：pipx安装 Homebrew 
function install_homebrew() {
    install_common_dependencies
    # Check if Homebrew is already installed
    if check_if_installed "brew"; then
        log 1 "Homebrew 已经安装"

        return 0
    fi

    # Install Homebrew
    log 1 "正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Check installation status
    if [ $? -eq 0 ]; then
        # Configure Homebrew path for different shells
        log 1 "Homebrew 安装成功。正在配置环境..."
        
        # Add Homebrew to PATH for bash
        if [ -f ~/.bashrc ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
        fi
        
        # Add Homebrew to PATH for zsh
        if [ -f ~/.zshrc ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc
        fi
        
        # Reload shell environment
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        
        log 1 "Homebrew 安装并配置完成"
    else
        log 3 "Homebrew 安装失败。请检查网络连接和系统权限"
        return 1
    fi
}

# 函数：卸载 Homebrew 
function uninstall_homebrew() {
    if check_if_installed "brew"; then
        log 1 "正在卸载 Homebrew..."
        if ! /home/linuxbrew/.linuxbrew/bin/brew uninstall; then
            log 3 "Homebrew 卸载失败"
            return 1
        fi
        log 1 "Homebrew 卸载成功"
    else
        log 1 "Homebrew 未安装"
    fi
}

# 函数：pipx安装 docker和docker-compose 虚拟化平台
function install_docker_and_docker_compose() {
    log 1 "检查是否已安装Docker和Docker Compose"
    if check_if_installed "docker-ce"; then
        version=$(get_package_version "docker-ce" "docker --version")
        log 2 "检测到Docerk已安装，Docker版本: $version"
        compose_version=$(get_package_version "docker-compose-plugin" "docker compose version")
        log 2 "检测到Docker Compose版本: $compose_version"
        return 0
    fi

    log 2 "检测到未安装Docker和Docker Compose，开始安装..."
    # 检查必要的依赖
    local deps=("apt-transport-https" "ca-certificates" "curl" "gnupg" "lsb-release")
    if ! check_and_install_dependencies "${deps[@]}"; then
        log 3 "安装依赖失败，无法继续安装Docker和Docker Compose"
        return 1
    fi

    # 添加Docker的GPG密钥
    log 1 "添加Docker的GPG密钥"
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    if [ $? -ne 0 ]; then
        log 3 "添加Docker GPG密钥失败"
        return 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # 设置Docker存储库
    log 1 "设置Docker存储库"
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        log 1 "删除旧的docker.list文件"
        sudo rm /etc/apt/sources.list.d/docker.list
    fi

    # 获取系统版本代号，直接写死算了，只管基于bookworm的系统
    # if [ -f /etc/os-release ]; then
    #     . /etc/os-release
    #     codename=$DEBIAN_CODENAME
    #     log 1 "检测到系统版本代号: $codename"
    # else
    #     log 3 "无法检测系统版本"
    #     return 1
    # fi
    local codename="bookworm"

    # 添加Docker存储库
    echo \
    "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    if [ $? -ne 0 ]; then
        log 3 "添加Docker存储库失败"
        return 1
    fi

    # 安装Docker
    log 1 "开始安装Docker和Docker Compose"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    if [ $? -ne 0 ]; then
        log 3 "Docker安装失败"
        return 1
    fi
    log 1 "Docker和Docker Compose安装完成"

    # 配置用户权限
    log 1 "配置用户权限"
    sudo usermod -aG docker $USER
    if [ $? -ne 0 ]; then
        log 3 "添加用户到docker组失败"
    fi

    # 启动Docker服务
    log 1 "启动Docker服务"
    sudo systemctl start docker
    sudo systemctl enable docker
    if [ $? -ne 0 ]; then
        log 3 "Docker服务启动失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "docker-ce"; then
        log 2 "Docker安装和配置全部完成"
        version=$(get_package_version "docker-ce" "docker --version")
        log 1 "Docker版本: $version"
        compose_version=$(get_package_version "docker-compose-plugin" "docker compose version")
        log 1 "Docker Compose版本: $compose_version"
        return 0
    else
        log 3 "Docker安装验证失败"
        return 1
    fi
}

# 函数：卸载 docker和docker-compose 虚拟化平台
function uninstall_docker_and_docker_compose() {
    log 1 "检查是否已安装Docker"
    if ! check_if_installed "docker-ce"; then
        log 2 "Docker未安装"
        return 0
    fi

    log 21 "检测到安装Docker，开始卸载..."
    if check_if_installed "docker"; then
        log 1 "停止所有运行的容器"
        docker stop $(docker ps -aq) 2>/dev/null
        
        # 删除所有容器
        log 1 "删除所有容器"
        docker rm $(docker ps -aq) 2>/dev/null
        
        # 删除所有镜像
        log 1 "删除所有Docker镜像"
        docker rmi $(docker images -q) 2>/dev/null
    fi

    # 卸载Docker包
    log 1 "卸载Docker包"
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo apt-get autoremove -y
    if [ $? -ne 0 ]; then
        log 3 "Docker包卸载失败"
        return 1
    fi

    # 删除Docker数据目录
    log 1 "删除Docker数据目录"
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    
    log 1 "Docker卸载完成"
    return 0
}



# 生成菜单函数，用于显示菜单
# 每个菜单项都是一个函数，添加合适的分类
# 安装和卸载分开
show_menu() {
    desktop_enhance=(
        "01. Plank 快捷启动器"
        "02. angrysearch 类似everything的快速查找工具"
        "03. Pot-desktop 翻译工具"
        "04. Geany 简洁清凉的文字编辑器"
        "05. stretchly 定时休息设置"
        "06. AB Download Manager下载工具"
        "07. LocalSend 局域网传输工具"
        "08. SpaceFM 双面板文件管理器"
        "09. Krusader 双面板文件管理器"
        "10. Konsole KDE's Terminal Emulator"
    )

    command_enhance=(
        "20. Tabby 终端"
        "21. telegram 聊天软件 "
        "22. Brave 浏览器"
        "23. VLC 视频播放器 apt"
        "24. Windsurf IDE 最新编程工具"
        "25. PDF Arranger PDF页面编辑器"
    )

   cli_enhance=(
        "30. Neofetch 获取系统信息 "
        "31. micro 命令行编辑器"
        "32. cheat.sh 输出简洁命令示例 "
        "33. eg 命令行命令示例"
        "34. eggs 命令行系统备份"
        "35. 按两次Esc键命令前加sudo"
    ) 

    software_library=(
        "40. Docker  和 Docker Compose"
        "41. Snap 和 Snapstore 软件库"
        "42. Flatpak 软件库"
        "43. 三种字体JetBrains Mono等宽、Cascadia Code等宽和Source Han Mono中日韩等宽字体"
    )

    # uninstall_software=(
    #     '50. 卸载 Plank 快捷启动器'
    #     '51. 卸载 angrysearch 快速查找工具'
    #     '52. 卸载 Pot-desktop 翻译工具'
    #     '53. 卸载 Geany 简洁清凉的文字编辑器'
    #     '54. 卸载 stretchly 定时休息设置'
    #     '55. 卸载 AB Download Manager下载工具'
    #     '56. 卸载 LocalSend 局域网传输工具'
    #     '57. 卸载 SpaceFM 双面板文件管理器'
    #     '58. 卸载 Krusader 双面板文件管理器'
    #     "59. 卸载 Konsole KDE's Terminal Emulator"
    #     "--------------------------------"
    #     "--------------------------------"
    #     '61. 卸载 Tabby 终端'
    #     '62. 卸载 telegram 聊天软件 '
    #     '63. 卸载 Brave 浏览器'
    #     '64. 卸载 VLC 视频播放器 apt'
    #     '65. 卸载 Windsurf IDE 编程工具'
    #     '66. 卸载 PDF Arranger PDF页面编辑器'
    #     "--------------------------------"
    #     "--------------------------------"
    #     '70. 卸载Neofetch 命令行获取系统信息'
    #     '71. 卸载 micro 命令行编辑器'
    #     '72. 卸载 cheat.sh  命令行命令示例'
    #     '73. 卸载 eg 命令行命令示例'
    #     '74. 卸载 eggs 命令行系统备份'
    #     "75. 卸载 按两次Esc键命令前加sudo"
    #     "--------------------------------"
    #     "--------------------------------"
    #     '80. 卸载 Docker 和 Docker Compose'
    #     '81. 卸载 Snap 和 Snapstore 软件库'
    #     '82. 卸载 Flatpak 软件库'
    #     "..............................."
    # )

    green "==================================="
    green "Linux软件一键安装脚本"
    green "Github: https://github.com/cogitate3/setupSparkyLinux"
    green "当前脚本在Sparky7.5检测通过"
    green "安装日志记录在${CURRENT_LOG_FILE}文件中"
    green "==================================="

    yellow "~~~~~~~~~~~~~~~~~安装单选直接输入序号，卸载单选输入序号+100~~~~~~~~~~~~~~~~~~~"
    yellow "~~~~~~~~~~~~~~~~~比如安装Plank输入01，卸载Plank输入101~~~~~~~~~~~~~~~~~~~~~~"
    yellow "桌面系统增强必备:"
    display_items 2 "${desktop_enhance[@]}"
    yellow "19. 安装全部1-10软件           119. 卸载全部1-10软件"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    yellow "桌面系统进阶常用软件:"
    display_items 2 "${command_enhance[@]}"
    yellow "29. 安装全部20-25软件          129. 卸载全部20-25软件"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    yellow "命令行增强工具:"
    display_items 2 "${cli_enhance[@]}"
    yellow "39. 安装全部30-35软件          139. 卸载全部30-35软件"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    yellow "软件库工具:"
    display_items 2 "${software_library[@]}"
    yellow "49. 安装全部40-42软件          149. 卸载全部40-42软件"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    yellow "0. 退出脚本"

}

##
# 新的：处理菜单选择
handle_menu() {
    local choice
    read -p "请输入选项编号: " choice
    
    # 定义所有软件类别的安装函数和名称映射
    declare -A desktop_basic=(
        ["install_plank"]="plank"
        ["install_angrysearch"]="angrysearch"
        ["install_pot_desktop"]="Pot-desktop"
        ["install_geany"]="geany"
        ["install_stretchly"]="stretchly"
        ["install_ab_download_manager"]="ab-download-manager"
        ["install_localsend"]="localsend"
        ["install_spacefm"]="spacefm"
        ["install_krusader"]="krusader"
        ["install_konsole"]="konsole"
    )
    
    declare -A desktop_advanced=(
        ["install_tabby"]="tabby"
        ["install_telegram"]="telegram"
        ["install_brave"]="brave"
        ["install_VLC"]="vlc"
        ["install_windsurf"]="windsurf"
        ["install_pdfarranger"]="pdfarranger"
    )
    
    declare -A cli_tools=(
        ["install_neofetch"]="neofetch"
        ["install_micro"]="micro"
        ["install_cheatsh"]="cheatsh"
        ["install_eg"]="eg"
        ["install_eggs"]="eggs"
        ["install_double_esc_sudo"]="double-esc-sudo"
    )
    
    declare -A package_tools=(
        ["install_docker_and_docker_compose"]="docker-compose"
        ["install_snap"]="snap"
        ["install_flatpak"]="flatpak"
        ["install_fonts"]="fonts"
    )

    # 批量安装并记录结果的函数
    batch_install() {
        local -n funcs=$1  # 通过引用传递数组
        local -A results
        
        for func in "${!funcs[@]}"; do
            if $func; then
                results[${funcs[$func]}]="成功"
            else
                results[${funcs[$func]}]="失败"
            fi
        done
        
        # 打印安装结果
        log 1 "\n=== 软件安装结果汇总 ==="
        for app in "${!results[@]}"; do
            if [[ "${results[$app]}" == *"失败"* ]]; then
                printf "%-20s: " "$app"
                red "${results[$app]}"
            else
                printf "%-20s: %s\n" "$app" "${results[$app]}"
            fi
        done
        log 1 "\n======================"
        
        return 0
    }

    # 批量卸载并记录结果的函数
    batch_uninstall() {
        local -n funcs=$1  # 通过引用传递数组
        local -A results
        declare -A uninstall_funcs
        
        # 将安装函数名转换为卸载函数名
        for func in "${!funcs[@]}"; do
            local uninstall_func=${func/install/uninstall}
            uninstall_funcs[$uninstall_func]=${funcs[$func]}
        done
        
        # 执行卸载
        for func in "${!uninstall_funcs[@]}"; do
            if $func; then
                results[${uninstall_funcs[$func]}]="成功"
            else
                results[${uninstall_funcs[$func]}]="失败"
            fi
        done
        
        # 打印卸载结果
        log 1 "\n=== 软件卸载结果汇总 ==="
        for app in "${!results[@]}"; do
            if [[ "${results[$app]}" == *"失败"* ]]; then
                printf "%-20s: " "$app"
                red "${results[$app]}"
            else
                printf "%-20s: %s\n" "$app" "${results[$app]}"
            fi
        done
        log 1 "\n======================"
        
        return 0
    }

    case $choice in
        # 桌面系统增强必备
        01) install_plank ;;
        02) install_angrysearch ;;
        03) install_pot_desktop ;;
        04) install_geany ;;
        05) install_stretchly ;;
        06) install_ab_download_manager ;;
        07) install_localsend ;;
        08) install_spacefm ;;
        09) install_krusader ;;
        10) install_konsole ;;

        19) batch_install desktop_basic ;;

        
        # 桌面系统进阶常用软件
        20) install_tabby ;;
        21) install_telegram ;;
        22) install_brave ;;
        23) install_VLC ;;
        24) install_windsurf ;;
        25) install_pdfarranger ;;

        29) batch_install desktop_advanced ;;


        # 命令行增强工具
        30) install_neofetch ;;
        31) install_micro ;;
        32) install_cheatsh ;;
        33) install_eg ;;
        34) install_eggs ;;
        35) install_double_esc_sudo ;;

        39) batch_install cli_tools ;;

        
        # 软件库工具
        40) install_docker_and_docker_compose ;;
        41) install_snap ;;
        42) install_flatpak ;;
        43) install_fonts ;;
        
        49) batch_install package_tools ;;

        # 卸载选项 - 桌面系统增强必备
        101) uninstall_plank ;;
        102) uninstall_angrysearch ;;
        103) uninstall_pot_desktop ;;
        104) uninstall_geany ;;
        105) uninstall_stretchly ;;
        106) uninstall_ab_download_manager ;;
        107) uninstall_localsend ;;
        108) uninstall_spacefm ;;
        109) uninstall_krusader ;;
        110) uninstall_konsole ;;
        
        119) batch_uninstall desktop_basic ;;

        # 卸载选项 - 桌面系统进阶常用软件
        120) uninstall_tabby ;;
        121) uninstall_telegram ;;
        122) uninstall_brave ;;
        123) uninstall_VLC ;;
        124) uninstall_windsurf ;;
        125) uninstall_pdfarranger ;;

        129) batch_uninstall desktop_advanced ;;

        # 卸载选项 - 命令行增强工具
        130) uninstall_neofetch ;;
        131) uninstall_micro ;;
        132) uninstall_cheatsh ;;
        133) uninstall_eg ;;
        134) uninstall_eggs ;;
        135) uninstall_double_esc_sudo ;;

        139) batch_uninstall cli_tools ;;

        # 卸载选项 - 软件库工具
        140) uninstall_docker_and_docker_compose ;;
        141) uninstall_snap ;;
        142) uninstall_flatpak ;;

        149) batch_uninstall package_tools ;;

        0) 
            log 1 "退出脚本"
            exit 0 
            ;;
        *)
            log 3 "无效的选项，请重新选择"
            return 1
            ;;
    esac
}

# 主循环
main() {
    clear
    # 系统更新，分开执行并检查错误
    log 1 "更新系统软件包列表..."
    if ! sudo apt update; then
        log 3 "更新软件包列表失败"
        return 1
    fi

    log 1 "请先升级系统软件包..."
    if ! sudo apt upgrade -y; then
        log 3 "升级软件包失败"
        return 1
    fi

    # 主循环
    while true; do
        show_menu
        handle_menu
        echo
        read -p "按Enter键继续..."
    done
}

check_and_install_dependencies "jq" "git" "curl" "wget" "sudo"
main

# 如果脚本被直接运行而不是被source，则执行main函数
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     main
# fi