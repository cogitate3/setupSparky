# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误处理函数
handle_error() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 警告函数
show_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 成功信息函数
show_success() {
    echo -e "${GREEN}成功: $1${NC}"
}

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
        exit 1
    fi
}

# 更安全的用户检测函数
get_real_user_info() {
    # 优先使用SUDO_USER，因为这个变量准确反映了执行sudo的原始用户
    if [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        # 如果没有SUDO_USER（直接以root登录的情况），使用当前登录用户
        REAL_USER=$(who | awk '{print $1}' | head -n1)
        REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    fi

    # 验证获取的信息
    if [ -z "$REAL_USER" ] || [ -z "$REAL_HOME" ]; then
        echo -e "${RED}错误: 无法确定实际用户信息${NC}"
        exit 1
    fi

    echo -e "${BLUE}实际用户: $REAL_USER${NC}"
    echo -e "${BLUE}用户主目录: $REAL_HOME${NC}"
}

# 检查桌面环境
check_desktop_environment() {
    # 检测是否有图形环境
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        echo -e "${RED}错误: 未检测到图形环境${NC}"
        exit 1
    fi
    
    # 获取当前桌面环境
    local current_de="$XDG_CURRENT_DESKTOP"
    echo -e "${BLUE}当前桌面环境: $current_de${NC}"
    
    # 检查是否支持XDG标准
    if [ ! -d "$XDG_CONFIG_HOME" ]; then
        echo -e "${RED}警告: 系统可能不完全遵循XDG标准${NC}"
        read -p "是否继续？[y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}操作已取消${NC}"
            exit 1
        fi
    fi
}

# 带有重试的git clone函数
function git_clone_with_retry {
    local repo_url=$1
    local target_dir=$2
    local max_attempts=3
    local retry_delay=5

    # 检查目标目录是否存在且非空
    if [ -d "$target_dir" ] && [ "$(ls -A $target_dir)" ]; then
        echo -e "${BLUE}目标目录 $target_dir 已存在且非空，正在删除...${NC}"
        rm -rf "$target_dir"
    fi

    local counter=0
    until [ "$counter" -ge $max_attempts ]
    do
        git clone "$repo_url" "$target_dir" && break
        counter=$((counter+1))
        if [ "$counter" -eq $max_attempts ]; then
            echo -e "${RED}Failed to clone $repo_url after $max_attempts attempts. Aborting.${NC}"
            return 1
        fi
        echo -e "${RED}git clone failed, retrying in $retry_delay seconds...${NC}"
        sleep $retry_delay
    done
    
    return 0
}

# 安装必要的包并检查安装结果
install_packages() {
    echo -e "${GREEN}检查并安装必要的软件包...${NC}"
    
    # 创建要安装的包列表
    local packages=(
        "fcitx5"
        "fcitx5-rime"
        "fcitx5-chinese-addons"
        "fcitx5-frontend-gtk2"
        "fcitx5-frontend-gtk3"
        "fcitx5-frontend-qt5"
        "fcitx5-module-cloudpinyin"
        "qt5-style-plugins"
        "zenity"
        "fcitx5-module-lua"
        "fcitx5-material-color"
        "fonts-noto-cjk"
        "fonts-noto-color-emoji"
        "git"
        "curl"
    )

    # 需要安装的包列表
    local packages_to_install=()
    # 已安装的包列表
    local already_installed=()
    # 安装失败的包列表
    local failed_packages=()

    # 检查每个包的安装状态
    echo -e "${BLUE}检查已安装的软件包...${NC}"
    for package in "${packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii\s\+$package\s"; then
            already_installed+=("$package")
        else
            packages_to_install+=("$package")
        fi
    done

    # 显示已安装的包
    if [ ${#already_installed[@]} -ne 0 ]; then
        echo -e "${GREEN}以下软件包已安装，将跳过：${NC}"
        for package in "${already_installed[@]}"; do
            echo -e "${GREEN}✓ $package${NC}"
        done
    fi

    # 如果有需要安装的包
    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${BLUE}即将安装以下软件包：${NC}"
        for package in "${packages_to_install[@]}"; do
            echo -e "${BLUE}→ $package${NC}"
        done

        echo -e "${GREEN}开始安装缺失的软件包...${NC}"
        for package in "${packages_to_install[@]}"; do
            echo -e "${BLUE}正在安装 $package...${NC}"
            if ! apt install -y --install-recommends "$package"; then
                failed_packages+=("$package")
                echo -e "${RED}安装 $package 失败${NC}"
            else
                echo -e "${GREEN}安装 $package 成功${NC}"
            fi
        done
    else
        echo -e "${GREEN}所有必要的软件包都已安装${NC}"
        return 0
    fi

    # 检查是否有安装失败的包
    if [ ${#failed_packages[@]} -ne 0 ]; then
        echo -e "${RED}错误: 以下包安装失败：${NC}"
        for package in "${failed_packages[@]}"; do
            echo -e "${RED}✗ $package${NC}"
        done
        echo -e "${RED}请检查系统包管理器状态和网络连接后重试${NC}"
        echo -e "${BLUE}您可以尝试手动安装失败的包：${NC}"
        echo -e "${BLUE}sudo apt install ${failed_packages[*]}${NC}"
        return 1
    fi

    echo -e "${GREEN}所有必要的包安装完成${NC}"
    return 0
}

# 检查必要的命令
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found. Installing..."
        if ! sudo apt install -y "$2"; then
            handle_error "Failed to install $2"
        fi
    fi
}

# 检查必要的命令
check_command "wget" "wget"
check_command "unzip" "unzip"
check_command "fc-cache" "fontconfig"

# 提示重启
prompt_restart() {
    echo -e "${RED}重要: 需要重启系统才能使更改生效${NC}"
    read -p "是否现在重启系统？[y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}系统将在5秒后重启...${NC}"
        sleep 5
        reboot
    else
        echo -e "${BLUE}请记得稍后重启系统以使更改生效${NC}"
    fi
}

# 过程函数：检查和安装依赖的函数
check_and_install_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    # 检查每个依赖是否已安装
    for dep in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii\s*$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    # 如果有缺失的依赖，尝试安装它们
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log 1 "安装缺失的依赖: ${missing_deps[*]}"
        if ! sudo apt update; then
            log 3 "更新软件包列表失败"
            return 1
        fi
        if ! sudo apt install -y "${missing_deps[@]}"; then
            log 3 "安装依赖失败: ${missing_deps[*]}"
            return 1
        fi
        log 1 "依赖安装成功"
    else
        log 1 "所有依赖已满足"
    fi
    return 0
}

# 过程函数：检查deb包依赖的函数，对于下载的deb包
check_deb_dependencies() {
    local deb_file="$1"
    
    # 检查文件是否存在
    if [ ! -f "$deb_file" ]; then
        log 3 "deb文件不存在: $deb_file"
        return 1
    fi
    
    # 获取依赖列表
    log 1 "检查 $deb_file 的依赖..."
    local deps=$(dpkg-deb -f "$deb_file" Depends | tr ',' '\n' | sed 's/([^)]*)//g' | sed 's/|.*//g' | tr -d ' ')
    
    # 显示依赖
    log 1 "包含以下依赖:"
    echo "$deps" | while read -r dep; do
        if [ ! -z "$dep" ]; then
            log 1 "- $dep"
        fi
    done
    
    # 检查并安装依赖
    if ! check_and_install_dependencies $deps; then
        log 3 "依赖安装失败"
        return 1
    fi
    
    return 0
}

get_assets_links() {
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

# 过程函数：统一获取软件版本的函数
get_package_version() {
    local package_name="$1"
    local version_command="$2"
    
    if [ -n "$version_command" ]; then
        # 如果提供了特定的版本命令，使用它
        eval "$version_command"
    else
        # 默认使用dpkg获取版本
        dpkg -l "$package_name" 2>/dev/null | grep "^ii" | awk '{print $3}'
    fi
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

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="${COLORS[$level]:-${COLORS[INFO]}}"

    if [[ $QUIET -eq 0 ]] || [[ "$level" == "ERROR" ]]; then
        echo -e "${color}[$level] [$timestamp] $message${COLORS[RESET]}" | tee -a "$LOG_FILE"
    fi

    [[ "$level" == "ERROR" ]] && >&2 echo -e "${color}[$level] $message${COLORS[RESET]}"
}

# 错误处理函数
error_handler() {
    local line=$1
    local command=$2
    local code=$3
    log "ERROR" "脚本执行失败 [行 $line]: 命令 '$command' 返回错误码 $code"
    exit $code
}

# 清理函数
cleanup() {
    log "DEBUG" "清理临时文件..."
    rm -rf "$TEMP_DIR"
    [[ $VERBOSE -eq 1 ]] && log "DEBUG" "临时目录已删除: $TEMP_DIR"
}

# 确认操作函数
confirm_action() {
    local prompt="$1"
    local answer
    
    if [[ $FORCE -eq 1 ]]; then
        return 0
    fi

    if [[ $QUIET -eq 1 ]]; then
        return 1
    fi

    while true; do
        read -r -p "$prompt [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO]|"")
                return 1
                ;;
            *)
                echo "请输入 yes 或 no"
                ;;
        esac
    done
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 检查依赖
check_dependencies() {
    # 定义依赖关系：包名和对应的命令
    declare -A pkg_commands=(
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["tar"]="tar"
        ["fontconfig"]="fc-cache"
        ["p7zip-full"]="7z"
    )
    
    local missing_deps=()

    # 检查每个依赖
    for pkg in "${!pkg_commands[@]}"; do
        local cmd="${pkg_commands[$pkg]}"
        if ! check_command "$cmd"; then
            missing_deps+=("$pkg")
        fi
    done

    # 安装缺失的依赖
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "WARN" "安装缺失的依赖: ${missing_deps[*]}"
        if ! sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"; then
            log "ERROR" "依赖安装失败"
            return 1
        fi
    fi
    
    return 0
}

# 初始化环境
init_environment() {
    log "INFO" "初始化环境..."

    mkdir -p "$FONT_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    if ! check_dependencies; then
        log "ERROR" "环境初始化失败"
        return 1
    fi

    log "INFO" "环境初始化完成"
    return 0
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local progress=$((current * width / total))
    
    if [[ $QUIET -eq 0 ]]; then
        printf "\r[%-${width}s] %d%%" \
               "$(printf '%*s' "$progress" '' | tr ' ' '#')" \
               $((current * 100 / total))
        [[ $current -eq $total ]] && echo
    fi
}

# 解压文件
extract_archive() {
    local file="$1"
    local target_dir="$2"

    mkdir -p "$target_dir" || {
        log "ERROR" "无法创建解压目标目录: $target_dir"
        return 1
    }

    local file_type=$(file -b --mime-type "$file")
    log "DEBUG" "文件类型: $file_type"

    case "$file_type" in
        application/zip)
            unzip -q "$file" -d "$target_dir" ;;
        application/x-tar|application/x-gtar)
            tar -xf "$file" -C "$target_dir" ;;
        application/x-xz)
            tar -xJf "$file" -C "$target_dir" ;;
        application/x-7z-compressed)
            7z x "$file" -o"$target_dir" >/dev/null ;;
        application/x-font-ttf|application/x-font-otf|application/octet-stream)
            cp "$file" "$target_dir/" ;;
        *)
            log "ERROR" "不支持的文件类型: $file_type"
            return 1 ;;
    esac

    log "INFO" "解压完成: $file -> $target_dir"
    return 0
}

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Check sudo privileges
check_sudo() {
    if ! sudo -v &>/dev/null; then
        error_exit "This script requires sudo privileges. Please run with sudo or grant sudo access."
    fi
    
    # Keep sudo alive
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

# Check dependencies function
check_dependencies() {
    local missing_deps=()
    for cmd in curl grep sed chmod sudo; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
}

# Get real user when script is run with sudo
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    elif [ -n "$USER" ]; then
        echo "$USER"
    else
        error_exit "Could not determine the real user"
    fi
}

# Get real user's home directory
get_real_home() {
    local real_user
    real_user=$(get_real_user)
    local home_dir
    
    if [ "$real_user" = "root" ]; then
        error_exit "This script should not be run as the root user directly. Please use 'sudo' instead."
    fi
    
    home_dir=$(getent passwd "$real_user" | cut -d: -f6)
    if [ -z "$home_dir" ]; then
        error_exit "Could not determine home directory for user $real_user"
    fi
    
    echo "$home_dir"
}


# Function to update shell config files
update_shell_configs() {
    # ...
    # List of supported shell config files
    local shell_configs=("$real_home/.bashrc" "$real_home/.zshrc")

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            if [[ "$action" == "add" ]]; then
                if ! grep -q "source $env_file" "$config"; then
                    # Use real user to modify their own config files
                    sudo -u "$real_user" tee -a "$config" >/dev/null <<< "source $env_file"
                    updated=true
                fi
            fi
            # ...
        fi
    done
}
