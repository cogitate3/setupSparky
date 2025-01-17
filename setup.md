# SparkyLinux 安装后配置脚本使用说明

本脚本用于在 SparkyLinux 安装完成后进行系统优化和常用软件安装。

## 使用方法

1. 确保有 root 权限运行脚本：

```bash
git clone https://github.com/cogitate3/setupSparkyLinux.git
cd setupSparkyLinux
sudo bash./901afterLinuxInstall.sh
```

2. 脚本会显示一个交互式菜单，包含以下几个主要类别：

![安装菜单](https://raw.githubusercontent.com/alt369/picgo/main/202501161907286.png)

### 桌面系统增强必备

- Plank：美观的快捷启动器
- Angrysearch：类似 Everything 的快速文件搜索工具
- Pot-desktop：翻译工具
- Geany：轻量级文本编辑器
- Stretchly：定时提醒休息的工具
- AB Download Manager：下载管理器
- LocalSend：局域网文件传输工具
- SpaceFM/Krusader：双面板文件管理器
- Konsole：KDE 终端模拟器

### 桌面系统进阶常用

- Tabby：可同步的终端模拟器
- Warp Terminal：现代化终端
- Telegram：即时通讯软件
- Brave：浏览器
- VLC：多媒体播放器
- Windsurf：IDE 开发工具
- PDF Arranger：PDF 页面编辑器

### 命令行工具

- Neofetch：系统信息显示
- Micro：命令行文本编辑器
- Cheat.sh：命令示例查询工具
- Eg：另一个命令示例工具
- Eggs：系统备份工具

### 系统工具和平台

- Snap：Ubuntu 的软件包管理系统
- Flatpak：通用软件包管理系统
- Homebrew：包管理器
- Docker & Docker-compose：容器化平台

## 功能特点

1. 每个软件都提供安装和卸载选项
2. 自动检查并安装依赖
3. 自动检查已安装版本
4. 支持版本更新
5. 详细的日志记录（保存在 /tmp/logs/ 目录）

## 注意事项

1. 部分软件安装可能需要较长时间，请耐心等待
2. 建议在安装前确保系统已更新到最新状态
3. 某些软件可能需要额外的系统配置，请按照提示进行操作
4. 如遇到问题，可查看日志文件了解详细信息

## 常见问题

1. 如果安装失败，请检查：

   - 网络连接是否正常
   - 系统更新是否完整
   - 是否有足够的磁盘空间

2. 如果软件运行异常，可以：
   - 尝试卸载后重新安装
   - 检查日志文件排查问题
   - 确认系统依赖是否满足

## 反馈与支持

如遇到问题或需要帮助，请提交 issue 或通过相关渠道反馈。
