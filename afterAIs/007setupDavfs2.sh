#!/bin/bash

# 增强版davfs2安装卸载脚本：添加签名验证、备份恢复功能

set -e

# 基础配置
DAVFS2_URL="https://download.savannah.gnu.org/releases/davfs2/"
INSTALL_PREFIX="/usr/local"
DOWNLOAD_DIR="/tmp/davfs2_download"
BACKUP_DIR="/var/backups/davfs2"
LOG_FILE="/var/log/davfs2_install.log"

# 引入日志功能
source 001log2File.sh
log "$LOG_FILE" 1 "启动davfs2安装脚本"

# 错误处理函数
function error_exit() {
    log 3 "错误: $1"
    exit 1
}

# 检查系统要求
function check_prerequisites() {
    log 1 "检查系统要求..."
    local required_packages=("gcc" "make" "tar" "wget" "curl" "gpg")
    
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            error_exit "需要$pkg但未安装"
        fi
    done

    # 检查和安装libneon
    if ! pkg-config --exists neon; then
        log 1 "安装libneon..."
        sudo apt-get update && sudo apt-get install -y libneon27-dev
    fi
}

# 获取最新版本
function fetch_latest_version() {
    log 1 "获取最新版本..."
    LATEST_VERSION=$(curl -s "$DAVFS2_URL" | grep -oP 'davfs2-\K[0-9.]+(?=\.tar\.gz)' | sort -V | tail -n 1)
    [[ -z "$LATEST_VERSION" ]] && error_exit "无法获取最新版本"
    
    DAVFS2_SOURCE="davfs2-$LATEST_VERSION.tar.gz"
    DAVFS2_SIG="$DAVFS2_SOURCE.sig"
    DAVFS2_DIR="davfs2-$LATEST_VERSION"
}

# 下载和验证
function download_and_verify() {
    log 1 "下载和验证源码..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"

    # 下载源码和签名
    wget -O "$DAVFS2_SOURCE" "$DAVFS2_URL$DAVFS2_SOURCE"
    wget -O "$DAVFS2_SIG" "$DAVFS2_URL$DAVFS2_SIG"

    # 验证签名
    if ! gpg --verify "$DAVFS2_SIG" "$DAVFS2_SOURCE"; then
        error_exit "签名验证失败"
    fi
}

# 备份现有安装
function backup_existing() {
    if [[ -d "$INSTALL_PREFIX/bin/mount.davfs" ]]; then
        log 1 "备份现有安装..."
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_DIR/davfs2_backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
            "$INSTALL_PREFIX/bin/mount.davfs" \
            "$INSTALL_PREFIX/sbin/umount.davfs" \
            "/etc/davfs2"
    fi
}

# 安装函数
function install_davfs2() {
    log 1 "开始安装davfs2 $LATEST_VERSION..."
    
    backup_existing
    download_and_verify

    # 解压和编译
    tar -xzf "$DAVFS2_SOURCE"
    cd "$DAVFS2_DIR"

    ./configure --prefix="$INSTALL_PREFIX" \
        --with-neon="$(pkg-config --variable=prefix neon)" || error_exit "配置失败"
    
    make || error_exit "编译失败"
    sudo make install || error_exit "安装失败"

    # 创建系统用户和组
    if ! getent group davfs2 &>/dev/null; then
        sudo groupadd davfs2
    fi
    if ! id -u davfs2 &>/dev/null; then
        sudo useradd -r -g davfs2 -s /usr/sbin/nologin -d /var/cache/davfs2 davfs2
    fi

    # 设置权限
    sudo chmod u+s "$INSTALL_PREFIX/sbin/mount.davfs"
    sudo chown root:davfs2 "$INSTALL_PREFIX/sbin/mount.davfs"
}

# 卸载函数
function uninstall_davfs2() {
    log 1 "卸载davfs2..."
    
    if [[ ! -d "$DAVFS2_DIR" ]]; then
        cd "$DOWNLOAD_DIR"
        tar -xzf "$DAVFS2_SOURCE"
    fi
    
    cd "$DAVFS2_DIR"
    sudo make uninstall || log 2 "卸载过程出现非致命错误"
    
    # 清理用户和组
    sudo userdel -r davfs2 2>/dev/null || true
    sudo groupdel davfs2 2>/dev/null || true
}

# 清理函数
function clean_up() {
    log 1 "清理临时文件..."
    rm -rf "$DOWNLOAD_DIR"
    log 1 "清理完成"
}

# 主函数
function main() {
    case "$1" in
        install)
            check_prerequisites
            fetch_latest_version
            install_davfs2
            ;;
        uninstall)
            fetch_latest_version
            uninstall_davfs2
            ;;
        clean)
            clean_up
            ;;
        *)
            echo "用法: $0 {install|uninstall|clean}"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"