# SparkyLinux Post-Installation Configuration Script Guide

This script is designed for system optimization and common software installation after SparkyLinux installation.

## Usage

1. Ensure you have root privileges to run the script:

```bash
git clone https://github.com/cogitate3/setupSparkyLinux.git
cd setupSparkyLinux
sudo bash ./901afterLinuxInstall.sh
```

2. The script will display an interactive menu with the following main categories:

![Installation Menu](https://raw.githubusercontent.com/alt369/picgo/main/202501161907286.png)

### Essential Desktop System Enhancements

- Plank: Beautiful quick launcher
- Angrysearch: Fast file search tool similar to Everything
- Pot-desktop: Translation tool
- Geany: Lightweight text editor
- Stretchly: Break time reminder tool
- AB Download Manager: Download manager
- LocalSend: LAN file transfer tool
- SpaceFM/Krusader: Dual-panel file manager
- Konsole: KDE Terminal Emulator

### Advanced Desktop System Applications

- Tabby: Synchronizable terminal emulator
- Warp Terminal: Modern terminal
- Telegram: Instant messaging software
- Brave: Browser
- VLC: Multimedia player
- Windsurf: IDE development tool
- PDF Arranger: PDF page editor

### Command Line Tools

- Neofetch: System information display
- Micro: Command line text editor
- Cheat.sh: Command example query tool
- Eg: Another command example tool
- Eggs: System backup tool

### System Tools and Platforms

- Snap: Ubuntu's package management system
- Flatpak: Universal package management system
- Homebrew: Package manager
- Docker & Docker-compose: Containerization platform

## Features

1. Installation and uninstallation options for each software
2. Automatic dependency checking and installation
3. Automatic installed version checking
4. Version update support
5. Detailed logging (saved in /tmp/logs/ directory)

## Important Notes

1. Some software installations may take longer, please be patient
2. It's recommended to update your system to the latest state before installation
3. Some software may require additional system configuration, please follow the prompts
4. If you encounter issues, check the log files for detailed information

## Common Issues

1. If installation fails, check:

   - Network connection status
   - System update completeness
   - Available disk space

2. If software runs abnormally, you can:
   - Try uninstalling and reinstalling
   - Check log files for troubleshooting
   - Verify system dependencies are met

## Feedback and Support

If you encounter problems or need help, please submit an issue or provide feedback through related channels.