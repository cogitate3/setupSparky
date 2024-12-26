# Sparky Linux 安装配置

一键安装脚本，用于设置和自定义 Sparky Linux 7.5（或其他基于 Debian Bookworm 的发行版）。

## 概述

本项目旨在通过自动化安装常用软件和配置，简化全新 Linux 安装的过程。该脚本使用 Bash 编写，专为 Sparky Linux 定制，但也足够灵活，可用于其他基于 Debian Bookworm 的发行版，如 MX Linux 和 Linux Mint。

## 项目动机

我开发这个项目的主要目的是在解决个人需求（简化轻量级 Linux 系统的安装）的同时学习 Bash 语言。

为了充分利用我的旧电脑，我探索了轻量级、资源效率高的 Linux 桌面系统。通过 [DistroWatch.com](https://distrowatch.com/)，我测试了几乎所有排名前 20 的发行版，并发现了 Linux 实时模式的强大功能。实时模式对于初始系统测试非常有价值，我也注意到 Linux 桌面体验这些年来有了显著提升，现在已经能达到 Windows 系统约 90%的可用性。

### 探索历程

为了更方便地尝试不同的系统，我接触到了 [Ventoy](https://ventoy.net/)，这是一个改变游戏规则的工具。使用 Ventoy，我可以将数十个 Linux 发行版复制到单个 USB 驱动器上，随时按需启动任何系统。这种方法使我能够绕过典型 Windows 电脑的限制，在不改变硬盘的情况下访问文件和使用硬件。

后来，我想知道这种自由是否也能扩展到 Windows。经过一些研究，我发现了 **Windows To Go**，它使我能够直接从高速 USB 驱动器安装和运行 Windows。这成为了我主要的 Windows 设置，并坚定了我对便携式操作系统的热情。

### 脚本的灵感来源

在使用官方 Linux 发行版时，我希望有一种快速安装我喜欢的软件的方法。这激发了我学习 Bash 编程来创建一键安装脚本的兴趣。虽然多年来进展缓慢，但这个想法一直存在。

最近，在 **windsurf**、编程参考资料和各种 AI 助手的帮助下，我终于在一周的专注努力后完成了这个脚本的 0.3 版本。调试过程充满挑战——AI 工具有时会引入一些需要手动纠正的细微问题。最终，我在最后的调试阶段禁用了 windsurf 的自动完成功能以确保准确性。

该脚本包含大量注释，既帮助我学习，也为其他探索 Bash 的人提供参考。

## 功能特点

- 通过单个命令安装基本软件和依赖项
- 专为 Sparky Linux 设计，但可适用于其他基于 Debian Bookworm 的系统
- 包含详细注释，便于学习

## 系统要求

- 基于 Debian Bookworm 的 Linux 发行版（如 Sparky Linux、MX Linux 或 Linux Mint）
- Bash shell（大多数 Linux 发行版的默认 shell）

## 使用方法

1. 克隆此仓库：

   ```bash
   git clone https://github.com/cogitate3/setupSparkyLinux.git
   cd setupSparkyLinux
   ```

2. 运行安装脚本：

   ```bash
   bash 901afterLinuxInstall.sh
   ```

3. 按照屏幕上的说明完成安装。

## 未来计划

- 测试并优化脚本，使其适用于其他基于 Debian 的发行版
- 继续提升 Bash 编程技能并改进脚本功能

## 贡献

欢迎贡献、反馈和建议！请随时提出问题或提交拉取请求。

## 许可证

本项目采用 GPL-3.0 许可证。详情请参见 LICENSE 文件。

## 致谢

**特别感谢 [Emer Chen](https://sourceforge.net/u/ldsemerchen/profile/)**，这位热心的兄弟向我介绍了 Sparky Linux，并耐心回答了我这个 Linux 新手的各种初学者问题。Emer Chen 定制的 [Live Debian System (Debian Respin)](https://sourceforge.net/projects/antix-mate-respin/) 非常用户友好，具有完整的本地化、吸引人的界面，并预装了许多实用的应用程序。

**衷心感谢这些令人惊叹的工具和平台**，它们让我们作为开发者和用户的生活变得更加轻松：

- **[devv.ai](https://devv.ai/)**：程序员的福音。只需输入你的错误，答案就会迎面而来。如此简单！

- **[ChatGPT-Next-Web](https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web)**：有了这个开源项目，你可以自行部署 OpenAI 的 API，灵活地管理和使用 AI 服务。

- **[chatgpt.com](https://chatgpt.com/)**：无所不知的终极助手。它能回答你能想到的所有问题。

- **[Claude.ai](https://claude.ai/new)**：在编程方面，Claude 真的很专业，能提供一些可靠的解决方案。

- **Grok-beta**：有了这个便捷工具，不用再担心处理蹩脚的英语了。

这些工具和平台共同让技术挑战变得轻而易举，前所未有地提升了我们的效率。感谢它们的存在，让我们的工作和学习体验更加顺畅和高效！

## 下一步计划：

- [x] 一键安装配置 zsh 及其插件和界面美化
- 一键配置 mount webdav 远程文件夹
- 一键安装中文输入法
- 测试并优化脚本，使其适配 Mx Linux， Mint Linux 发行版
