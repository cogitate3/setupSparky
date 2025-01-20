#!/bin/bash

# 检查参数数量
if [ "$#" -ne 2 ]; then
    echo "用法: $0 <ubuntu-package-name或.deb文件名> <debian-version>"
    echo "支持的 Debian 版本:"
    echo "- bookworm"
    echo "- bullseye"
    echo "- buster"
    echo "- stretch"
    exit 1
fi

ubuntu_package="$1"
debian_system="$2"

check_package_compatibility() {
    local ubuntu_package="$1"
    local debian_system="$2"

    # 创建一个数组来存储已检查过的依赖项
    local checked_deps=()

    # 递归检查依赖关系
    if ! check_dependencies "$ubuntu_package" "$debian_system" checked_deps; then
        echo "以下软件包在 Debian $debian_system 上可能不兼容:"
        for dep in "${checked_deps[@]}"; do
            echo "- $dep"
        done
        return 1
    else
        return 0
    fi
}

check_dependencies() {
    local package="$1"
    local debian_system="$2"
    local -n checked_deps="$3"

    # 获取软件包的依赖关系
    local dep_output
    if ! dep_output=$(apt-cache depends "$package" 2>/dev/null); then
        echo "无法获取 $package 的依赖关系" >&2
        checked_deps+=("$package")
        return 1
    fi

    # 解析依赖关系
    local dependencies=$(echo "$dep_output" | grep -o 'Depends: .*' | sed 's/Depends: //')

    # 检查每个依赖项在 Debian 系统上的版本
    for dep in $dependencies; do
        if ! [[ " ${checked_deps[*]} " =~ " $dep " ]]; then
            local version_output
            if ! version_output=$(apt-cache policy "$dep" 2>/dev/null); then
                echo "无法获取依赖项 $dep 在 Debian $debian_system 上的版本信息" >&2
                checked_deps+=("$dep")
                return 1
            elif ! grep -q "Debian $debian_system" <<< "$version_output"; then
                echo "依赖项 $dep 在 Debian $debian_system 上不可用" >&2
                checked_deps+=("$dep")
                return 1
            else
                # 递归检查依赖项的依赖关系
                if ! check_dependencies "$dep" "$debian_system" checked_deps; then
                    return 1
                fi
            fi
        fi
    done

    return 0
}

# 调用检查函数
if check_package_compatibility "$ubuntu_package" "$debian_system"; then
    echo "该 Ubuntu 软件包在 Debian $debian_system 上兼容"
else
    echo "该 Ubuntu 软件包在 Debian $debian_system 上可能不兼容"
fi