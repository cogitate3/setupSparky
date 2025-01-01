#!/bin/bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo"
else
  sudoCmd=""
fi

#copied & modified from atrandys trojan scripts
#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
  release="centos"
  systemPackage="yum"
  #colorEcho ${RED} "unsupported OS"
  #exit 0
elif cat /etc/issue | grep -Eqi "debian|SparkyLinux"; then
  # grep 是一个文本搜索工具，用于在输入中查找匹配的文本。
  # -E 选项启用扩展正则表达式，使得可以使用更复杂的匹配模式。
  # -q 选项使 grep 在找到匹配项时不输出结果，只返回退出状态（0 表示找到匹配项，1 表示未找到）。
  # -i 选项使搜索不区分大小写。
  # "debian|SparkyLinux" 正则表达式匹配包含 "debian" 或 "SparkyLinux" 的文本。
  release="debian"
  systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release="ubuntu"
  systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
  systemPackage="yum"
  #colorEcho ${RED} "unsupported OS"
  #exit 0
elif cat /proc/version | grep -Eqi "debian"; then
  release="debian"
  systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release="ubuntu"
  systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
  systemPackage="yum"
  #colorEcho ${RED} "unsupported OS"
  #exit 0
fi

# install requirements
${sudoCmd} ${systemPackage} update -q
${sudoCmd} ${systemPackage} install curl wget jq lsof coreutils unzip -y -qq

check_if_running_as_root() {
  # If you want to run as another user, please modify $EUID to be owned by this user
  if [[ "$EUID" -ne '0' ]]; then
    echo "error: You must run this script as root!"
    exit 1
  fi
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        lscpu | grep -q "Little Endian" && MACHINE='mips64le'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
     elif [[ "$(type -P emerge)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
      PACKAGE_MANAGEMENT_REMOVE='emerge -Cv'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}




# ——————————————————————————————以下是用chatgpt-4o优化的部分代码————————————————————————————

#!/bin/bash

# Check if the script is running as root or add sudo dynamically
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo" # Non-root user, enable sudo
else
  sudoCmd=""     # Root user, no sudo required
fi

# Function: Detect the operating system and package manager
detect_os_and_package_manager() {
  local os_release_file="/etc/os-release"
  local issue_file="/etc/issue"
  local proc_version_file="/proc/version"

  if [[ -f /etc/redhat-release ]]; then
    # CentOS or RHEL-based systems
    release="centos"
    systemPackage="yum"
  elif [[ -f $os_release_file ]]; then
    # Modern distributions use /etc/os-release
    source $os_release_file
    case "$ID" in
      debian)
        release="debian"
        systemPackage="apt-get"
        ;;
      ubuntu)
        release="ubuntu"
        systemPackage="apt-get"
        ;;
      linuxmint)
        release="linuxmint"
        systemPackage="apt-get"
        ;;
      sparkylinux)
        release="sparkylinux"
        systemPackage="apt-get"
        ;;
      mx)
        release="mxlinux"
        systemPackage="apt-get"
        ;;
      centos | rhel)
        release="centos"
        systemPackage="yum"
        ;;
      arch)
        release="arch"
        systemPackage="pacman"
        ;;
      manjaro)
        release="manjaro"
        systemPackage="pacman"
        ;;
      opensuse* | suse)
        release="suse"
        systemPackage="zypper"
        ;;
      fedora)
        release="fedora"
        systemPackage="dnf"
        ;;
      *)
        echo "Warning: Unsupported Linux distribution detected: $ID"
        release="unknown"
        systemPackage="unknown"
        ;;
    esac
  elif grep -Eqi "debian" $issue_file || grep -Eqi "debian" $proc_version_file; then
    # Fallback for Debian-based systems
    release="debian"
    systemPackage="apt-get"
  elif grep -Eqi "ubuntu" $issue_file || grep -Eqi "ubuntu" $proc_version_file; then
    # Fallback for Ubuntu systems
    release="ubuntu"
    systemPackage="apt-get"
  elif grep -Eqi "centos|red hat|redhat" $issue_file || grep -Eqi "centos|red hat|redhat" $proc_version_file; then
    # Fallback for CentOS or RHEL-based systems
    release="centos"
    systemPackage="yum"
  else
    echo "Error: Unable to determine the operating system."
    release="unknown"
    systemPackage="unknown"
    return 1
  fi
}

# Call the function to detect OS and package manager
detect_os_and_package_manager

# Output detected system information
echo "========================================"
echo "Detected Operating System: $release"
echo "Using Package Manager: $systemPackage"
echo "========================================"

# Optional: Add further actions based on OS detection
if [[ "$release" == "unknown" ]]; then
  echo "Error: Unsupported or undetected operating system. Exiting."
  exit 1
fi

# Example: Perform an update command
echo "Running a sample package manager update command..."
if [[ "$systemPackage" != "unknown" ]]; then
  $sudoCmd $systemPackage update -y
else
  echo "Warning: Package manager not detected. Cannot update packages."
fi

