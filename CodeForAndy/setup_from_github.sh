#!/bin/bash
# 改进后的日志脚本：默认日志级别改为 INFO(1)，对应绿色输出

# 当前脚本内全局使用的日志文件，若未设置则为空
CURRENT_LOG_FILE=""

# 使用关联数组管理颜色，统一在脚本Global范围定义
declare -A COLORS=(
    ["reset"]="\033[0m"    # 重置颜色
    ["red"]="\033[31m"     # 红色
    ["green"]="\033[32m"   # 绿色
    ["yellow"]="\033[33m"  # 黄色
    ["blue"]="\033[34m"    # 蓝色
    ["bold"]="\033[1m"     # 粗体
)


##############################################################################
# 设置日志文件的函数：检查文件格式、创建父目录、触摸文件并更新全局 CURRENT_LOG_FILE
##############################################################################
set_log_file() {
    local file_path="$1"
    if [ -n "$file_path" ]; then
        # 检查文件名是否以 .log 结尾
        if [[ "$file_path" != *.log ]]; then
            echo -e "${COLORS["red"]}错误：日志文件名必须以 .log 结尾${COLORS["reset"]}"
            return 1
        fi
        # 确保日志文件所在的目录存在
        local dir_path
        dir_path="$(dirname "$file_path")"
        if [ ! -d "$dir_path" ]; then
            mkdir -p "$dir_path"
        fi

        # 创建空的日志文件（如不存在）
        touch "$file_path" 2>/dev/null || {
            echo -e "${COLORS["red"]}错误：无法创建日志文件：$file_path${COLORS["reset"]}"
            return 1
        }

        # 更新全局变量
        CURRENT_LOG_FILE="$file_path"
        return 0
    fi

    echo -e "${COLORS["red"]}错误：未指定日志文件的路径${COLORS["reset"]}"
    return 1
}

##############################################################################
# 核心日志记录函数：可同时输出到控制台（带颜色）和日志文件（纯文本）。
# 参数（共1~3个，使用灵活）：
#   1) file_path (.log结尾) [可选]
#   2) level (0~3，只在指定时生效) [可选]
#   3) message (必需)
# 若只有一个参数，可能是日志文件或日志级别或消息；脚本会自动判断
##############################################################################
function log() {
    # 定义日志级别与对应文本
    declare -A LOG_LEVELS=(
        [0]="DEBUG"   # 调试信息
        [1]="INFO"    # 一般信息
        [2]="WARN"    # 警告信息
        [3]="ERROR"   # 错误信息
    )

    # 定义日志级别对应的颜色
    declare -A LEVEL_COLORS=(
        [0]="reset"   # DEBUG - 默认颜色
        [1]="green"   # INFO - 绿色
        [2]="yellow"  # WARN - 黄色
        [3]="red"     # ERROR - 红色
    )

    # 将默认 level 改为 1 (INFO)，对应绿色
    local file_path=""
    local level=1
    local message=""

    case $# in
        1)
            if [[ "$1" == *.log ]]; then
                # 只有一个参数，且是 .log 结尾 => 文件路径
                file_path="$1"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                # 只有一个参数，且是数字 0-3 => 日志级别
                level="$1"
            else
                # 只有一个参数，既不是 .log 也不是级别 => 日志消息
                message="$1"
            fi
            ;;
        2)
            # 两个参数 => 可能是 (file_path, message) 或 (level, message)
            if [[ "$1" == *.log ]]; then
                file_path="$1"
                message="$2"
            elif [[ "$1" =~ ^[0-3]$ ]]; then
                level="$1"
                message="$2"
            else
                echo -e "${COLORS["red"]}错误：第一个参数必须是 .log 文件或日志级别(0~3)${COLORS["reset"]}"
                return 1
            fi
            ;;
        3)
            # 三个参数 => (file_path, level, message)
            file_path="$1"
            if [[ ! "$file_path" == *.log ]]; then
                echo -e "${COLORS["red"]}错误：文件路径必须以 .log 结尾${COLORS["reset"]}"
                return 1
            fi
            if [[ ! "$2" =~ ^[0-3]$ ]]; then
                echo -e "${COLORS["red"]}错误：日志级别必须是0-3的数字${COLORS["reset"]}"
                return 1
            fi
            level="$2"
            message="$3"
            ;;
        *)
            echo -e "${COLORS["red"]}错误：参数数量必须是1-3个${COLORS["reset"]}"
            return 1
            ;;
    esac

    # 如果取得了 file_path，就尝试设置日志文件
    if [ -n "$file_path" ]; then
        set_log_file "$file_path" || return 1
    fi

    # 如果没显式传入 file_path 且全局也没设置过，就报错
    if [ -z "$file_path" ] && [ -z "$CURRENT_LOG_FILE" ]; then
        echo -e "${COLORS["red"]}错误：没有指定日志文件路径${COLORS["reset"]}"
        return 1
    fi

    # 如果没有传入消息，则警告
    if [ -z "$message" ]; then
        echo -e "${COLORS["red"]}错误：日志消息内容不能为空${COLORS["reset"]}"
        return 1
    fi

    # 取最终要写入的文件
    local final_log_file="${CURRENT_LOG_FILE}"

    # 获取当前时间戳
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # 获取日志级别文本和对应颜色
    local level_text="${LOG_LEVELS[$level]}"
    local color="${LEVEL_COLORS[$level]}"

    # 终端输出（带颜色）
    echo -e "[${timestamp}] [${COLORS[$color]}${level_text}${COLORS["reset"]}] ${COLORS[$color]}${message}${COLORS["reset"]}"

    # 文件输出（纯文本）
    echo "[${timestamp}] [${level_text}] ${message}" >> "$final_log_file"
}

###############################################################################
# 下面四个函数的作用：获取release页面的资源链接,找到最新版本号,下载用正则匹配的那个文件
# 参数说明：
# 
###############################################################################
function get_assets_links() {
  # 检查参数
  if [ $# -ne 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"

  # 使用更可靠的方法提取 owner 和 repo
  local owner_repo=$(echo "$url" | grep -oP 'github\.com/\K[^/]+/[^/]+')
  sudo apt install jq curl wget -y
  # 获取最新版本号，并检查 curl 和 jq 的返回值
  # 这行代码分为几个步骤，我们一步一步来执行：
  # 
  # 第1步：检查最新版本的API是否可访问
  # curl -s：安静模式，不显示进度条
  # -o /dev/null：丢弃返回的内容，我们只关心状态码
  # -w "%{http_code}"：只输出HTTP状态码（比如200表示成功）
  # 最后用grep -q 200检查是否返回200（成功）状态码
  # 
  # 第2步：如果第1步成功（&&），则获取版本号
  # curl -s：再次调用API获取完整信息
  # jq -r：用jq工具解析JSON，-r表示原始输出（不带引号）
  # '.tag_name'：从JSON中提取tag_name字段（这就是版本号）
  # 
  # 把上面的步骤组合成一个命令：
  LATEST_VERSION=$(
    # 第1步：检查API是否可访问
    curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$owner_repo/releases/latest" | grep -q 200 && \
    # 第2步：如果可访问，获取版本号
    curl -s "https://api.github.com/repos/$owner_repo/releases/latest" | jq -r '.tag_name'
  )

  # 举个例子：
  # 如果是获取Visual Studio Code的最新版本
  # 1. 首先检查 https://api.github.com/repos/microsoft/vscode/releases/latest 是否能访问
  # 2. 如果能访问，获取JSON数据并提取版本号（比如 "1.85.0"）
  if [ $? -ne 0 ] || [ -z "$LATEST_VERSION" ]; then
    log 2 "无法获取最新版本号: curl 返回码 $?，版本号: $LATEST_VERSION "
    return 1
  else
    log 2 "最新版本号: $LATEST_VERSION, 获取成功, 但取得的版本号含有v前缀"
  fi

  # 获取所有 assets 的下载链接，并检查 curl 和 jq 的返回值
  local download_links_json=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$owner_repo/releases/latest" | \
  grep -q 200 && curl -s "https://api.github.com/repos/$owner_repo/releases/latest" | \
  jq -r '.assets[] | .browser_download_url')

  if [ $? -ne 0 ] || [ -z "$download_links_json" ]; then
    log 2 "无法获取下载链接: curl 返回码 $?，链接: $download_links_json 为空，但得到了最新版本号：$LATEST_VERSION "
    return 1
  fi

  # 使用 jq 解析 JSON 数组，并循环输出
  DOWNLOAD_LINKS=()
  readarray -t DOWNLOAD_LINKS <<< "$download_links_json"

  if (( ${#DOWNLOAD_LINKS[@]} == 0 )); then
    log 2 "没有找到任何下载链接"
    return 0 # 警告，但不是错误
  fi


  log 1 "最新版本: $LATEST_VERSION " # 输出最新版本号，以v开头
  log 1 "所有最新版本的资源下载链接:"
  for link in "${DOWNLOAD_LINKS[@]}"; do
    log 1 "- $link"
  done

}


function get_download_link() {
  # 检查参数
  if [ $# -lt 1 ]; then
    log 3 "参数错误: 需要提供release页面的访问链接"
    return 1
  fi

  local url="$1"
  get_assets_links "$url" >/dev/null 2>&1
  
  # 访问参数1的页面，找到规律，写一个正则表达式匹配规则，作为第二个参数，比如".*linux-[^/]*\.deb$"
  # 用chatgpt生成匹配规则
  local regex="$2"  
  # 如果参数2为空，则输出找到的最新版本号
  # 如果参数2不为空，参数2为正则表达式，函数输出匹配的下载链接；
  # 输入参数2时，不要加两边的双引号
  if [ -z "$regex" ]; then
    get_assets_links "$url" >/dev/null 2>&1
    # log 1 "未提供匹配规则，输出获取的远程最新版本号: $LATEST_VERSION "
    # log 1 "LATEST_VERSION 这个变量的值来自 get_assets_links 函数"
    # log 1 "获得全局变量 LATEST_VERSION 的值必须执行一次这个函数"

    return 0
  fi

  # 检查 DOWNLOAD_LINKS 是否为空
  if [ -z "$DOWNLOAD_LINKS" ]; then
    log 3 "未找到资源链接，匹配代码无法运行"
    return 1
  fi

  # 声明一个数组来存储匹配的链接
  declare -a MATCHED_LINKS=()

  # 遍历数组中的每个链接
  for link in "${DOWNLOAD_LINKS[@]}"; do
      log 1 "Checking link: $link" >/dev/null 2>&1 # Log each link being checked
      if [[ "$link" =~ $regex ]]; then
      # =~ 是正则表达式匹配操作符
      # 左边是要测试的字符串
      # 右边是正则表达式模式
          MATCHED_LINKS+=("$link")
          # += 是数组追加操作符
          # 将新元素添加到数组末尾
          # 保持原有元素不变
          log 1 "匹配到: $link"
      else
          log 2 "不匹配: $link"
      fi
  done

  # 显示匹配结果统计
  log 1 "共找到 ${#MATCHED_LINKS[@]} 个匹配的下载链接"

  # Check if a download link was found
  if [ ${#MATCHED_LINKS[@]} -eq 0 ]; then
      log 3 "没有找到合适的下载链接,请检查正则表达式参数"
      return 1
  fi

  # 选择第一个匹配的下载链接
  DOWNLOAD_URL="${MATCHED_LINKS[0]}"
  log 1 "Found matching download link，适配的最新版的下载链接是: "
  log 1 "$DOWNLOAD_URL"

  return 0
}

# 过程函数：统一检查软件是否已安装的函数
# 返回0表示已安装，返回1表示未安装
check_if_installed() {
    local package_name="$1"
    
    # 检查常见的包管理器
    if dpkg -l | grep -q "^ii\s*$package_name"; then
        return 0
    fi
    
    if snap list 2>/dev/null | grep -q "^$package_name "; then
        return 0
    fi
    
    if flatpak list 2>/dev/null | grep -q "$package_name"; then
        return 0
    fi
    
    # 最后检查命令是否存在
    if command -v "$package_name" &> /dev/null; then
        return 0
    fi
    
    return 1
}

function install_package() {
    local download_link="$1"
    local max_retries=3
    local retry_delay=5
    local timeout=30
    local retry_count=0
    local success=false
    
    # 下载文件:
    # -f: 失败时不输出错误页面
    # -S: 显示错误信息
    # -L: 跟随重定向
    # --progress-bar: 显示下载进度条
    # --fail-early: 在错误时尽早失败

    local tmp_dir="/tmp/downloads"
    mkdir -p "$tmp_dir"
    
    log 1 "开始下载: ${download_link}..."
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -fSL --progress-bar --fail-early \
            --connect-timeout $timeout \
            --retry $max_retries \
            --retry-delay $retry_delay \
            -o "$tmp_dir/$(basename "$download_link")" \
            "${download_link}"; then
            success=true
            log 1 "下载成功"
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log 2 "下载失败，${retry_delay}秒后进行第$((retry_count + 1))次重试..."
                sleep $retry_delay
            else
                log 3 "下载失败，已达到最大重试次数"
                return 1
            fi
        fi
    done

    if [ "$success" = true ]; then
        # 提取文件名
        local filename=$(basename "$download_link")
        local need_cleanup=true
        local install_status=0
        
        # ${filename##*.} extracts the file extension:
        # ## removes the longest matching pattern (everything up to the last dot)
        # Example: for "package.tar.gz", this gives "gz"
        case "${filename##*.}" in
            deb)
                log 1 "安装 $filename..."
                if sudo dpkg -i "$tmp_dir/$filename"; then # dpkg -i 不需要联网
                    log 2 "$filename 安装成功"
                else
                    log 2 "首次安装失败，尝试修复依赖..."
                    if sudo apt-get install -f -y; then # apt-get install -f -y 需要联网
                        log 2 "依赖修复成功，重试安装"
                        if sudo dpkg -i "$tmp_dir/$filename"; then
                            log 2 "安装成功"
                        else
                            log 3 "安装失败"
                            install_status=1
                        fi
                    else
                        log 3 "依赖修复失败"
                        install_status=1
                    fi
                fi
                ;;
            gz|tgz)
                if [[ "$filename" == *.tar.gz || "$filename" == *.tgz ]]; then
                    log 1 "下载的文件是压缩包: $filename，无法使用apt或者dpkg安装，需要手动安装"
                    install_status=2
                    ARCHIVE_FILE="$tmp_dir/$filename"
                    need_cleanup=false  # 保留文件供后续使用
                    install_status=2    # 需要手动安装
                    log 2 "文件已保存到: $ARCHIVE_FILE，请手动完成安装"
                    return $install_status
                fi
                ;;
            *)
                log 3 "不支持的文件类型: ${filename##*.}"
                install_status=1
                ;;
        esac
        
        # 根据需要清理文件
        if [ "$need_cleanup" = true ]; then
            log 1 "清理下载的文件..."
            rm -f "$tmp_dir/$filename"
        fi
        
        return $install_status
    else
        log 3 "下载失败"
        install_status=1
        return $install_status
    fi
}

function detect_desktop_environment() {
    # 首先检查当前会话类型
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        echo "${XDG_CURRENT_DESKTOP^^}" # 转换为大写
        return
    fi

    # 备用检测方法
    if [[ -n "$KDE_FULL_SESSION" ]]; then
        echo "KDE"
    elif [[ -n "$GNOME_DESKTOP_SESSION_ID" ]]; then
        echo "GNOME"
    elif [[ -n "$MATE_DESKTOP_SESSION_ID" ]]; then
        echo "MATE"
    elif [[ "$DESKTOP_SESSION" == "xfce" ]]; then
        echo "XFCE"
    else
        echo "UNKNOWN"
    fi
}

###############################################################################
# 函数名称：010add_autostart_app
# 函数作用：
#   将指定应用添加到自动启动，适配不同桌面环境
#
# 参数说明：
#   $1 : 显示名称 (Name=)
#   $2 : 完整可执行命令 (Exec=)
#   $3 : 是否最小化 (yes|no)
#   $@ : 其余参数将追加到 Exec 行
###############################################################################
function add_autostart_app() {
    local display_name="$1"
    local exec_cmd="$2"
    local minimize_flag="$3"
    shift 3
    local exec_args=("$@")

    # 获取 XDG 配置目录
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local sanitized_name="${display_name// /_}"
    local desktop_file="${autostart_dir}/${sanitized_name}.desktop"

    # 检测当前桌面环境
    local current_de=$(detect_desktop_environment)

    #-------------------------
    # 基础输入验证
    #-------------------------
    if [[ -z "$display_name" || -z "$exec_cmd" || -z "$minimize_flag" ]]; then
        echo "[ERROR] 参数不足。用法："
        echo "       add_autostart_app <显示名称> <完整可执行命令> <yes|no> [参数...]"
        return 1
    fi

    if [[ "$minimize_flag" != "yes" && "$minimize_flag" != "no" ]]; then
        echo "[ERROR] 第三个参数仅允许 yes 或 no"
        return 1
    fi

    # 命令检查
    if [[ "$exec_cmd" == /* ]]; then
        if [[ ! -x "$exec_cmd" ]]; then
            echo "[WARNING] 指定路径不存在或没有执行权限：$exec_cmd"
        fi
    elif ! command -v "$exec_cmd" >/dev/null 2>&1; then
        echo "[WARNING] 命令 $exec_cmd 不在PATH中，可能无法正常启动。"
    fi

    #-------------------------
    # 创建autostart目录
    #-------------------------
    if [[ ! -d "$autostart_dir" ]]; then
        mkdir -p "$autostart_dir" || {
            echo "[ERROR] 无法创建目录：$autostart_dir"
            return 2
        }
    fi

    #-------------------------
    # 构造 Exec 命令
    #-------------------------
    local exec_line="$exec_cmd"
    
    # 根据不同桌面环境添加最小化参数
    if [[ "$minimize_flag" == "yes" ]]; then
        case "$current_de" in
            "KDE")
                # KDE Plasma 使用窗口规则更可靠，但这里仍然添加通用参数
                exec_args+=("--minimize")
                ;;
            "GNOME")
                # GNOME 可以使用 gtk-launch 包装
                if command -v gtk-launch >/dev/null 2>&1; then
                    exec_line="gtk-launch $exec_cmd"
                fi
                ;;
            *)
                # 通用方案：尝试常见的最小化参数
                exec_args+=("--minimize" "--minimized" "-m")
                ;;
        esac
    fi

    # 添加其他参数
    for arg in "${exec_args[@]}"; do
        exec_line+=" \"$arg\""
    done

    #-------------------------
    # 写入 .desktop 文件
    #-------------------------
    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        echo "Type=Application"
        echo "Name=$display_name"
        echo "Exec=$exec_line"
        echo "Comment=Autostart entry for $display_name"
        echo "Terminal=false"
        echo "X-GNOME-Autostart-enabled=true"
        
        # 根据桌面环境添加特定配置
        case "$current_de" in
            "KDE")
                if [[ "$minimize_flag" == "yes" ]]; then
                    echo "X-KDE-AutostartMinimized=true"
                fi
                ;;
            "GNOME")
                # GNOME特定配置（如果有）
                ;;
            "XFCE")
                # XFCE特定配置（如果有）
                ;;
        esac

        # 通用标准字段
        echo "StartupNotify=true"
    } > "$desktop_file"

    # 设置权限
    chmod +x "$desktop_file"

    #-------------------------
    # 确认结果
    #-------------------------
    if [[ -f "$desktop_file" ]]; then
        echo "[INFO] 已创建自启动条目：$desktop_file"
        echo "[INFO] 当前桌面环境：$current_de"
        echo "[INFO] 执行命令：$exec_line"
        if [[ "$minimize_flag" == "yes" ]]; then
            echo "[INFO] 已尝试配置最小化启动（实际效果取决于应用程序和桌面环境支持）"
        fi
        return 0
    else
        echo "[ERROR] 创建失败：$desktop_file"
        return 3
    fi
}

###############################################################################
# 函数名称：toggle_autostart_app
# 函数作用：
#   启用或禁用指定的自启动条目（freedesktop.org 标准实现）
###############################################################################
function toggle_autostart_app() {
    local name="$1"
    local action="$2"
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local sanitized_name="${name// /_}"
    local desktop_file="${autostart_dir}/${sanitized_name}.desktop"

    # 参数验证
    if [[ -z "$name" || -z "$action" ]]; then
        echo "[ERROR] 参数不足。用法："
        echo "       toggle_autostart_app <显示名称> <enable|disable>"
        return 1
    fi

    if [[ "$action" != "enable" && "$action" != "disable" ]]; then
        echo "[ERROR] 无效的操作类型。必须是 'enable' 或 'disable'"
        return 1
    fi

    # 检查文件是否存在
    if [[ ! -f "$desktop_file" ]]; then
        local found_file=$(grep -l "^Name=$name$" "$autostart_dir"/*.desktop 2>/dev/null)
        if [[ -n "$found_file" ]]; then
            desktop_file="$found_file"
        else
            echo "[ERROR] 未找到自启动条目：$name"
            return 2
        fi
    fi

    # 创建临时文件
    local temp_file=$(mktemp)
    if [[ ! -f "$temp_file" ]]; then
        echo "[ERROR] 无法创建临时文件"
        return 3
    fi

    # 修改配置（使用标准的 freedesktop.org 字段）
    local modified=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^X-GNOME-Autostart-enabled= ]]; then
            echo "X-GNOME-Autostart-enabled=$([[ "$action" == "enable" ]] && echo "true" || echo "false")"
            modified=true
        elif [[ "$line" =~ ^Hidden= ]]; then
            echo "Hidden=$([[ "$action" == "enable" ]] && echo "false" || echo "true")"
            modified=true
        else
            echo "$line"
        fi
    done < "$desktop_file" > "$temp_file"

    # 如果没找到相关字段，添加标准字段
    if [[ "$modified" == "false" ]]; then
        echo "X-GNOME-Autostart-enabled=$([[ "$action" == "enable" ]] && echo "true" || echo "false")" >> "$temp_file"
        echo "Hidden=$([[ "$action" == "enable" ]] && echo "false" || echo "true")" >> "$temp_file"
    fi

    # 替换原文件
    if mv "$temp_file" "$desktop_file"; then
        chmod +x "$desktop_file"
        echo "[INFO] 已${action == "enable" ? "启用" : "禁用"}自启动条目：$name"
        return 0
    else
        echo "[ERROR] 更新文件失败：$desktop_file"
        rm -f "$temp_file"
        return 3
    fi
}

###############################################################################
# 函数名称：list_autostart_apps
# 函数作用：
#   列出所有自启动条目（freedesktop.org 标准实现）
###############################################################################
function list_autostart_apps() {
    local autostart_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    local current_de=$(detect_desktop_environment)

    # 检查目录是否存在
    if [[ ! -d "$autostart_dir" ]]; then
        echo "[ERROR] 自启动目录不存在：$autostart_dir"
        return 1
    fi

    # 检查是否有.desktop文件
    local desktop_files=("$autostart_dir"/*.desktop)
    if [[ ! -e "${desktop_files[0]}" ]]; then
        echo "[INFO] 没有找到任何自启动条目"
        return 0
    fi

    # 打印环境信息
    echo "当前桌面环境: $current_de"
    echo "自启动目录: $autostart_dir"
    
    # 打印表头
    printf "\n%-30s %-40s %-10s %-20s\n" "名称" "执行命令" "状态" "类型"
    echo "--------------------------------------------------------------------------------"

    # 遍历所有.desktop文件
    for file in "${desktop_files[@]}"; do
        if [[ -f "$file" ]]; then
            local name=""
            local exec=""
            local enabled="启用"
            local type="Application"
            
            # 读取文件内容
            while IFS='=' read -r key value; do
                case "$key" in
                    "Name") name="$value" ;;
                    "Exec") exec="$value" ;;
                    "Type") type="$value" ;;
                    "X-GNOME-Autostart-enabled")
                        [[ "$value" == "false" ]] && enabled="禁用"
                        ;;
                    "Hidden")
                        [[ "$value" == "true" ]] && enabled="禁用"
                        ;;
                esac
            done < "$file"

            # 截断过长的值
            [[ ${#name} -gt 28 ]] && name="${name:0:25}..."
            [[ ${#exec} -gt 38 ]] && exec="${exec:0:35}..."

            # 打印信息
            printf "%-30s %-40s %-10s %-20s\n" "$name" "$exec" "$enabled" "$type"
        fi
    done

    echo "--------------------------------------------------------------------------------"
    echo "共找到 ${#desktop_files[@]} 个自启动条目"
    return 0
}

# 通用的GitHub软件安装/卸载函数
# 用法1（安装）: setup_from_github <github_url> <download_regex> [install] <package_name>
# 用法2（卸载）: setup_from_github uninstall <package_name>
function setup_from_github() {
    local github_url=""
    local download_regex=""
    local operation="install"
    local package_name=""
    
    # 参数解析
    case $# in
        2)
            # 如果第一个参数是 uninstall，则只需要包名
            if [ "$1" = "uninstall" ]; then
                operation="uninstall"
                package_name="$2"
            else
                log 3 "参数错误。卸载用法: setup_from_github uninstall <package_name>"
                return 1
            fi
            ;;
        3|4)
            # 完整参数模式
            github_url="$1"
            download_regex="$2"
            if [ $# -eq 4 ]; then
                operation="$3"
                package_name="$4"
            else
                package_name="$3"
            fi
            ;;
        *)
            log 3 "参数错误。用法："
            log 3 "安装: setup_from_github <github_url> <download_regex> [install] <package_name>"
            log 3 "卸载: setup_from_github uninstall <package_name>"
            return 1
            ;;
    esac

    # 卸载操作
    if [ "$operation" = "uninstall" ]; then
        log 1 "检查是否已安装 $package_name"
        if ! check_if_installed "$package_name"; then
            log 1 "$package_name 未安装，无需卸载"
            return 0
        fi

        if sudo apt purge -y "$package_name"; then
            log 2 "$package_name 卸载成功"
            # 清理依赖
            sudo apt autoremove -y
            return 0
        else
            log 3 "$package_name 卸载失败"
            return 1
        fi
    fi

    # 安装操作需要验证必要参数
    if [ -z "$github_url" ] || [ -z "$download_regex" ] || [ -z "$package_name" ]; then
        log 3 "安装时缺少必要参数"
        log 3 "用法: setup_from_github <github_url> <download_regex> [install] <package_name>"
        return 1
    fi

    # 检查是否已安装
    if check_if_installed "$package_name"; then
        # 获取本地版本
        local local_version=$(dpkg -l | grep "^ii\s*$package_name" | awk '{print $3}')
        log 1 "$package_name 已安装，本地版本: $local_version"
        
        # 获取远程版本
        get_download_link "$github_url"
        local remote_version=${LATEST_VERSION#v}
        log 1 "远程最新版本: $remote_version"
        
        # 比较版本号
        if [[ "$local_version" == *"$remote_version"* ]]; then
            log 2 "$package_name 已经是最新版本"
            return 0
        fi
        log 2 "发现新版本，开始更新..."
    else
        log 1 "未找到 $package_name，开始下载安装"
    fi
    
    # 获取下载链接
    get_download_link "$github_url" "$download_regex"
    local download_url=${DOWNLOAD_URL}
    
    if [ -z "$download_url" ]; then
        log 3 "无法获取下载链接"
        return 1
    fi
    
    # 下载并安装包
    install_package "$download_url"
    
    # 验证安装结果
    if check_if_installed "$package_name"; then
        log 2 "$package_name 安装完成"
        return 0
    else
        log 3 "$package_name 安装失败"
        return 1
    fi
}

log "$HOME/logs/$(basename "$0").log" 1 "第一条消息，同时设置日志文件到$HOME/logs/$(basename "$0").log"
log "~/.log.log" 1 "开始安装"
# setup_from_github "https://github.com/pot-app/pot-desktop/releases" ".*amd64.*\.deb$" "install" "pot"
# log "~/.log.log" 1 "开始安装"
setup_from_github "uninstall" "pot"