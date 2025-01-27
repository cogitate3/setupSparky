#!/bin/bash

# 检查是否以 root 权限运行
if [[ $EUID -ne 0 ]]; then
  echo "请以 root 权限运行此脚本 (sudo $0)"
  exit 1
fi

# 检测并安装 open-vm-tools
if ! command -v vmhgfs-fuse &>/dev/null; then
  echo "未检测到 open-vm-tools，正在尝试安装..."

  # 更新软件包列表
  if ! sudo apt-get update; then
    echo "更新软件包列表失败！请检查网络连接。"
    exit 1
  fi

  # 根据桌面环境选择安装包
  if [ -n "$DISPLAY" ]; then
    PKG="open-vm-tools-desktop"
  else
    PKG="open-vm-tools"
  fi

  if ! sudo apt-get install -y "$PKG"; then
    echo "安装 $PKG 失败！请手动安装 open-vm-tools。"
    exit 1
  fi
  echo "open-vm-tools 安装完成。"
fi

# 确保 fuse.conf 允许 user_allow_other
if ! grep -q "^user_allow_other" /etc/fuse.conf; then
  echo "启用 user_allow_other 选项..."
  sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf || \
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf >/dev/null
fi

# 检查并加载 fuse 模块
if ! lsmod | grep -q fuse; then
  sudo modprobe fuse || { echo "加载 fuse 模块失败！"; exit 1; }
fi

# 创建挂载目录并设置权限
MOUNT_DIR="/mnt/hgfs"
sudo mkdir -p "$MOUNT_DIR"
sudo chmod 1777 "$MOUNT_DIR"  # 允许所有用户读写，通过粘滞位防止删除他人文件

# 挂载共享文件夹（询问用户权限选项）
echo "请选择挂载方式："
select OPTION in "允许所有用户访问" "仅限当前用户"; do
  case $OPTION in
    "允许所有用户访问")
      MOUNT_OPTS="allow_other,umask=000"
      break ;;
    "仅限当前用户")
      MOUNT_OPTS="uid=$(id -u),gid=$(id -g)"
      break ;;
    *) echo "无效选择，请重试。" ;;
  esac
done

sudo vmhgfs-fuse -o "$MOUNT_OPTS" .host:/ "$MOUNT_DIR" || {
  echo "挂载失败！请检查 VMware 共享文件夹设置。"
  exit 1
}



# 设置开机自动挂载
echo "是否设置开机自动挂载？"
select CHOICE in "是" "否"; do
  case $CHOICE in
    "是")
      # 确保 fuse 模块开机加载
      if ! grep -q "^fuse" /etc/modules; then
        echo "fuse" | sudo tee -a /etc/modules >/dev/null
      fi

      # 更新 fstab（添加 nofail 防止启动阻塞）
      FSTAB_ENTRY=".host:/ $MOUNT_DIR fuse.vmhgfs-fuse $MOUNT_OPTS,nofail 0 0"
      if ! grep -q "$MOUNT_DIR" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null || {
          echo "更新 /etc/fstab 失败！请手动添加："
          echo "$FSTAB_ENTRY"
          exit 1
        }
      fi
      echo "已设置开机自动挂载。"
      break ;;
    "否")
      echo "已跳过开机自动挂载。"
      break ;;
    *) echo "无效选择，请重试。" ;;
  esac
done

# 测试挂载配置
sudo mount -a && echo "共享文件夹配置成功！" || {
  echo "挂载测试失败！请检查配置。"
  exit 1
}

# 挂载共享文件夹（原代码部分）
sudo vmhgfs-fuse -o "$MOUNT_OPTS" .host:/ "$MOUNT_DIR" || {
  echo "挂载失败！请检查 VMware 共享文件夹设置。"
  exit 1
}

# 新增功能：在桌面创建快捷方式
create_desktop_shortcut() {
  # 获取当前用户信息
  local REAL_USER=${SUDO_USER:-$USER}
  local USER_HOME=$(eval echo ~$REAL_USER)

  # 检测常见的桌面目录位置
  local DESKTOP_DIRS=(
    "$USER_HOME/Desktop"
    "$USER_HOME/Desktop"
    "$(xdg-user-dir DESKTOP 2>/dev/null)"
  )

  # 查找有效的桌面目录
  for DESKTOP_DIR in "${DESKTOP_DIRS[@]}"; do
    if [[ -d "$DESKTOP_DIR" ]]; then
      local SHORTCUT_PATH="$DESKTOP_DIR/Shared_Folders"
      
      # 删除已存在的旧链接或文件
      if [[ -e "$SHORTCUT_PATH" ]]; then
        sudo -u $REAL_USER rm -rf "$SHORTCUT_PATH" || return 1
      fi
      
      # 创建符号链接并设置权限
      if sudo -u $REAL_USER ln -s "$MOUNT_DIR" "$SHORTCUT_PATH" 2>/dev/null; then
        echo "已在桌面创建快捷方式：$SHORTCUT_PATH"
        return 0
      fi
    fi
  done

  echo "未找到桌面目录，跳过创建快捷方式。"
  return 0
}

# 询问是否创建桌面快捷方式
echo "是否在桌面创建共享文件夹快捷方式？"
select CHOICE in "是" "否"; do
  case $CHOICE in
    "是")
      create_desktop_shortcut || {
        echo "快捷方式创建失败！请手动创建链接："
        echo "ln -s $MOUNT_DIR ~/Desktop/Shared_Folders"
      }
      break ;;
    "否")
      echo "已跳过创建快捷方式。"
      break ;;
    *) echo "无效选择，请重试。" ;;
  esac
done

exit 0