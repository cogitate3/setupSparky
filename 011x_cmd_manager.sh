#!/bin/bash

# x-cmd 安装或卸载函数
x_cmd_manager() {
    local action=$1

    case "$action" in
        install)
            echo "开始安装 x-cmd..."

            # 检查系统是否安装 curl 或 wget
            if command -v curl > /dev/null; then
                echo "使用 curl 下载并安装 x-cmd..."
                eval "$(curl -fsSL https://get.x-cmd.com)"
            elif command -v wget > /dev/null; then
                echo "使用 wget 下载并安装 x-cmd..."
                eval "$(wget -qO- https://get.x-cmd.com)"
            else
                echo "错误：系统未安装 curl 或 wget，请先安装其中之一再重试。"
                return 1
            fi

            # 添加加载代码到 .bashrc 和 .zshrc
            echo "为 bash 和 zsh 添加加载代码..."
            local load_cmd='[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X"'
            if ! grep -q "$load_cmd" ~/.bashrc; then
                echo "$load_cmd" >> ~/.bashrc
            fi
            if ! grep -q "$load_cmd" ~/.zshrc; then
                echo "$load_cmd" >> ~/.zshrc
            fi

            echo "x-cmd 安装完成！请重新启动终端以加载环境。"
            ;;

        uninstall)
            echo "开始卸载 x-cmd..."

            # 从 .bashrc 和 .zshrc 中移除加载代码
            echo "移除 .bashrc 和 .zshrc 中的 x-cmd 加载代码..."
            sed -i '/\.x-cmd\.root/d' ~/.bashrc
            sed -i '/\.x-cmd\.root/d' ~/.zshrc

            # 提示用户退出所有 x-cmd 相关 shell 实例
            echo "建议退出所有加载了 x-cmd 的 shell 实例以避免潜在问题。"

            # 删除 $HOME/.x-cmd.root 文件夹
            read -p "是否立即删除 $HOME/.x-cmd.root 文件夹？ (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                echo "删除 $HOME/.x-cmd.root 文件夹..."
                rm -rf "$HOME/.x-cmd.root"
                echo "$HOME/.x-cmd.root 文件夹已删除。"
            else
                echo "跳过删除 $HOME/.x-cmd.root 文件夹。"
                echo "您可以稍后通过运行 'rm -rf ~/.x-cmd.root' 手动删除。"
            fi

            echo "x-cmd 卸载完成！"
            ;;

        *)
            echo "无效操作：$action"
            echo "使用方法：x_cmd_manager install 或 x_cmd_manager uninstall"
            ;;
    esac
}

# 示例调用：
# x_cmd_manager install
# x_cmd_manager uninstall
