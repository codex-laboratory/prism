#!/bin/bash

# Prism - Minimalist Ubuntu Installer
# Install only what you need.

set -e  # Error handling

# Variables
UBUNTU_VERSION="focal"  # Default Ubuntu version 
TARGET_DIR="/mnt/prism"  # Installation directory
DE_ENV="none"  # Default Desktop Environment
REMOVE_SNAPS=false  # Default Snap removal option

# Ensuring script runs as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Install required tools
apt update && apt install -y debootstrap whiptail

# Ask the user installation configs
DE_ENV=$(whiptail --title "Prism Installer" --menu "Choose a Desktop Environment" 15 50 4 \
    "none" "No Desktop (Minimal Server)" \
    "gnome" "GNOME Desktop" \
    "kde" "KDE Plasma" \
    "xfce" "XFCE Desktop" 3>&1 1>&2 2>&3)
    
# Check if the user pressed "Cancel"
if [ $? -ne 0 ]; then
    echo "Installation cancelled."
    exit 1
fi

whiptail --title "Prism Installer" --yesno "Do you want to remove Snaps?" 10 50
REMOVE_SNAPS=$?

# Debugging Output
echo "Selected Desktop: $DE_ENV"
echo "Remove Snaps? (0=Yes, 1=No): $REMOVE_SNAPS"

# Start the install
echo "Installing Minimal Ubuntu System..."
debootstrap --arch=amd64 $UBUNTU_VERSION $TARGET_DIR http://archive.ubuntu.com/ubuntu/

# Basic System Setup
echo "🛠 Configuring system..."
echo "proc $TARGET_DIR/proc proc defaults 0 0" >> $TARGET_DIR/etc/fstab
echo "sysfs $TARGET_DIR/sys sysfs defaults 0 0" >> $TARGET_DIR/etc/fstab

# Set up hostname and network
echo "prism" > $TARGET_DIR/etc/hostname
echo "127.0.1.1 prism" >> $TARGET_DIR/etc/hosts

# Configure fstab
cat << EOF > $TARGET_DIR/etc/fstab
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF

# Install kernel and essential utilities
echo "📦 Installing essential packages..."
chroot $TARGET_DIR apt update
chroot $TARGET_DIR apt install -y linux-generic grub2 sudo nano network-manager

# Apply selected Desktop Environment
echo "Applying selected Desktop Environment..."
if [[ $DE_ENV == "gnome" ]]; then
    chroot $TARGET_DIR apt install -y ubuntu-desktop
elif [[ $DE_ENV == "kde" ]]; then
    chroot $TARGET_DIR apt install -y kubuntu-desktop
elif [[ $DE_ENV == "xfce" ]]; then
    chroot $TARGET_DIR apt install -y xubuntu-desktop
fi

# Snap Removal (if chosen)
if [[ $REMOVE_SNAPS -eq 0 ]]; then
    echo "Removing Snaps..."
    chroot $TARGET_DIR apt purge -y snapd
fi

# Set up a new user
echo "Creating default user..."
chroot $TARGET_DIR adduser --disabled-password --gecos "" prismuser
chroot $TARGET_DIR usermod -aG sudo prismuser

echo "Setting up GRUB bootloader..."
chroot $TARGET_DIR grub-install --target=i386-pc --recheck /dev/sda
chroot $TARGET_DIR update-grub

# Cleanup & Finish
echo "Prism installation complete!"
echo "Reboot into your new minimal Ubuntu system."
exit 0

