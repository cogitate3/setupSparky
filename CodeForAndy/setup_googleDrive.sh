#!/bin/bash

# 获取实际用户名
get_real_user() {
  if [ -n "$SUDO_USER" ]; then
    echo "$SUDO_USER"
  elif [ -n "$LOGNAME" ]; then
    echo "$LOGNAME"
  else
    echo "$(whoami)"
  fi
}

# 设置用户相关变量
REAL_USER=$(get_real_user)
USER_HOME=$(eval echo "~$REAL_USER")
MOUNT_POINT="$USER_HOME/google-drive"   # 挂载点目录
RCLONE_CONFIG_NAME="gdrive"            # rclone 配置名称
RCLONE_DOWNLOAD_URL="https://rclone.org/install.sh"  # rclone 安装脚本地址
FUSE_CONF="/etc/fuse.conf"             # FUSE 配置文件

# 检查是否为 root 用户，安装 rclone 和修改 FUSE 配置需要 root 权限
if [ "$(id -u)" -ne 0 ]; then
  echo "请以 root 用户运行该脚本，或使用 sudo 执行。"
  exit 1
fi

# 验证获取到的用户名是否有效
if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
  echo "错误：无法确定实际用户。请使用 'sudo ./setup_googleDrive.sh' 运行此脚本。"
  exit 1
fi

# 检查 rclone 是否已安装
check_rclone_installed() {
  if ! command -v rclone &>/dev/null; then
    echo "rclone 未安装，正在下载并安装 rclone..."
    curl -fsSL "$RCLONE_DOWNLOAD_URL" | bash
    if [ $? -ne 0 ]; then
      echo "rclone 安装失败，请检查网络连接或安装脚本的有效性。"
      exit 1
    fi
    echo "rclone 安装成功。"
  else
    echo "rclone 已安装。"
  fi
}

# 检查 FUSE 配置，确保支持 --allow-other 参数
check_fuse_support() {
  if ! grep -q "^user_allow_other" "$FUSE_CONF"; then
    echo "FUSE 未正确配置为支持 --allow-other 参数。"
    echo "正在尝试自动添加 'user_allow_other' 到 $FUSE_CONF..."
    echo "user_allow_other" >> "$FUSE_CONF"
    if [ $? -eq 0 ]; then
      echo "FUSE 配置已更新，请确保重新启动后生效。"
    else
      echo "无法更新 $FUSE_CONF。请手动编辑该文件，并添加以下内容："
      echo "user_allow_other"
      exit 1
    fi
  else
    echo "FUSE 已正确配置为支持 --allow-other 参数。"
  fi
}

# 配置 Google Drive
configure_rclone() {
  # 检查 rclone 配置文件是否存在
  local config_file="$USER_HOME/.config/rclone/rclone.conf"
  if [ ! -f "$config_file" ]; then
    echo "未找到 rclone 配置文件，将创建新配置..."
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    chown -R "$REAL_USER:$(id -gn $REAL_USER)" "$(dirname "$config_file")"
  fi

  # 检查是否已存在 Google Drive 配置
  if ! su - "$REAL_USER" -c "rclone listremotes" | grep -q "^${RCLONE_CONFIG_NAME}:"; then
    echo "未找到名为 '${RCLONE_CONFIG_NAME}' 的 rclone 配置。"
    echo "请按照以下步骤配置 Google Drive："
    echo "1. 系统将自动启动 rclone 配置工具"
    echo "2. 输入 'n' 创建新的远程配置"
    echo "3. 名称输入 'gdrive'"
    echo "4. 选择 'drive' 作为存储类型（Google Drive）"
    echo "5. 按照提示完成 OAuth 认证"
    echo "6. 其他选项可以保持默认值"
    echo "7. 最后输入 'q' 退出配置"
    echo
    echo "正在启动 rclone 配置工具..."
    sleep 2

    # 使用实际用户身份运行 rclone config
    su - "$REAL_USER" -c "rclone config"
    
    # 验证配置是否成功创建
    if ! su - "$REAL_USER" -c "rclone listremotes" | grep -q "^${RCLONE_CONFIG_NAME}:"; then
      echo "错误：rclone 配置失败，未检测到 ${RCLONE_CONFIG_NAME} 配置。"
      echo "请确保您在配置过程中："
      echo "1. 正确输入了远程名称 '${RCLONE_CONFIG_NAME}'"
      echo "2. 成功完成了 Google OAuth 认证"
      echo "3. 正确保存了配置"
      exit 1
    fi

    # 测试配置是否可用
    echo "正在测试 Google Drive 配置..."
    if ! su - "$REAL_USER" -c "rclone lsd ${RCLONE_CONFIG_NAME}:" &>/dev/null; then
      echo "错误：无法访问 Google Drive。请检查："
      echo "1. 网络连接是否正常"
      echo "2. OAuth 认证是否成功"
      echo "3. Google Drive API 是否启用"
      exit 1
    fi

    echo "Google Drive 配置成功并已验证。"
  else
    echo "已检测到名为 '${RCLONE_CONFIG_NAME}' 的 rclone 配置。"
    # 测试现有配置是否可用
    echo "正在验证现有配置..."
    if ! su - "$REAL_USER" -c "rclone lsd ${RCLONE_CONFIG_NAME}:" &>/dev/null; then
      echo "警告：现有配置可能无效，建议重新配置："
      echo "1. 运行以下命令删除现有配置："
      echo "   su - $REAL_USER -c 'rclone config delete ${RCLONE_CONFIG_NAME}'"
      echo "2. 然后重新运行此脚本"
      exit 1
    fi
    echo "现有配置验证成功。"
  fi
}

# 创建挂载点目录
create_mount_point() {
  if [ ! -d "$MOUNT_POINT" ]; then
    echo "创建挂载点目录: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
    chown "$REAL_USER:$(id -gn $REAL_USER)" "$MOUNT_POINT"  # 确保普通用户拥有该目录的权限
    if [ $? -ne 0 ]; then
      echo "挂载点目录创建失败，请检查目录路径或权限。"
      exit 1
    fi
  else
    echo "挂载点目录已存在: $MOUNT_POINT"
  fi
}

# 挂载 Google Drive
mount_google_drive() {
  if mount | grep -q "$MOUNT_POINT"; then
    echo "Google Drive 已经挂载到 $MOUNT_POINT。"
  else
    echo "正在将 Google Drive 挂载到 $MOUNT_POINT..."
    su - "$REAL_USER" -c "rclone mount ${RCLONE_CONFIG_NAME}: $MOUNT_POINT \
      --vfs-cache-mode writes \
      --allow-other \
      --daemon"
    if [ $? -ne 0 ]; then
      echo "挂载 Google Drive 失败，请检查 rclone 配置或网络连接。"
      exit 1
    fi
    echo "Google Drive 成功挂载到 $MOUNT_POINT。"
    echo "您可以在该目录下访问 Google Drive 文件。"
  fi
}

# 卸载 Google Drive
unmount_google_drive() {
  if mount | grep -q "$MOUNT_POINT"; then
    echo "正在卸载 Google Drive..."
    fusermount -u "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
      echo "Google Drive 已成功卸载。"
    else
      echo "卸载失败，请检查是否有程序正在使用挂载点。"
      exit 1
    fi
  else
    echo "Google Drive 当前未挂载。"
  fi
}

# 重新配置 Google Drive
reconfigure_google_drive() {
  # 先卸载
  unmount_google_drive
  
  # 删除现有配置
  echo "正在删除现有配置..."
  su - "$REAL_USER" -c "rclone config delete ${RCLONE_CONFIG_NAME}"
  
  # 重新配置
  configure_rclone
  create_mount_point
  mount_google_drive
}

# 显示菜单
show_menu() {
  clear
  echo -e "\033[1;36m====== Google Drive 配置工具 ======\033[0m"
  echo
  echo -e "\033[1;33m1. 安装并挂载 Google Drive\033[0m"
  echo -e "\033[1;33m2. 卸载 Google Drive\033[0m"
  echo -e "\033[1;33m3. 重新配置 Google Drive\033[0m"
  echo -e "\033[1;31m0. 退出\033[0m"
  echo
  echo -e "\033[1;37m请输入选项 [0-3]: \033[0m"
}

# 处理菜单选择
handle_menu_choice() {
  local choice=$1
  case $choice in
    1)
      echo "开始安装并挂载 Google Drive..."
      check_rclone_installed
      check_fuse_support
      configure_rclone
      create_mount_point
      mount_google_drive
      echo "操作完成！"
      ;;
    2)
      unmount_google_drive
      ;;
    3)
      reconfigure_google_drive
      ;;
    0)
      echo "退出程序..."
      exit 0
      ;;
    *)
      echo "无效选项，请重新选择。"
      ;;
  esac
  
  # 等待用户按回车继续
  echo
  read -p "按回车键继续..." dummy
}

# 主函数
main() {
  while true; do
    show_menu
    read choice
    handle_menu_choice "$choice"
  done
}

# 执行主函数
main