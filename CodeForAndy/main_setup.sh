#!/bin/bash

# 定义颜色
BOLD_ORANGE='\033[1;33m'  # 粗体橙色
GREEN='\033[0;32m'        # 绿色
YELLOW='\033[0;33m'       # 黄色
RESET='\033[0m'           # 重置颜色

# 打印菜单标题，标题行前添加一个空行
print_title() {
  echo
  echo -e "${BOLD_ORANGE}## $1${RESET}"
}

# 打印菜单项 (软件名称为黄色，描述为绿色)
print_item() {
  local name=$(echo "$1" | awk -F '：' '{print $1}')  # 提取冒号前的软件名称
  local desc=$(echo "$1" | awk -F '：' '{print $2}')  # 提取冒号后的描述
  echo -e "${YELLOW}$name：${GREEN}$desc${RESET}"
}

# 打印“一键安装”项，没有空行
print_install_all() {
  echo -e "${BOLD_ORANGE}$1${RESET}"
}

# 打印“退出”项
print_exit() {
  echo -e "${BOLD_ORANGE}$1${RESET}"
}

# 显示菜单
display_menu() {
  clear  # 清屏
  echo
  print_title "中文系统必装"
  print_item "01. 中文字体与字体管理：确保系统支持中文显示和最佳的中文输入法"
  print_item "02. rime输入法：最快速的中文输入法，安装程序会自动配置雾凇输入法"
  print_item "03. wps办公：比微软office快，功能接近90%的office办公套件"
  print_install_all "09. 一键安装上述软件"

  print_title "终端增强工具"
  print_item "10. Zsh和Oh My Zsh：功能强大的终端Shell，和Zsh的增强框架，提供丰富主题插件支持"
  print_item "11. Neofetch：显示系统信息的终端工具，适合展示配置"
  print_item "12. Btop：实时系统监控工具，支持CPU、内存和网络信息"
  print_item "13. Micro：轻量级终端文本编辑器，支持多种语法高亮"
  print_item "14. Cheat.sh：命令行下的代码速查工具，支持多种语言"
  print_item "15. eg：提供详细命令示例的学习工具"
  print_install_all "19. 一键安装上述软件"

  print_title "优化桌面体验"
  print_item "21. Plank：轻量级桌面启动器，支持快速访问常用应用"
  print_item "22. AngrySearch：快速搜索本地文件的高效工具"
  print_item "23. UTools：多功能效率工具，支持插件扩展"
  print_item "24. Pot：支持截图翻译的多接口翻译工具"
  print_item "25. Stretchly：专注时间管理工具，提醒用户定时休息"
  print_item "26. FSearch：快速本地文件搜索工具，界面简洁高效"
  print_item "27. Geany：轻量级的跨平台文本编辑器，支持快速开发"
  print_install_all "29. 一键安装上述软件"

  print_title "尝试不同终端"
  print_item "31. Wave：强烈推荐的AI增强终端工具，提升效率的同时支持自然语言命令"
  print_item "32. Terminator：支持多窗口分割，自定义右键快捷输入命令的Linux终端模拟器"
  print_item "33. Alacritty：跨平台高性能终端，支持GPU加速渲染"
  print_item "34. Tabby：支持SSH和多标签页及插件的现代终端模拟器"
  print_item "35. Warp：AI驱动的终端，自动补全和命令建议功能"
  print_install_all "39. 一键安装上述软件"

  print_title "拥抱智能工具"
  print_item "41. Tgpt：无需API的命令行AI助手，安装简单易用，在终端中体验AI"
  print_item "42. TerminalGPT：脚本功能强大的AI命令行工具，后期可配置API"
  print_item "43. ChatGPT-Shell-CLI：支持API的智能命令行助手，需手动配置脚本"
  print_item "44. windsurf：由Codeium推出的AI驱动代码编辑器，编程利器"
  print_install_all "49. 一键安装上述软件"

  print_title "提升效率必备"
  print_item "51. brave：一款内置广告拦截器和跟踪器阻止功能的浏览器，兼容Chrome的插件，多平台同步"
  print_item "52. telegram：即时通讯工具，支持多平台同步，方便与朋友和团队沟通"
  print_item "53. localsend：局域网文件传输工具，快速分享文件，无需互联网连接"
  print_item "54. pdfarranger：PDF文件编辑工具，支持合并、分割和重新排列页面"
  print_item "55. openaitranslator：基于AI的翻译工具，提供高质量的多语言翻译服务"
  print_item "56. chatbox：一个人工智能客户端应用程序和智能助理，它兼容许多先进的 AI 模型和 API"
  print_item "57. eggs：一个系统备份工具，像企鹅下蛋生企鹅一样，支持将系统备份为可安装的iso"
  print_install_all "59. 一键安装上述软件"

  print_title "无穷尽软件库"
  print_item "61. Docker和Docker Compose：容器化平台，简化部署和开发流程，多容器的编排和运行工具"
  print_item "62. Snap：现代化的Linux软件包管理工具。"
  print_item "63. Flatpak：跨发行版的软件打包和运行工具。"
  print_item "64. Homebrew：macOS和Linux的包管理工具。"
  print_install_all "69. 一键安装上述软件"

  print_title "99. 一键安装上述所有软件"


  
  print_exit "    0. 退出"
  echo 
}

# 处理用户输入
handle_choice() {
  read -p "请输入你的选择: " choice
  case $choice in
    0) echo -e "${BOLD_ORANGE}退出程序...${RESET}"; exit 0 ;;
    01) echo "正在安装中文字体与字体管理..." ;;
    02) echo "正在安装rime输入法..." ;;
    03) echo "正在安装wps办公..." ;;
    09) echo "正在一键安装中文系统必装软件..." ;;
    # 可以继续添加更多选项处理逻辑
    99) echo "正在一键安装所有软件..." ;;
    *) echo "无效选择，请重新输入。" ;;
  esac
  sleep 2  # 暂停 2 秒以便用户查看输出
}

# 主程序循环
while true; do
  display_menu  # 显示菜单
  handle_choice # 处理用户输入
done