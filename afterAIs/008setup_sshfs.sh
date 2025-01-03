#!/bin/bash

# 本脚本用于在 Debian 系统上安装 SSHFS 和可选地安装 davfs2。
# SSHFS: https://github.com/libfuse/sshfs
# davfs2: https://savannah.nongnu.org/projects/davfs2

# 定义日志函数
log() {
    local level="$1"
    shift
    local message="$*"

    case "$level" in
        1) echo -e "[INFO] $message" ;;  # 信息日志
        2) echo -e "[WARNING] $message" ;;  # 警告日志
        3) echo -e "[ERROR] $message" ;;  # 错误日志
        *) echo -e "[UNKNOWN] $message" ;;  # 未知级别
    esac
}

# 安装 SSHFS 的函数
install_sshfs() {
    log 1 "检查是否已安装 SSHFS..."
    if command -v sshfs >/dev/null 2>&1; then
        local version=$(sshfs --version 2>&1 | head -n 1)
        log 1 "SSHFS 已安装，当前版本: $version"
        return 0
    fi

    log 1 "SSHFS 未安装，开始安装..."

    # 更新包列表
    log 1 "更新包列表中..."
    sudo apt update >/dev/null 2>&1 || { log 3 "更新包列表失败"; exit 1; }

    # 安装 SSHFS
    log 1 "安装 SSHFS 中..."
    sudo apt install -y sshfs >/dev/null 2>&1 || { log 3 "SSHFS 安装失败"; exit 1; }

    # 验证安装
    if command -v sshfs >/dev/null 2>&1; then
        local version=$(sshfs --version 2>&1 | head -n 1)
        log 1 "SSHFS 安装成功，版本: $version"
    else
        log 3 "SSHFS 安装验证失败"
        exit 1
    fi
}

# 安装 davfs2 的函数
install_davfs2() {
    log 1 "检查是否已安装 davfs2..."
    if command -v mount.davfs >/dev/null 2>&1; then
        log 1 "davfs2 已安装。"
        return 0
    fi

    log 1 "davfs2 未安装，开始安装..."

    # 更新包列表
    log 1 "更新包列表中..."
    sudo apt update >/dev/null 2>&1 || { log 3 "更新包列表失败"; exit 1; }

    # 安装 davfs2
    log 1 "安装 davfs2 中..."
    sudo apt install -y davfs2 >/dev/null 2>&1 || { log 3 "davfs2 安装失败"; exit 1; }

    # 验证安装
    if command -v mount.davfs >/dev/null 2>&1; then
        log 1 "davfs2 安装成功。"
    else
        log 3 "davfs2 安装验证失败"
        exit 1
    fi
}

# 主程序
log 1 "脚本开始执行..."

# 安装 SSHFS
install_sshfs

# 可选安装 davfs2
read -p "是否需要安装 davfs2？(y/n): " install_davfs2_choice
if [[ "$install_davfs2_choice" =~ ^[Yy]$ ]]; then
    install_davfs2
else
    log 1 "跳过 davfs2 安装。"
fi

log 1 "脚本执行完毕。"