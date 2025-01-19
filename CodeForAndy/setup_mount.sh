#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 或以 root 身份运行此脚本."
    echo "用法: sudo $0 <挂载路径>"
    exit 1
fi

# 检查是否提供了挂载路径参数
if [ -z "$1" ]; then
    echo "使用方法: sudo $0 <挂载路径>"
    exit 1
fi

MOUNT_POINT="$1"

# 确保挂载点目录存在
if [ ! -d "$MOUNT_POINT" ]; then
    echo "创建挂载点目录: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
fi

# 修改 /etc/fuse.conf 以允许其他用户访问 FUSE 文件系统
if ! grep -q "^user_allow_other" /etc/fuse.conf; then
    echo "修改 /etc/fuse.conf 以允许 other 用户访问 FUSE 文件系统"
    echo "user_allow_other" >> /etc/fuse.conf
else
    echo "/etc/fuse.conf 中已包含 user_allow_other"
fi

# 修改 /etc/fstab 文件以自动挂载
FSTAB_ENTRY=".host:/$ $MOUNT_POINT fuse.vmhgfs-fuse allow_other,defaults 0 0"

if ! grep -q "$FSTAB_ENTRY" /etc/fstab; then
    echo "添加挂载配置到 /etc/fstab"
    echo "$FSTAB_ENTRY" >> /etc/fstab
else
    echo "挂载条目已经存在于 /etc/fstab"
fi

# 设置挂载点权限
chown "$(whoami):$(whoami)" "$MOUNT_POINT"
chmod 755 "$MOUNT_POINT"

# 测试 /etc/fstab 的新配置
echo "测试 /etc/fstab 配置..."
if mount -a; then
    echo "挂载成功。"
else
    echo "挂载出现错误！"
    exit 1
fi

echo "所有设置完成！"