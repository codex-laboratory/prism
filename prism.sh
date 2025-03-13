#!/bin/bash

# Prism - This script is meant to be used as a base for creating a distro installer
# for now it only installs ubuntu with some options tho
# Install only what you need 

set -euo pipefail

# Variables
UBUNTU_VERSION="focal"  # Default Ubuntu version
TARGET_DIR="/mnt/prism"  # Installation directory
DE_ENV="none"            # Default Desktop Environment
REMOVE_SNAPS=1            # Default is to keep snaps

# Ensuring script runs as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Essential packages
BASE_PACKAGES="linux-generic grub-pc sudo nano network-manager net-tools"

echo "Prism: Minimal Ubuntu Installer"

# Install required tools
apt update
apt install -y debootstrap whiptail

# Asking the user :p
DE_ENV=$(whiptail --title "Prism Installer" --menu "Choose Desktop Environment" 15 50 4 \
  "none" "No Desktop (Minimal Server)" \
  "gnome" "GNOME Desktop" \
  "xfce" "XFCE Desktop" \
  "kde" "KDE Plasma" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "Installation cancelled."
    exit 1
fi

if (whiptail --title "Prism Installer" --yesno "Do you want to remove Snaps?" 10 50); then
  REMOVE_SNAPS=0
fi

echo "Selected Desktop: $DE_ENV"
echo "Remove Snaps? (0=Yes, 1=No): $REMOVE_SNAPS"

# Bootstrap minimal Ubuntu
echo "Installing Minimal Ubuntu System..."
sudo debootstrap --arch amd64 $UBUNTU_VERSION $TARGET_DIR http://archive.ubuntu.com/ubuntu/

# Basic Configuration
echo "🛠 Configuring basic settings..."
echo "prism" | sudo tee $TARGET_DIR/etc/hostname
cat <<EOF | sudo tee $TARGET_DIR/etc/fstab
proc  /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF

# Mount necessary filesystems 
sudo mount --bind /dev $TARGET_DIR/dev
sudo mount --bind /dev/pts $TARGET_DIR/dev/pts
sudo mount --bind /proc $TARGET_DIR/proc
sudo mount --bind /sys $TARGET_DIR/sys

# Install packages inside chroot
echo "Installing essential packages..."
sudo chroot $TARGET_DIR apt update
sudo chroot $TARGET_DIR apt install -y $BASE_PACKAGES

# Enable Universe repository (required for some DE packages)
sudo chroot "$TARGET_DIR" apt install -y software-properties-common
sudo chroot "$TARGET_DIR" add-apt-repository universe
sudo chroot "$TARGET_DIR" apt update

# Desktop Environment Installation
if [[ $DE_ENV != "none" ]]; then
  if [[ $DE_ENV == "xfce" ]]; then
    sudo chroot $TARGET_DIR apt install -y xubuntu-desktop
  elif [[ $DE_ENV == "gnome" ]]; then
    sudo chroot $TARGET_DIR apt install -y ubuntu-desktop
  elif [[ $DE_ENV == "kde" ]]; then
    sudo chroot $TARGET_DIR apt install -y kde-plasma-desktop
  fi
else
  echo "No desktop environment selected. Skipping..."
fi

# Remove snaps if selected :)))
if [[ $REMOVE_SNAPS -eq 0 ]]; then
  echo "Removing Snaps..."
  sudo chroot $TARGET_DIR apt purge -y snapd
fi

# Set hostname and basic network config
echo "127.0.0.1 prism" | sudo tee -a $TARGET_DIR/etc/hosts

# Setting up GRUB bootloader (pleasework)
echo "Setting up GRUB bootloader..."
sudo chroot "$TARGET_DIR" apt install -y grub-pc grub-common
sudo chroot "$TARGET_DIR" grub-install --target=i386-pc --recheck /dev/sda
sudo chroot "$TARGET_DIR" update-grub

# Add default user
sudo chroot $TARGET_DIR useradd -m -G sudo -s /bin/bash prism
sudo chroot $TARGET_DIR passwd prism

# Cleanup 
sudo umount $TARGET_DIR/dev/pts
sudo umount $TARGET_DIR/dev
sudo umount $TARGET_DIR/sys
sudo umount $TARGET_DIR/proc

echo "Prism installation complete!"
echo "Reboot into your minimalist Ubuntu: sudo reboot"

exit 0
