
# 通用的Debian软件包安装/卸载函数
# 参数1: package_name - 软件包名称
# 参数2: action - 动作(install/uninstall)，可选，默认为install
# 返回值: 成功返回0，失败返回1
function setup_debian_package() {
    local package_name="$1"
    local action="${2:-install}"  # 如果未提供第二个参数，默认为install

    # 参数验证
    if [ -z "$package_name" ]; then
        log 3 "参数错误: 需要提供软件包名称"
        return 1
    fi

    if [ "$action" = "install" ]; then
        log 1 "检查 $package_name 是否已安装"
        if check_if_installed "$package_name"; then
            # 获取本地版本
            local local_version=$(dpkg -l | grep "^ii\s*$package_name" | awk '{print $3}')
            log 2 "$package_name 已安装，本地版本: $local_version"
            return 0
        fi

        # # 检查并安装依赖（包括常用中文字体）
        # local dependencies=("curl" "fonts-wqy-zenhei" "fonts-noto-cjk" "fonts-wqy-microhei" "xfonts-wqy")
        # if ! check_and_install_dependencies "${dependencies[@]}"; then
        #     log 3 "安装 $package_name 依赖失败"
        #     return 1
        # fi

        # 安装软件包
        if ! sudo apt install -y "$package_name"; then
            log 3 "安装 $package_name 失败"
            return 1
        fi

        # 验证安装
        if ! check_if_installed "$package_name"; then
            log 3 "$package_name 安装失败"
            return 1
        fi

        log 2 "$package_name 安装完成"
        return 0

    elif [ "$action" = "uninstall" ]; then
        log 1 "检查 $package_name 是否已安装"
        if ! check_if_installed "$package_name"; then
            log 2 "$package_name 未安装"
            return 0
        fi

        # 卸载软件包
        if ! sudo apt purge -y "$package_name"; then
            log 3 "卸载 $package_name 失败"
            return 1
        fi

        log 2 "$package_name 卸载完成"
        return 0

    else
        log 3 "不支持的动作: $action (应为 install 或 uninstall)"
        return 1
    fi
}