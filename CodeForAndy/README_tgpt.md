# Setup TGPT Script

一个用于安装和管理终端版 ChatGPT 客户端的 Shell 脚本。

## 功能特点

- 自动安装/更新/卸载 TGPT 终端客户端
- 支持多种系统架构 (x86_64, i386, arm64, armv7l)
- 支持多种操作系统 (Linux, macOS)
- 自动版本检测和更新
- 错误处理和日志记录
- 清理临时文件

## 系统要求

- bash shell
- curl
- sudo 权限 (用于安装到系统目录)

## 安装位置

默认安装到 `/usr/local/bin` 目录

## 使用方法

### 基本命令

```bash
# 安装或更新 TGPT
./setup_tgpt.sh install
# 或直接运行
./setup_tgpt.sh

# 卸载 TGPT
./setup_tgpt.sh uninstall

# 显示帮助信息
./setup_tgpt.sh -h
```

### TGPT 使用示例

安装完成后，可以使用以下命令：

```bash
# 提问
tgpt "你的问题"

# 进入聊天模式
tgpt --chat

# 生成图片
tgpt --image "图片描述"

# 显示更多选项
tgpt -h
```

## 错误处理

- 脚本包含完整的错误处理机制
- 安装失败时会显示详细的错误信息
- 自动清理临时文件
- 验证下载文件的完整性

## 版本控制

- 自动检测本地版本
- 从 GitHub 获取最新版本信息
- 只在有新版本时更新

## 源代码

基于 [chatGPT-shell-cli](https://github.com/0xacx/chatGPT-shell-cli) 项目

## 授权协议

MIT License
