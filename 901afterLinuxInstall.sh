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

# 检查并安装依赖的函数
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

# 检查deb包依赖的函数，对于下载的deb包
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

# 检查已安装软件的依赖，对于仓库中的软件
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

# 1. 仓库安装docker和docker-compose函数
install_docker_and_docker_compose() {
    log 1 "开始安装Docker和Docker Compose"
    
    # 检查是否已经安装
    if dpkg -l | grep -q "^ii\s*docker-ce"; then
        log 1 "Docker已经安装"
        version=$(docker --version)
        log 1 "Docker版本: $version"
        compose_version=$(docker compose version)
        log 1 "Docker Compose版本: $compose_version"
        return 0
    fi

    # 检查必要的依赖
    local deps=("apt-transport-https" "ca-certificates" "curl" "gnupg" "lsb-release")
    if ! check_and_install_dependencies "${deps[@]}"; then
        log 3 "安装依赖失败，无法继续安装Docker和Docker Compose"
        return 1
    fi

    # 更新软件包列表并安装依赖
    log 1 "更新软件包列表并安装依赖"
    sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    if [ $? -ne 0 ]; then
        log 3 "安装依赖失败"
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
    
    log 1 "Docker安装和配置全部完成"
    return 0
}

# 卸载docker和docker-compose函数
uninstall_docker_and_docker_compose() {
    log 1 "开始卸载Docker和Docker Compose"
    
    # 停止所有运行的容器
    if command -v docker &> /dev/null; then
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


# 2. 仓库安装Brave浏览器函数
install_brave() {
    # 检查是否已安装
    if dpkg -l | grep -q "^ii\s*brave-browser"; then
        log 1 "Brave浏览器已经安装"
        version=$(brave-browser --version)
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

    # 更新软件包并安装curl
    log 1 "更新软件包并安装curl..."
    sudo apt update && sudo apt install -y curl
    if [ $? -ne 0 ]; then
        log 3 "安装curl失败"
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
    if command -v brave-browser &> /dev/null; then
        log 1 "Brave浏览器安装成功"
        version=$(brave-browser --version)
        log 1 "已安装Brave版本: $version"
        return 0
    else
        log 3 "Brave浏览器安装验证失败"
        return 1
    fi
}

# 卸载Brave浏览器的函数
uninstall_brave() {
    log 1 "开始卸载Brave浏览器..."

    # 检查是否已安装
    if ! command -v brave-browser &> /dev/null; then
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

# 3. GitHub安装和更新tabby的函数
install_tabby() {
    # 检测是否已安装
    if dpkg -l | grep -q "^ii\s*tabby"; then
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

# 卸载tabby的函数
uninstall_tabby() {
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

# 4. apt安装Konsole、VLC、Neofetch和krusader的函数
install_konsole() {
    log 1 "开始检查软件安装状态..."
    local packages=("konsole" "vlc" "neofetch" "krusader")
    local packages_to_install=()
    local all_installed=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii\s*$pkg"; then
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

# 卸载konsole vlc neofetch krusader的函数
uninstall_konsole() {
    log 1 "开始检查软件卸载状态..."
    local packages=("konsole" "vlc" "neofetch" "krusader")
    local packages_to_remove=()
    local all_uninstalled=true
    
    # 检查每个软件的安装状态
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii\s*$pkg"; then
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

# 5.GitHub安装和更新pot-desktopd的函数
install_pot_desktop() {
   # 检测是否已安装
    if dpkg -l | grep -q "^ii\s*pot"; then
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
            # 获取最新的下载链接,要先将之前保存的下载链接清空
            DOWNLOAD_URL=""
            get_download_link "https://github.com/pot-app/pot-desktop/releases" "amd64.deb$"
            # .*：表示任意字符（除换行符外）出现零次或多次。
            # linux-x86-64：匹配字符串“linux-x86-64”。
            # .*：再次表示任意字符出现零次或多次，以便在“linux-x86-64”之后可以有其他字符。
            # \.deb：匹配字符串“.deb”。注意，点号 . 在正则表达式中是一个特殊字符，表示任意单个字符，因此需要用反斜杠 \ 转义。
            # $：表示字符串的结尾。
            pot_desktop_download_link=${DOWNLOAD_URL}
            install_package ${pot_desktop_download_link}
        fi
        return 0
    else
            log 1 "本地未安装，下载远程最新版并安装..."
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
uninstall_pot_desktop() {
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

# 6. aptq安装geany的函数
install_geany() {
    log 1 "开始安装geany..."
    
    # 更新软件包列表并安装geany
    log 1 "更新软件包列表并安装Geany..."
    sudo apt update
    if ! sudo apt install -y geany geany-plugins geany-plugin-markdown; then
        log 3 "安装geany失败"
        return 1
    fi
    
    log 1 "geany及插件安装成功"
    return 0
}

# 卸载geany的函数
uninstall_geany() {
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

# 7. 仓库安装windsurf的函数
install_windsurf() {
    log 1 "开始安装Windsurf..."

    # 检查是否已安装
    if dpkg -l | grep -q '^ii\s*windsurf'; then
        log 1 "Windsurf已经安装"
        return 0
    fi

    # 创建keyrings目录（如果不存在）
    if [ ! -d "/usr/share/keyrings" ]; then
        sudo mkdir -p /usr/share/keyrings
    fi

    # 添加Windsurf GPG密钥
    log 1 "下载Windsurf GPG密钥..."
    curl -fsSL "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | sudo gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
    
    # 添加Windsurf软件源
    log 1 "添加Windsurf源列表..."
    echo "deb [signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg arch=amd64] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null

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
    if dpkg -l | grep -q '^ii\s*windsurf'; then
        log 1 "Windsurf安装成功"
        return 0
    else
        log 3 "Windsurf安装失败，请查看日志获取详细信息"
        return 1
    fi
}

# 卸载windsurf的函数
uninstall_windsurf() {
    log 1 "开始卸载Windsurf..."
    
    # 检查是否已安装
    if ! dpkg -l | grep -q '^ii\s*windsurf'; then
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

# 8. pipx安装pdfarranger的函数
install_pdfarranger() {
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

# 卸载pdfarranger的函数
uninstall_pdfarranger() {
    log 1 "开始卸载pdfarranger..."
    pipx uninstall pdfarranger
    if [ $? -ne 0 ]; then
        log 3 "卸载pdfarranger失败"
        return 1
    fi
    log 1 "pdfarranger卸载成功"
    return 0
}

# 9. apt安装spacefm的函数
install_spacefm() {
    log 1 "开始安装spacefm..."
    sudo apt update
    sudo apt install -y spacefm
    if [ $? -ne 0 ]; then
        log 3 "安装spacefm失败"
        return 1
    fi
    log 1 "spacefm安装成功"
    return 0
}

# 卸载spacefm的函数
uninstall_spacefm() {
    log 1 "开始卸载spacefm..."
    sudo apt remove -y spacefm
    if [ $? -ne 0 ]; then
        log 3 "卸载spacefm失败"
        return 1
    fi
    log 1 "spacefm卸载成功"
    return 0
}

# 10. apt安装flatpak的函数
install_flatpak() {
    log 1 "开始安装Flatpak..."

    # 检查是否已安装
    if command -v flatpak &> /dev/null; then
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

# 卸载flatpak的函数
uninstall_flatpak() {
    log 1 "开始卸载Flatpak..."

    # 检查是否已安装
    if ! command -v flatpak &> /dev/null; then
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

# 11. github安装和更新ab-download-manager的函数
install_ab_download_manager() {
    # 检查是否已经安装了ab-download-manager
    if dpkg -l | grep -q "^ii\s*abdownloadmanager"; then
        # 获取本地版本
        local_version=$(dpkg -l abdownloadmanager | grep "^ii" | awk '{print $3}')
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
            ab_download_manager_download_link=${DOWNLOAD_URL}
            install_package ${ab_download_manager_download_link}
        fi
    else
        # 获取最新的下载链接
        get_download_link "https://github.com/amir1376/ab-download-manager/releases" ".*linux_x64.*\.deb$"
        ab_download_manager_download_link=${DOWNLOAD_URL}
        install_package ${ab_download_manager_download_link}
    fi
}

# 卸载ab-download-manager的函数
uninstall_ab_download_manager() {
    log 1 "开始卸载ab-download-manager..."
    
    log 1 "ab-download-manager卸载成功"
    return 0
}

# 12. GitHub安装和更新localsend的函数
install_localsend() {
    # 检测是否已经安装了localsend
    if dpkg -l | grep -q "^ii\s*localsend"; then
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

# 卸载localsend的函数
uninstall_localsend() {
    log 1 "开始卸载localsend..."
    sudo apt remove -y localsend
    if [ $? -ne 0 ]; then
        log 3 "卸载localsend失败"
        return 1
    fi
    log 1 "localsend卸载成功"
    return 0
}

# 13. 安装micro软件
install_micro() {
    log 1 检查是否已经安装了micro
    if which micro >/dev/null 2>&1; then
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
                if command -v micro &> /dev/null; then
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
                if command -v micro &> /dev/null; then
                    log 1 "micro 编辑器安装成功！"
                    micro --version
                else
                    log 3 "micro 编辑器安装失败。"
                    return 1
                fi
            fi        
        # 验证安装
        if command -v micro &> /dev/null; then
            log 1 "micro 编辑器安装成功！"
            micro --version
        else
            log 3 "micro 编辑器安装失败。"
            return 1
        fi
    fi
}

uninstall_micro() {
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

# 14. 安装typora软件
install_typora() {
    # 检查是否已安装
    if dpkg -l | grep -q "^ii\s*typora"; then
        log 1 "Typora 已经安装"
        return 0
    fi
    
    log 1 "开始安装 Typora..."
    
    # Add Typora's GPG key using more secure method
    if ! curl -fsSL https://typora.io/linux/public-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/typora.gpg; then
        log 3 "下载并保存 Typora 的 GPG 密钥失败"
        return 1
    fi
    log 1 "已保存 Typora 的 GPG 密钥到 /usr/share/keyrings/typora.gpg"

    # Create and write to typora.list
    local repo_line="deb [arch=amd64 signed-by=/usr/share/keyrings/typora.gpg] https://typora.io/linux ./"
    if ! echo "$repo_line" | sudo tee /etc/apt/sources.list.d/typora.list > /dev/null; then
        log 3 "创建 Typora 软件源文件失败"
        return 1
    fi
    log 1 "已创建 Typora 软件源文件"

    # Update package list
    if ! sudo apt-get update; then
        log 3 "更新软件包列表失败"
        return 1
    fi
    log 1 "已更新软件包列表"

    # Install typora
    if ! sudo apt-get install typora -y; then
        log 3 "安装 Typora 失败"
        return 1
    fi

    log 1 "Typora 安装成功"
    return 0
}

# 卸载typora软件
uninstall_typora() {
    # 检查是否已安装
    if ! dpkg -l | grep -q "^ii\s*typora"; then
        log 1 "Typora 未安装，无需卸载"
        return 0
    fi

    log 1 "开始卸载 Typora..."
    
    # Remove typora first
    if ! sudo apt-get remove typora -y; then
        log 3 "卸载 Typora 失败"
        return 1
    fi
    log 1 "已卸载 Typora"

    # Remove Typora's GPG key if exists
    if [ -f "/usr/share/keyrings/typora.gpg" ]; then
        if ! sudo rm /usr/share/keyrings/typora.gpg; then
            log 3 "删除 Typora 的 GPG 密钥失败"
            return 1
        fi
        log 1 "已删除 Typora 的 GPG 密钥"
    fi

    # Remove typora.list if exists
    if [ -f "/etc/apt/sources.list.d/typora.list" ]; then
        if ! sudo rm /etc/apt/sources.list.d/typora.list; then
            log 3 "删除 Typora 软件源文件失败"
            return 1
        fi
        log 1 "已删除 Typora 软件源文件"
    fi

    # Update package list
    if ! sudo apt-get update; then
        log 3 "更新软件包列表失败"
        return 1
    fi
    log 1 "已更新软件包列表"

    log 1 "Typora 卸载成功"
    return 0
}

# 15. 安装snap和snap-store
install_snap() {
    # 检查是否已安装
    if command -v snap &> /dev/null && dpkg -l | grep -q "^ii\s*snapd"; then
        log 1 "Snap 已经安装"
        return 0
    fi

    log 1 "开始安装 Snap..."

    # 检查并安装依赖
    local dependencies=("snapd")
    if ! check_and_install_dependencies "${dependencies[@]}"; then
        log 3 "安装 Snap 依赖失败"
        return 1
    fi

    # 安装 snapd snap 以获取最新版本
    if ! sudo snap install snapd; then
        log 3 "安装 snapd snap 失败"
        return 1
    fi
    log 1 "已安装 snapd snap"

    # 安装并刷新 core snap 以解决潜在的兼容性问题
    if ! sudo snap install core; then
        log 3 "安装 core snap 失败"
        return 1
    fi
    log 1 "已安装 core snap"

    if ! sudo snap refresh core; then
        log 3 "刷新 core snap 失败"
        return 1
    fi
    log 1 "已刷新 core snap"

    # 安装 Snap Store
    if ! sudo snap install snap-store; then
        log 3 "安装 Snap Store 失败"
        return 1
    fi
    log 1 "已安装 Snap Store"

    # 测试安装
    if ! sudo snap install hello-world; then
        log 3 "安装测试包 hello-world 失败"
        return 1
    fi

    if ! hello-world; then
        log 3 "运行测试包失败"
        return 1
    fi

    log 1 "Snap 和 Snap Store 安装成功！"
    return 0
}

# 卸载snap和snap-store
uninstall_snap() {
    # 检查是否已安装
    if ! command -v snap &> /dev/null || ! dpkg -l | grep -q "^ii\s*snapd"; then
        log 1 "Snap 未安装，无需卸载"
        return 0
    fi

    log 1 "开始卸载 Snap..."

    # 卸载所有已安装的 snap 包
    for snap in $(snap list | awk 'NR>1 {print $1}'); do
        if [ "$snap" != "snapd" ]; then
            if ! sudo snap remove "$snap"; then
                log 3 "卸载 snap 包 $snap 失败"
                return 1
            fi
            log 1 "已卸载 snap 包 $snap"
        fi
    done

    # 卸载 snapd
    if ! sudo apt-get remove --purge snapd -y; then
        log 3 "卸载 snapd 失败"
        return 1
    fi
    log 1 "已卸载 snapd"

    # 清理残留文件
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /root/snap

    log 1 "Snap 卸载成功"
    return 0
}

# 生成菜单函数，用于显示菜单
# 每个菜单项都是一个函数，添加合适的分类
# 安装和卸载分开
show_menu() {
    # fonts color,简单快速输出颜色字
    # Usage:red "字母"
    red(){
        echo -e "\033[31m\033[01m$1\033[0m"
    }
    green(){
        echo -e "\033[32m\033[01m$1\033[0m"
    }
    yellow(){
        echo -e "\033[33m\033[01m$1\033[0m"
    }
    blue(){
        echo -e "\033[34m\033[01m$1\033[0m"
    }
    bold(){
        echo -e "\033[1m\033[01m$1\033[0m"
    }
    green "==================================="
    green "Linux软件一键安装脚本"
    green "==================================="
    yellow "安装选项:"
    green "1. 安装 Docker 和 Docker Compose"
    green "2. 安装 Brave 浏览器"
    green "3. 安装 Tabby 终端"
    green "4. 安装 Konsole、VLC、Neofetch和Krusader"
    green "5. 安装 Pot-desktop 翻译工具"
    green "6. 安装 Geany 编辑器"
    green "7. 安装 Windsurf IDE"
    green "8. 安装 PDF Arranger"
    green "9. 安装 SpaceFM 文件管理器"
    green "10. 安装 Flatpak"
    green "11. 安装 AB Download Manager"
    green "12. 安装 LocalSend"
    yellow "13. 安装1-12的全部软件"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    yellow "卸载选项:"
    green "21. 卸载 Docker 和 Docker Compose"
    green "22. 卸载 Brave 浏览器"
    green "23. 卸载 Tabby 终端"
    green "24. 卸载 Konsole、VLC、Neofetch和Krusader"
    green "25. 卸载 Pot-desktop 翻译工具"
    green "26. 卸载 Geany 编辑器"
    green "27. 卸载 Windsurf IDE"
    green "28. 卸载 PDF Arranger"
    green "29. 卸载 SpaceFM 文件管理器"
    green "30. 卸载 Flatpak"
    green "31. 卸载 AB Download Manager"
    green "32. 卸载 LocalSend"
    green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    yellow "0. 退出脚本"

}

# 处理菜单选择
handle_menu() {
    local choice
    read -p "请输入选项编号: " choice
    case $choice in
        1) install_docker_and_docker_compose ;;
        2) install_brave ;;
        3) install_tabby ;;
        4) install_konsole ;;
        5) install_pot_desktop ;;
        6) install_geany ;;
        7) install_windsurf ;;
        8) install_pdfarranger ;;
        9) install_spacefm ;;
        10) install_flatpak ;;
        11) install_ab_download_manager ;;
        12) install_localsend ;;
        13) 
            install_docker_and_docker_compose
            install_brave
            install_tabby
            install_konsole
            install_pot_desktop
            install_geany
            install_windsurf
            install_pdfarranger
            install_spacefm
            install_flatpak
            install_ab_download_manager
            install_localsend
            ;;
        21) uninstall_docker_and_docker_compose ;;
        22) uninstall_brave ;;
        23) uninstall_tabby ;;
        24) uninstall_konsole ;;
        25) uninstall_pot_desktop ;;
        26) uninstall_geany ;;
        27) uninstall_windsurf ;;
        28) uninstall_pdfarranger ;;
        29) uninstall_spacefm ;;
        30) uninstall_flatpak ;;
        31) uninstall_ab_download_manager ;;
        32) uninstall_localsend ;;
        0) 
            log 1 "退出脚本"
            exit 0 
            ;;
        *)
            log 3 "无效的选项，请重新选择"
            ;;
    esac
}

# 主循环
main() {
    clear
    log "./logs/901.log" 1 "第一条消息，同时设置日志文件"
    log 1 "日志记录在./logs/901.log"

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

# 如果脚本被直接运行而不是被source，则执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi