#!/bin/bash

# 设置将ssh远程的一个目录挂载到本地：https://github.com/libfuse/sshfs
# sshfs user@host:/path/to/folder /path/to/mountpoint

# Mount a WebDAV resource as a regular file system： https://savannah.nongnu.org/projects/davfs2
# sudo apt install -y davfs2
# davfs2 的主要命令是 mount.davfs，而不是直接的 davfs2。你可以尝试使用以下命令来挂载 WebDAV 资源：
# sudo mount -t davfs https://your-webdav-url /your/mount/point


install_sshfs() {
    # 检查是否已安装
    if command -v sshfs >/dev/null 2>&1; then
        local version=$(sshfs --version 2>&1 | head -n 1)
        log 1 "SSHFS已安装，当前版本: $version"
        return 0
    fi

    # 检查系统包管理器
    if ! command -v apt >/dev/null 2>&1; then
        log 3 "错误：未找到apt包管理器"
        return 1
    fi

    # 更新包列表
    log 1 "正在更新包列表..."
    if ! sudo apt update >/dev/null 2>&1; then
        log 3 "错误：更新包列表失败"
        return 1
    fi

    # 安装 sshfs
    log 1 "正在安装SSHFS..."
    if sudo apt install -y sshfs; then
        # 验证安装是否成功
        if command -v sshfs >/dev/null 2>&1; then
            local version=$(sshfs --version 2>&1 | head -n 1)
            log 1 "SSHFS安装成功，版本: $version"
            return 0
        else
            log 3 "错误：SSHFS安装验证失败"
            return 1
        fi
    else
        log 3 "错误：SSHFS安装失败"
        return 1
    fi
}