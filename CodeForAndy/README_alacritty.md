# Alacritty 终端安装脚本

## 基本功能和特点

- 自动化安装/卸载 Alacritty 终端
- 自动配置和管理依赖项
- 安装 JetBrains Mono 编程字体
- 支持配置文件的自动下载和安装
- 提供完整的安装步骤追踪和回滚机制
- 自动检测系统兼容性
- 支持多种 Linux 发行版
- 提供彩色日志输出

## 源代码引用和授权信息

- 作者：CodeParetoImpove cogitate3 Claude.ai
- 版本：1.3
- 开源协议：MIT License

## 系统要求

### 必需的系统依赖：

- wget
- unzip
- fontconfig (fc-cache)
- git
- curl
- tar
- rustc
- cargo

### 支持的操作系统：

- Linux 发行版（基于 Debian/Ubuntu/Fedora 等）
- 需要 bash shell 环境

## 详细的使用说明和示例

### 基本用法：

```bash
# 安装 Alacritty
./setup_alacritty.sh install

# 卸载 Alacritty
./setup_alacritty.sh uninstall
```

### 安装过程包括：

1. 系统兼容性检查
2. 依赖项检查和安装
3. JetBrains Mono 字体安装
4. Alacritty 配置文件下载和配置
5. 验证安装结果

### 配置文件位置：

- Alacritty 配置文件将被安装到用户主目录的适当位置
- 字体将被安装到系统字体目录

## 错误处理机制

### 完整的错误处理系统：

- 安装步骤追踪
- 失败时自动回滚
- 详细的错误日志
- 清理临时文件

### 错误处理特点：

1. 每个安装步骤都有对应的回滚操作
2. 安装失败时自动执行回滚
3. 提供彩色错误输出便于识别问题
4. 保留详细的错误日志供故障排查

### 常见问题处理：

- 依赖缺失自动提示安装
- 配置文件下载失败提供备用方案
- 权限问题提供明确的错误提示
- 系统不兼容时提供详细说明
