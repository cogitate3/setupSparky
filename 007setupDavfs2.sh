#!/bin/bash

# One-click script for installing and uninstalling the latest version of davfs2

set -e

DAVFS2_URL="https://download.savannah.gnu.org/releases/davfs2/"
INSTALL_PREFIX="/usr/local"
NEON_LIB=""
NEON_HEADERS=""
DOWNLOAD_DIR="/tmp/download"

# Source the logging functions
source 001log2File.sh

# Set log file
log "/tmp/logs/007.log" 1 "Starting davfs2 installation script"

function check_prerequisites() {
  log 1 "Checking prerequisites..."
  if ! command -v gcc &>/dev/null; then
    log 3 "GCC is required but not installed. Install GCC and try again."
    exit 1
  fi

  if ! command -v make &>/dev/null; then
    log 3 "Make is required but not installed. Install Make and try again."
    exit 1
  fi

  if ! command -v tar &>/dev/null; then
    log 3 "Tar is required but not installed. Install Tar and try again."
    exit 1
  fi

  if ! dpkg-query -W -f='${Status}' libneon27 2>/dev/null | grep -q "install ok installed" || \
     ! dpkg-query -W -f='${Status}' libneon27-dev 2>/dev/null | grep -q "install ok installed"; then
    log 1 "libneon or its development headers are required but not found. Installing libneon and its development headers..."
    sudo apt-get update
    sudo apt-get install -y libneon27 libneon27-dev
  else
    log 1 "libneon and its development headers are already installed."
  fi

  if ! command -v wget &>/dev/null; then
    log 3 "wget is required but not installed. Install wget and try again."
    exit 1
  fi

  if ! command -v curl &>/dev/null; then
    log 3 "curl is required but not installed. Install curl and try again."
    exit 1
  fi

  log 1 "All prerequisites met."
}

function fetch_latest_version() {
  log 1 "Fetching the latest version of davfs2..."
  LATEST_VERSION=$(curl -s $DAVFS2_URL | grep -oP 'davfs2-\K[0-9.]+(?=\.tar\.gz)' | sort -V | tail -n 1)

  if [[ -z "$LATEST_VERSION" ]]; then
    log 3 "Failed to determine the latest version of davfs2."
    exit 1
  fi

  log 1 "Latest version is $LATEST_VERSION."
  DAVFS2_SOURCE="davfs2-$LATEST_VERSION.tar.gz"
  DAVFS2_DIR="davfs2-$LATEST_VERSION"
}

function download_source() {
  log 1 "Downloading davfs2 $LATEST_VERSION..."
  
  # Create download directory if it doesn't exist
  mkdir -p "$DOWNLOAD_DIR"
  cd "$DOWNLOAD_DIR"

  if [[ -f $DAVFS2_SOURCE ]]; then
    log 1 "$DAVFS2_SOURCE already exists. Skipping download."
  else
    wget -O $DAVFS2_SOURCE "$DAVFS2_URL$DAVFS2_SOURCE"
  fi
}

function install_davfs2() {
  log 1 "Installing davfs2 $LATEST_VERSION..."

  fetch_latest_version
  download_source

  tar -xzf $DAVFS2_SOURCE
  cd $DAVFS2_DIR

  log 1 "Running configure script..."
  ./configure --prefix=$INSTALL_PREFIX ${NEON_LIB:+--with-neon=$NEON_LIB} ${NEON_HEADERS:+--with-neon=$NEON_HEADERS}

  log 1 "Building the source..."
  make

  log 1 "Installing the program..."
  sudo make install

  log 1 "Creating system user and group 'davfs2'..."
  if ! id -u davfs2 &>/dev/null; then
    sudo useradd -r -s /usr/sbin/nologin -d /var/cache/davfs2 davfs2
  fi

  if ! getent group davfs2 &>/dev/null; then
    sudo groupadd davfs2
  fi

  log 1 "Installation completed."
  cd ..
}

function uninstall_davfs2() {
  log 1 "Uninstalling davfs2..."

  fetch_latest_version

  if [[ ! -d $DAVFS2_DIR ]]; then
    log 3 "$DAVFS2_DIR not found. Please extract the source package and try again."
    exit 1
  fi

  cd $DAVFS2_DIR

  log 1 "Running make uninstall..."
  sudo make uninstall

  log 1 "Removing user and group 'davfs2'..."
  sudo userdel -r davfs2 || true
  sudo groupdel davfs2 || true

  log 1 "Uninstallation completed."
  cd ..
}

function clean_up() {
  log 1 "Cleaning up..."
  rm -rf "$DOWNLOAD_DIR/$DAVFS2_DIR"
  log 1 "Cleanup completed."
}

function print_usage() {
  log 1 "Usage: $0 {install|uninstall|clean}"
}

if [[ $# -ne 1 ]]; then
  print_usage
  exit 1
fi

case $1 in
  install)
    check_prerequisites
    install_davfs2
    ;;
  uninstall)
    uninstall_davfs2
    ;;
  clean)
    clean_up
    ;;
  *)
    print_usage
    exit 1
    ;;
esac
