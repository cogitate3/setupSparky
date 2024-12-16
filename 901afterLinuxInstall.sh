#!/bin/bash

# 日志相关配置
# source 001log2File.sh 003get_download_link.sh里面引入了001log2File.sh和002get_assets_links.sh
source 003get_download_link.sh
# log "./logs/901.log" "第一条消息，同时设置日志文件"     # 设置日志文件并记录消息，
# echo 日志记录在"./logs/901.log"


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

# 过程函数：统一检查软件是否已安装的函数
check_if_installed() {
    local package_name="$1"
    
    # 先用dpkg检查
    if dpkg -l | grep -q "^ii\s*$package_name"; then
        return 0  # 已安装
    fi
    
    # 如果dpkg检查失败，再用command检查
    if command -v "$package_name" &> /dev/null; then
        return 0  # 已安装
    fi
    
    return 1  # 未安装
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
# 桌面系统增强必备软件
# 函数：安装 Plank 快捷启动器
function install_plank() {
    # 检查是否已安装
    if check_if_installed "plank"; then
        log 1 "Plank 已安装"
        return 0
    fi

    # 检查并安装依赖
    local dependencies=("plank")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装 Plank 失败"
        return 1
    fi

    log 1 "Plank 快捷启动器安装完成"
}

# 函数：安装 angrysearch 类似everything的快速查找工具
function install_angrysearch() {
    # 检查并安装依赖
    local dependencies=("wget")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装依赖失败"
        return 1
    fi

    # 检查是否已安装
    if check_if_installed "angrysearch"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*angrysearch" | awk '{print $3}')
        log 1 "AngrySearch已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/DoTheEvo/ANGRYsearch/releases" ".*\.tar\.gz$"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新"
            return 0
        fi
        log 1 "发现新版本，开始更新..."
    else
        log 1 "开始安装 AngrySearch..."
    fi

    angrysearch_download_link=${DOWNLOAD_URL}
    install_package ${angrysearch_download_link}
    if [ $? -eq 2 ]; then
        log 2 "下载文件 ${ARCHIVE_FILE} 是压缩包"
        log 1 "解压并手动安装"
        local install_dir="/tmp/angrysearch_install" 
        rm -rf "$install_dir"  # 清理可能存在的旧目录
        mkdir -p "$install_dir"  # 创建新的临时目录
        
        # 检查源文件
        if [ ! -f "${ARCHIVE_FILE}" ]; then
            log 3 "压缩包文件 ${ARCHIVE_FILE} 不存在"
            rm -rf "$install_dir"
            return 1
        fi

        log 1 "开始解压 ${ARCHIVE_FILE}..."
                # -v: 显示解压过程
                # -x: 解压
                # -z: gzip格式
                # -f: 指定文件
                # 2>&1: 合并标准错误到标准输出
        if ! tar -vxzf "${ARCHIVE_FILE}" -C "$install_dir" 2>&1; then
            log 3 "解压失败，可能是文件损坏或格式不正确"
            rm -rf "$install_dir"
            return 1
        fi

        # 检查解压结果
        if [ ! "$(ls -A "$install_dir")" ]; then
            log 3 "解压后目录为空，解压可能失败"
            rm -rf "$install_dir"
            return 1
        fi

        # 检查是否存在ANGRYsearch-*目录
        if [ ! -d "$install_dir"/ANGRYsearch-* ]; then
            log 3 "未找到 ANGRYsearch 程序目录"
            rm -rf "$install_dir"
            return 1
        fi

        log 1 "解压完成"
        # 执行ANGRYsearch-*目录下的install.sh
        chmod +x "$install_dir"/ANGRYsearch-*/install.sh
        if ! sudo "$install_dir"/ANGRYsearch-*/install.sh; then
            log 3 "执行安装脚本失败"
            rm -rf "$install_dir"
            return 1
        fi
        log 1 "安装ANGRYsearch 成功！用sudo angrysearch 启动！"
    else
        log 1 "安装ANGRYsearch 成功！用sudo angrysearch 启动！"
    fi

    # 清理临时文件
    rm -rf "$install_dir"
    rm -f "${ARCHIVE_FILE}"
    
    # 验证安装
    if check_if_installed "angrysearch"; then
        log 1 "angrysearch 安装成功！"
        return 0
    else
        log 3 "angrysearch 安装失败"
        return 1
    fi
}

# 函数：安装 Pot-desktop 翻译工具
function install_pot_desktop() {
   # 检测是否已安装
    if check_if_installed "pot"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*pot" | awk '{print $3}')
        log 1 "pot-desktop已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/pot-app/pot-desktop/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 1 "发现新版本，开始更新..."
            pot_desktop_download_link=${DOWNLOAD_URL}
            install_package ${pot_desktop_download_link}
        fi
        return 0
    else
        # 获取最新的下载链接,要先将之前保存的下载链接清空
        DOWNLOAD_URL=""
        get_download_link "https://github.com/pot-app/pot-desktop/releases" ".*amd64.*\.deb$"
        # .*：表示任意字符（除换行符外）出现零次或多次。
        # linux-x86-64：匹配字符串“linux-x86-64”。
        # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
        # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
        # $：表示字符串的结尾。
        pot_desktop_download_link=${DOWNLOAD_URL}
        install_package ${pot_desktop_download_link}
    fi
}

# 卸载pot-desktop的函数
function uninstall_pot_desktop() {
    log 1 "开始卸载pot-desktop..."
    
    # 获取实际的包名
    pkg_name=$(dpkg -l | grep -i pot | awk '{print $2}')
    if [ -z "$pkg_name" ]; then
        log 3 "未找到已安装的pot-desktop"
        return 1
    fi
    
    log 1 "找到pot-desktop包名: ${pkg_name}"
    if sudo dpkg -r "$pkg_name"; then
        log 1 "pot-desktop卸载成功"
        # 清理依赖
        sudo apt autoremove -y
        return 0
    else
        log 3 "pot-desktop卸载失败"
        return 1
    fi
}

# 函数：安装 
function install_geany() {
    # 检查是否已安装
    if check_if_installed "geany"; then
        log 1 "Geany已经安装"
        version=$(get_package_version "geany" "geany --version")
        log 1 "Geany版本: $version"
        return 0
    fi

    log 1 "开始安装geany..."
    
    # 更新软件包列表并安装geany
    log 1 "更新软件包列表并安装Geany..."
    sudo apt update
    if ! sudo apt install -y geany geany-plugins geany-plugin-markdown; then
        log 3 "安装geany失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "geany"; then
        log 1 "Geany安装成功"
        version=$(get_package_version "geany" "geany --version")
        log 1 "Geany版本: $version"
        return 0
    else
        log 3 "Geany安装验证失败"
        return 1
    fi

    log 1 "Geany安装成功"
    return 0
}

# 函数：卸载 Geany 简洁清凉的文字编辑器
function uninstall_geany() {
    log 1 "开始卸载geany..."
    if ! sudo apt remove -y geany geany-plugins geany-plugin-markdown; then
        log 3 "卸载geany失败"
        return 1
    fi
    
    # 清理配置文件和依赖
    sudo apt purge -y geany geany-plugins geany-plugin-markdown
    sudo apt autoremove -y
    
    log 1 "geany卸载成功"
    return 0
}
# 函数：安装 stretchly 定时休息桌面
function install_stretchly() {
    log 1 "开始安装stretchly..."
    
    # 更新软件包列表并安装stretchly
    log 1 "更新软件包列表并安装stretchly..."
    sudo apt update
    if ! sudo apt install -y stretchly; then
        log 3 "安装stretchly失败"
        return 1
    fi
    
    # 验证安装
    if check_if_installed "stretchly"; then
        log 1 "stretchly安装成功"
        return 0
    else
        log 3 "stretchly安装验证失败"
        return 1
    fi
}

# 函数：安装和更新 ab-download-manager 下载工具
function install_ab_download_manager() {
    # 检查是否已经安装了ab-download-manager
    if check_if_installed "abdownloadmanager"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*abdownloadmanager" | awk '{print $3}')
        log 1 "ab-download-manager已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/amir1376/ab-download-manager/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新，返回主菜单"
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
    log 1 "开始卸载ab-download-manager..."
    
    log 1 "ab-download-manager卸载成功"
    return 0
}

# 函数：安装和更新 localsend 局域网传输工具
function install_localsend() {
    # 检测是否已经安装了localsend
    if check_if_installed "localsend"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*localsend" | awk '{print $3}')
        log 1 "localsend已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/localsend/localsend/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 1 "发现新版本，开始更新..."
            DOWNLOAD_URL=""
            get_download_link "https://github.com/localsend/localsend/releases" ".*linux-x86-64.*\.deb$"            
            localsend_download_link=${DOWNLOAD_URL}
            install_package ${localsend_download_link}
        fi
        log 1 "localsend已经安装"
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
        log 1 "localsend已经安装"
        return 0
    fi
}

# 函数： 卸载 localsend 局域网传输工具
function uninstall_localsend() {
    log 1 "开始卸载localsend..."
    sudo apt remove -y localsend
    if [ $? -ne 0 ]; then
        log 3 "卸载localsend失败"
        return 1
    fi
    log 1 "localsend卸载成功"
    return 0
}

# 函数：安装 SpaceFM 双面板文件管理器
function install_spacefm() {
    # 检查是否已安装
    if check_if_installed "spacefm"; then
        return 0
    fi

    log 1 "开始安装 spacefm..."
    
    # 安装依赖
    local dependencies=("spacefm")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装 spacefm 失败"
        return 1
    fi

    # 验证安装
    if ! check_if_installed "spacefm"; then
        log 3 "spacefm 安装失败"
        return 1
    fi

    log 1 "spacefm 安装成功"
    return 0
}

# 函数：卸载 SpaceFM 双面板文件管理器
function uninstall_spacefm() {
    log 1 "开始检查软件卸载状态..."
    local packages=("spacefm")
    local packages_to_remove=()
    local all_uninstalled=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if check_if_installed "$pkg"; then
            packages_to_remove+=("$pkg")
            all_uninstalled=false
            log 1 "$pkg 已安装，将进行卸载"
        else
            log 1 "$pkg 未安装"
        fi
    done
    
    # 如果所有软件都未安装，直接返回
    if [ "$all_uninstalled" = true ]; then
        log 1 "所有软件都未安装，无需操作"
        return 0
    fi
    
    # 卸载已安装的软件
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        log 1 "开始卸载软件: ${packages_to_remove[*]}"
        if ! sudo apt remove -y "${packages_to_remove[@]}"; then
            log 3 "卸载失败: ${packages_to_remove[*]}"
            return 1
        fi
        
        # 清理配置文件
        log 1 "清理软件配置..."
        sudo apt purge -y "${packages_to_remove[@]}"
        sudo apt autoremove -y
        
        log 1 "所有软件卸载成功"
    fi
    
    return 0
}

# 函数：安装 Krusader 双面板文件管理器
function install_krusader() {
    log 1 "开始检查软件安装状态..."
    local packages=("krusader")
    local packages_to_install=()
    local all_installed=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if ! check_if_installed "$pkg"; then
            packages_to_install+=("$pkg")
            all_installed=false
            log 1 "$pkg 未安装，将进行安装"
        else
            log 1 "$pkg 已安装"
        fi
    done
    
    # 如果所有软件都已安装，直接返回
    if [ "$all_installed" = true ]; then
        log 1 "所有软件都已安装，无需操作"
        return 0
    fi
    
    # 安装未安装的软件
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log 1 "开始安装未安装的软件: ${packages_to_install[*]}"
        sudo apt update
        if ! sudo apt install -y "${packages_to_install[@]}"; then
            log 3 "安装失败: ${packages_to_install[*]}"
            return 1
        fi
        log 1 "所有软件安装成功"
    fi
    
    return 0
}

# 函数：卸载 Krusader 双面板文件管理器
function uninstall_krusader() {
    log 1 "开始检查软件卸载状态..."
    local packages=("krusader")
    local packages_to_remove=()
    local all_uninstalled=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if check_if_installed "$pkg"; then
            packages_to_remove+=("$pkg")
            all_uninstalled=false
            log 1 "$pkg 已安装，将进行卸载"
        else
            log 1 "$pkg 未安装"
        fi
    done
    
    # 如果所有软件都未安装，直接返回
    if [ "$all_uninstalled" = true ]; then
        log 1 "所有软件都未安装，无需操作"
        return 0
    fi
    
    # 卸载已安装的软件
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        log 1 "开始卸载软件: ${packages_to_remove[*]}"
        if ! sudo apt remove -y "${packages_to_remove[@]}"; then
            log 3 "卸载失败: ${packages_to_remove[*]}"
            return 1
        fi
        
        # 清理配置文件
        log 1 "清理软件配置..."
        sudo apt purge -y "${packages_to_remove[@]}"
        sudo apt autoremove -y
        
        log 1 "所有软件卸载成功"
    fi
    
    return 0
}

# 函数：安装 Konsole KDE's Terminal Emulator
function install_konsole() {
    log 1 "开始检查软件安装状态..."
    local packages=("konsole")
    local packages_to_install=()
    local all_installed=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if ! check_if_installed "$pkg"; then
            packages_to_install+=("$pkg")
            all_installed=false
            log 1 "$pkg 未安装，将进行安装"
        else
            log 1 "$pkg 已安装"
        fi
    done
    
    # 如果所有软件都已安装，直接返回
    if [ "$all_installed" = true ]; then
        log 1 "所有软件都已安装，无需操作"
        return 0
    fi
    
    # 安装未安装的软件
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log 1 "开始安装未安装的软件: ${packages_to_install[*]}"
        sudo apt update
        if ! sudo apt install -y "${packages_to_install[@]}"; then
            log 3 "安装失败: ${packages_to_install[*]}"
            return 1
        fi
        log 1 "所有软件安装成功"
    fi
    
    return 0
}

# 函数：卸载 Konsole KDE's Terminal Emulator
function uninstall_konsole() {
    log 1 "开始检查软件卸载状态..."
    local packages=("konsole")
    local packages_to_remove=()
    local all_uninstalled=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if check_if_installed "$pkg"; then
            packages_to_remove+=("$pkg")
            all_uninstalled=false
            log 1 "$pkg 已安装，将进行卸载"
        else
            log 1 "$pkg 未安装"
        fi
    done
    
    # 如果所有软件都未安装，直接返回
    if [ "$all_uninstalled" = true ]; then
        log 1 "所有软件都未安装，无需操作"
        return 0
    fi
    
    # 卸载已安装的软件
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        log 1 "开始卸载软件: ${packages_to_remove[*]}"
        if ! sudo apt remove -y "${packages_to_remove[@]}"; then
            log 3 "卸载失败: ${packages_to_remove[*]}"
            return 1
        fi
        
        # 清理配置文件
        log 1 "清理软件配置..."
        sudo apt purge -y "${packages_to_remove[@]}"
        sudo apt autoremove -y
        
        log 1 "所有软件卸载成功"
    fi
    
    return 0
}


# 桌面系统进阶常用软件
# 函数：安装和更新 Tabby 可同步终端
function install_tabby() {
    # 检测是否已安装
    if check_if_installed "tabby"; then
        # 获取本地版本
        local_version=$(dpkg -l | grep  "^ii\s*tabby" | awk '{print $3}')
        log 1 "Tabby已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/Eugeny/tabby/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 1 "发现新版本，开始更新..."
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
    log 1 "开始卸载Tabby..."
    
    # 获取实际的包名
    pkg_name=$(dpkg -l | grep -i tabby | awk '{print $2}')
    if [ -z "$pkg_name" ]; then
        log 3 "未找到已安装的Tabby"
        return 1
    fi
    
    log 1 "找到Tabby包名: ${pkg_name}"
    if sudo dpkg -r "$pkg_name"; then
        log 1 "Tabby卸载成功"
        # 清理依赖
        sudo apt autoremove -y
        return 0
    else
        log 3 "Tabby卸载失败"
        return 1
    fi
}

# 函数：安装 Brave 浏览器函数
function install_brave() {
    # 检查是否已安装
    if check_if_installed "brave-browser"; then
        log 1 "Brave浏览器已经安装"
        version=$(get_package_version "brave-browser" "brave-browser --version")
        log 1 "Brave版本: $version"
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
        log 1 "Brave浏览器安装成功"
        version=$(get_package_version "brave-browser" "brave-browser --version")
        log 1 "已安装Brave版本: $version"
        return 0
    else
        log 3 "Brave浏览器安装验证失败"
        return 1
    fi
}

# 函数：卸载 Brave 浏览器的函数
function uninstall_brave() {
    log 1 "开始卸载Brave浏览器..."
    
    # 检查是否已安装
    if ! check_if_installed "brave-browser"; then
        log 1 "Brave浏览器未安装"
        return 0
    fi

    # 卸载Brave浏览器
    log 1 "卸载Brave浏览器..."
    sudo apt purge -y brave-browser
    if [ $? -ne 0 ]; then
        log 3 "卸载Brave浏览器失败"
        return 1
    fi

    # 删除软件源
    log 1 "删除Brave软件源..."
    rm -f /etc/apt/sources.list.d/brave-browser-release.list
    if [ $? -ne 0 ]; then
        log 3 "删除Brave软件源文件失败"
    fi

    # 删除GPG密钥
    log 1 "删除Brave GPG密钥..."
    rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
    if [ $? -ne 0 ]; then
        log 3 "删除Brave GPG密钥失败"
    fi

    # 清理不需要的依赖
    log 1 "清理不需要的依赖..."
    sudo apt autoremove -y
    
    log 1 "Brave浏览器卸载完成"
    return 0
}

# 函数：安装 VLC 视频播放器
function install_VLC() {
}

# 函数：卸载 VLC 视频播放器
function uninstall_VLC() {
}

# 函数：安装 Windsurf IDE 编程工具
function install_windsurf() {
    # 检查是否已安装 Windsurf
    if check_if_installed "windsurf"; then
        log 1 "Windsurf 已经安装"
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
        log 1 "Windsurf安装成功"
        return 0
    else
        log 3 "Windsurf安装失败，请查看日志获取详细信息"
        return 1
    fi
}

# 函数：卸载 Windsurf IDE 编程工具
function uninstall_windsurf() {
    log 1 "开始卸载Windsurf..."
    
    # 检查是否已安装
    if ! check_if_installed "windsurf"; then
        log 1 "Windsurf未安装"
        return 0
    fi
    
    # 卸载Windsurcd source
    if ! sudo apt remove -y windsurf; then
        log 3 "卸载Windsurf失败"
        return 1
    fi
    
    # 清理配置文件和依赖
    sudo apt purge -y windsurf
    sudo apt autoremove -y
    
    # 删除仓库配置
    sudo rm -f /etc/apt/sources.list.d/windsurf.list
    sudo rm -f /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
    
    log 1 "Windsurf卸载成功"
    return 0
}


# 函数：pipx安装 PDF Arranger PDF页面编辑器
function install_pdfarranger() {
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
    log 1 "pdfarranger安装成功"
    return 0
}

# 卸载：PDF Arranger PDF页面编辑器
function uninstall_pdfarranger() {
    log 1 "开始卸载pdfarranger..."
    pipx uninstall pdfarranger
    if [ $? -ne 0 ]; then
        log 3 "卸载pdfarranger失败"
        return 1
    fi
    log 1 "pdfarranger卸载成功"
    return 0
}

# 函数：安装 WPS Office
function install_wps() {
    # 检查并安装依赖
    local dependencies=("wget")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装依赖失败"
        return 1
    fi

    # 检查是否已安装
    if check_if_installed "wps-office"; then
        log 1 "WPS Office 已安装"
        return 0
    fi

    cd ~/Downloads
    wget https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11664/wps-office_11.1.0.11664_amd64.deb
    sudo dpkg -i wps-office_11.1.0.11664_amd64.deb
    sudo apt-mark hold wps-office  # 阻止 WPS 自动更新
    log 1 "WPS Office 安装完成。已阻止自动更新，请手动更新到稳定版本"
}

# 函数：卸载 WPS Office
function uninstall_wps() {
    # 检查是否已安装
    if ! check_if_installed "wps-office"; then
        log 1 "WPS Office 未安装"
        return 0
    fi

    sudo apt-mark unhold wps-office
    sudo apt purge -y wps-office
    sudo apt autoremove -y
    log 1 "WPS Office 卸载完成"
}


# 安装命令行增强工具
# 函数：安装和更新 micro 命令行编辑器
function install_micro() {
    log 1 检查是否已经安装了micro
    if check_if_installed "micro"; then
        # 获取已安装版本
        local_version=$(micro --version 2>&1 | grep -oP 'Version: \K[0-9.]+' || echo "unknown")
        log 1 "micro已安装，本地版本: $local_version"
        
        # 获取远程最新版本
        get_download_link "https://github.com/zyedidia/micro/releases"
        # 从LATEST_VERSION中提取版本号（去掉v前缀）
        remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号，检查本地版本是否包含远程版本
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 1 "已经是最新版本，无需更新，返回主菜单"
            return 0
        else
            log 1 "发现新版本，开始更新..."
            micro_download_link=${DOWNLOAD_URL}
            install_package ${micro_download_link}
            if [ $? -eq 2 ]; then
                log 2 "下载文件 ${ARCHIVE_FILE} 是压缩包"
                log 1 解压并手动安装
                local install_dir="/tmp/micro_install" 
                rm -rf "$install_dir"  # 清理可能存在的旧目录
                mkdir -p "$install_dir"  # 创建新的临时目录
                
                # 检查源文件
                if [ ! -f "${ARCHIVE_FILE}" ]; then
                    log 3 "压缩包文件 ${ARCHIVE_FILE} 不存在"
                    rm -rf "$install_dir"
                    return 1
                fi

                log 1 "开始解压 ${ARCHIVE_FILE}..."
                # -v: 显示解压过程
                # -x: 解压
                # -z: gzip格式
                # -f: 指定文件
                # 2>&1: 合并标准错误到标准输出
                if ! tar -vxzf "${ARCHIVE_FILE}" -C "$install_dir" 2>&1; then
                    log 3 "解压失败，可能是文件损坏或格式不正确"
                    rm -rf "$install_dir"
                    return 1
                fi

                # 检查解压结果
                if [ ! "$(ls -A "$install_dir")" ]; then
                    log 3 "解压后目录为空，解压可能失败"
                    rm -rf "$install_dir"
                    return 1
                fi

                # 检查是否存在micro-*目录
                if [ ! -d "$install_dir"/micro-* ]; then
                    log 3 "未找到 micro 程序目录"
                    rm -rf "$install_dir"
                    return 1
                fi

                log 1 "解压完成"
                # 移动到系统路径
                if ! sudo mv "$install_dir"/micro-* /usr/local/bin/micro; then
                    log 3 "移动目录到 /usr/local/bin 失败"
                    rm -rf "$install_dir"
                    return 1
                else
                    log 1 "移动目录到 /usr/local/bin 成功！"
                    echo 'export PATH=$PATH:/usr/local/bin/micro' >> ~/.bashrc && source ~/.bashrc 
                    # 环境变量目录不会自动继承,因此手动添加新生成的micro目录到环境变量
                    echo 'export PATH=$PATH:/usr/local/bin/micro' >> ~/.zshrc && source ~/.zshrc

                fi

                # 清理临时文件
                rm -rf "$install_dir"
                rm -f "${ARCHIVE_FILE}"
                # 验证安装
                if check_if_installed "micro"; then
                    log 1 "micro 编辑器安装成功！"
                    micro --version
                else
                    log 3 "micro 编辑器安装失败。"
                    return 1
                fi
            fi        
        fi
    else
        # 获取最新的下载链接
        log 1 "未找到micro，开始安装micro，请耐心等待..."
        get_download_link "https://github.com/zyedidia/micro/releases" .*linux64\.tar\.gz$ 
        micro_download_link=${DOWNLOAD_URL}
        install_package ${micro_download_link}
            if [ $? -eq 2 ]; then
                log 2 "下载文件 ${ARCHIVE_FILE} 是压缩包"
                log 1 解压并安装，因为系统之前未安装micro
                local install_dir="/tmp/micro_install" 
                rm -rf "$install_dir"  # 清理可能存在的旧目录
                mkdir -p "$install_dir"  # 创建新的临时目录
                
                # 检查源文件
                if [ ! -f "${ARCHIVE_FILE}" ]; then
                    log 3 "压缩包文件 ${ARCHIVE_FILE} 不存在"
                    rm -rf "$install_dir"
                    return 1
                fi

                log 1 "开始解压 ${ARCHIVE_FILE}..."
                # -v: 显示解压过程
                # -x: 解压
                # -z: gzip格式
                # -f: 指定文件
                # 2>&1: 合并标准错误到标准输出
                if ! tar -vxzf "${ARCHIVE_FILE}" -C "$install_dir" 2>&1; then
                    log 3 "解压失败，可能是文件损坏或格式不正确"
                    rm -rf "$install_dir"
                    return 1
                fi

                # 检查解压结果
                if [ ! "$(ls -A "$install_dir")" ]; then
                    log 3 "解压后目录为空，解压可能失败"
                    rm -rf "$install_dir"
                    return 1
                fi

                # 检查是否存在micro-*目录
                if [ ! -d "$install_dir"/micro-* ]; then
                    log 3 "未找到 micro 程序目录"
                    rm -rf "$install_dir"
                    return 1
                fi

                log 1 "解压完成"
                # 移动到系统路径
                if ! sudo mv "$install_dir"/micro-* /usr/local/bin/micro; then
                    log 3 "移动目录到 /usr/local/bin 失败"
                    rm -rf "$install_dir"
                    return 1
                else
                    log 1 "移动目录到 /usr/local/bin 成功！"
                    echo 'export PATH=$PATH:/usr/local/bin/micro' >> ~/.bashrc && source ~/.bashrc 
                    # 环境变量目录不会自动继承,因此手动添加新生成的micro目录到环境变量
                    echo 'export PATH=$PATH:/usr/local/bin/micro' >> ~/.zshrc && source ~/.zshrc

                fi

                # 清理临时文件
                rm -rf "$install_dir"
                rm -f "${ARCHIVE_FILE}"
                # 验证安装
                if check_if_installed "micro"; then
                    log 1 "micro 编辑器安装成功！"
                    micro --version
                else
                    log 3 "micro 编辑器安装失败。"
                    return 1
                fi
            fi        
        # 验证安装
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
    log 1 "开始卸载 micro 编辑器..."
    # 删除micro可执行文件
    if [ -f /usr/local/bin/micro ]; then
        log 1 "删除 micro 可执行文件..."
        if sudo rm -f /usr/local/bin/micro; then
            log 1 "成功删除 micro 可执行文件"
        else
            log 3 "删除 micro 可执行文件失败"
            return 1
        fi
    else
        log 1 "未找到 micro 可执行文件，可能已被删除"
    fi

    # 删除micro的环境变量
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

# 函数：安装 cheat.sh 命令行命令示例工具
function install_cheatsh() {
  # 检查并安装依赖
  local dependencies=("rlwrap" "curl")
  if ! check_and_install_dependencies "${dependencies[@]}"; then
      log 3 "安装依赖失败"
      return 1
  fi

  # 检查是否已安装
  if check_if_installed "cht.sh"; then
      log 1 "cheat.sh 已安装"
      return 0
  fi

  # 确保目标目录存在
  mkdir -p ~/.local/bin

  # 安装主程序
  if ! curl -s https://cht.sh/:cht.sh > ~/.local/bin/cht.sh || ! chmod +x ~/.local/bin/cht.sh; then
      log 3 "下载或安装 cht.sh 失败"
      rm -f ~/.local/bin/cht.sh
      return 1
  fi

  # 添加到 PATH（如果需要）
  if ! echo $PATH | grep -q "$HOME/.local/bin"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
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
  if ! curl -s https://cheat.sh/:bash_completion > ~/.bash.d/cht.sh; then
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
  log 1 "开始卸载 cheat.sh...检查是否已安装"
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

# 函数：安装 eg 命令行命令示例工具
function install_eg() {
  # 检查是否已安装
  if check_if_installed "eg"; then
      log 1 "eg 已安装"
      return 0
  fi

  # 检查 Homebrew
  if ! check_if_installed "brew"; then
      log 3 "请先安装 Homebrew"
      return 1
  fi

  brew install eg-examples
  log 1 "eg 安装完成。使用方法：eg 命令 (例如 eg curl)"
}

# 函数：卸载 eg 命令行命令示例工具
function uninstall_eg() {
  log 1 "开始卸载 eg..."
  # 删除主程序
  if ! brew uninstall eg-examples; then
      log 3 "删除 eg 主程序失败"
      return 1
  fi
  log 1 "eg 卸载成功"
}

# 函数：安装 eggs 命令行系统备份
function install_eggs() {
    
}

# 函数：卸载 eggs 命令行系统备份
function uninstall_eggs() {
    
}

# 函数：安装 v2rayA 网络代理设置
function install_v2raya() {
    read -p "请选择安装方法 (1: 使用脚本, 2: 使用软件源): " method
    case $method in
        1)
            # 检查并安装依赖
            local dependencies=("curl")
            if ! check_and_install_dependencies "${dependencies[@]}"; then
                log 3 "安装依赖失败"
                return 1
            fi

            curl -Ls https://mirrors.v2raya.org/go.sh | sudo bash
            sudo systemctl disable v2ray --now
            log 1 "v2rayA (脚本安装) 完成。systemd 服务已禁用"
            ;;
        2)
            # 检查并安装依赖
            local dependencies=("wget")
            if ! check_and_install_dependencies "${dependencies[@]}"; then
                log 3 "安装依赖失败"
                return 1
            fi

            wget -qO - https://apt.v2raya.org/key/public-key.asc | sudo tee /etc/apt/trusted.gpg.d/v2raya.asc
            echo "deb https://apt.v2raya.org/ v2raya main" | sudo tee /etc/apt/sources.list.d/v2raya.list
            apt update && apt install -y v2raya
            log 1 "v2rayA (软件源安装) 完成"
            ;;
        *) 
            log 3 "无效的选项"
            return 1
            ;;
    esac
}

# 函数：卸载 v2rayA 网络代理设置
function uninstall_v2rayA() {
    
}


## 添加各种软件库
# 函数：安装 Flatpak 软件库
function install_flatpak() {
    log 1 "开始安装Flatpak..."

    # 检查是否已安装
    if check_if_installed "flatpak"; then
        log 1 "Flatpak已经安装，版本是$(flatpak --version)"
        return 0
    fi

    # 安装Flatpak
    log 1 "安装Flatpak..."
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
    else
        log 3 "未安装特定的Flatpak插件，您可能需要手动配置Flatpak"
    fi

    # 添加Flathub仓库
    log 1 "添加Flathub仓库..."
    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        log 3 "添加Flathub仓库失败，请检查网络连接"
        return 1
    fi

    log 1 "Flatpak安装完成，您可能需要重启系统以使更改生效"
    return 0
}

# 函数：卸载 Flatpak 软件库
function uninstall_flatpak() {
    log 1 "开始卸载Flatpak..."

    # 检查是否已安装
    if ! check_if_installed "flatpak"; then
        log 1 "Flatpak未安装"
        return 0
    fi

    # 首先卸载所有已安装的Flatpak应用
    log 1 "卸载所有Flatpak应用..."
    flatpak uninstall -y --all || log 2 "没有找到已安装的Flatpak应用"

    # 移除所有远程仓库
    log 1 "移除所有Flatpak仓库..."
    flatpak remote-delete --force -y --all || log 2 "没有找到Flatpak仓库"

    # 卸载Flatpak和相关插件
    log 1 "卸载Flatpak及相关插件..."
    if ! sudo apt remove -y flatpak gnome-software-plugin-flatpak plasma-discover-backend-flatpak; then
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

    log 1 "Flatpak完全卸载成功"
    return 0
}

# 函数：安装 snap和snapstore 软件库
function install_snap() {    
}

# 函数：卸载 snap和snapstore 软件库
function uninstall_snap() {    
}

# 函数：安装 Homebrew 
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

# 函数：安装 docker和docker-compose 虚拟化平台
function install_docker_and_docker_compose() {
    log 1 "开始安装Docker和Docker Compose"
    
    # 检查是否已经安装
    if check_if_installed "docker-ce"; then
        log 1 "Docker已经安装"
        version=$(get_package_version "docker-ce" "docker --version")
        log 1 "Docker版本: $version"
        compose_version=$(get_package_version "docker-compose-plugin" "docker compose version")
        log 1 "Docker Compose版本: $compose_version"
        return 0
    fi

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

    # 获取系统版本代号
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        codename=$DEBIAN_CODENAME
        log 1 "检测到系统版本代号: $codename"
    else
        log 3 "无法检测系统版本"
        return 1
    fi

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
        log 1 "Docker安装和配置全部完成"
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
    log 1 "开始卸载Docker和Docker Compose"
    
    # 停止所有运行的容器
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

