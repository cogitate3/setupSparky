#!/bin/bash

# Source the setup_from_github.sh file to use its functions
source "$(dirname "$0")/setup_from_github.sh"

# Set up logging
log "$HOME/logs/$(basename "$0").log" 1 "Starting installation of pot, anfysearch, and geany"



# Install pot-app (a translation tool)
log 1 "Installing pot-app..."
setup_from_github "https://github.com/pot-app/pot-desktop/releases" ".*amd64.*\.deb$" "install" "pot"

# Install anfysearch (a search tool)
log 1 "Installing anfysearch..."
setup_from_github "https://github.com/anfy-tech/anfysearch/releases" ".*amd64.*\.deb$" "install" "anfysearch"

# Install geany (a text editor)
log 1 "Installing geany..."
apt-get update
apt-get install -y geany

log 1 "Installation completed!"

setup_from_github "https://github.com/wavetermdev/waveterm/releases" "-amd64.*\.deb$" "install" "waveterm"

setup_from_github "https://github.com/hovancik/stretchly/releases" ".*amd64\.deb$" "install" "stretchly"

setup_from_github "https://github.com/amir1376/ab-download-manager/releases" ".*linux_x64.*\.deb$" "install" "ab-download-manager"

setup_from_github "https://github.com/localsend/localsend/releases" ".*linux-x86-64.*\.deb$" "install" "localsend"

setup_from_github "https://github.com/Eugeny/tabby/releases" ".*linux-x64.*\.deb$" "install" "tabby"


https://software.opensuse.org//download.html?project=home%3Acboxdoerfer&package=fsearch#manualDebian