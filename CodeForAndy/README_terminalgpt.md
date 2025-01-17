# TerminalGPT 安装脚本

## 基本功能和特点

- 自动化安装/卸载 TerminalGPT 终端
- 自动备份和恢复 shell 配置文件
- 自动配置环境变量和别名
- 支持多种 shell 环境
- 提供备份文件管理和清理
- 彩色输出界面提示
- 完整的错误处理机制

## 源代码引用和授权信息

- 作者：CodeParetoImpove cogitate3 Claude.ai
- 源代码：https://github.com/adamyodinsky/TerminalGPT
- 版本：1.3
- 开源协议：MIT License

## 系统要求

### 支持的 Shell 环境：

- bash
- zsh
- 其他兼容的 POSIX shell

### 系统依赖：

- git (用于克隆源代码)
- curl 或 wget (用于下载)

## terminalgpt 的使用说明和示例

### 基本用法：

```bash
# 安装 TerminalGPT
./setup_terminalgpt.sh install

# 卸载 TerminalGPT
./setup_terminalgpt.sh uninstall
```

### 安装过程包括：

1. 自动备份现有 shell 配置
2. 创建必要的目录结构
3. 配置环境变量
4. 设置命令别名
5. 验证安装结果

### 配置说明：

- 自动备份配置文件到指定备份目录
- 定期清理旧的备份文件
- 支持自定义别名配置

### TerminalGPT 使用说明：

```bash
# 查看帮助信息
terminalgpt -h
terminalgpt --help

# 配置 API Key
terminalgpt install

# 使用别名简化命令（安装后自动配置）,开始一段对话
gptn

# 问一个问题即退出
gpnto "你的问题"
```

### 常用功能：

- 支持交互式对话
- 支持直接命令行提问
- 支持 API Key 配置
- 提供简化的命令别名
