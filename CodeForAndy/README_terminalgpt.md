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
- sudo 权限 (用于系统级安装)

## 详细的使用说明和示例

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
# 启动 TerminalGPT 交互模式
terminalgpt

# 直接提问（非交互模式）
terminalgpt "你的问题"

# 查看帮助信息
terminalgpt --help

# 使用系统代理
terminalgpt --proxy "http://your-proxy:port"

# 设置 OpenAI API Key
export OPENAI_API_KEY="your-api-key"

# 使用别名简化命令（安装后自动配置）
tgpt "你的问题"
```

### 常用功能：

- 支持交互式对话
- 支持直接命令行提问
- 支持代理设置
- 支持 API Key 配置
- 提供简化的命令别名

## 错误处理机制

### 错误处理特点：

1. 完整的错误捕获和处理
2. 安装失败时自动回滚
3. 详细的错误日志输出
4. 彩色提示信息便于识别问题

### 主要错误处理功能：

- 备份文件管理
- 权限检查和提示
- 配置文件冲突处理
- 安装失败恢复机制

### 错误提示：

- 使用彩色输出区分错误级别
- 提供详细的错误原因说明
- 给出解决建议和操作指导
