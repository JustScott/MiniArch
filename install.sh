#!/bin/bash

# Install the default pacman application
pacman -S --noconfirm gnome-control-center gnome-backgrounds gnome-terminal gnome-settings-daemon gnome-calculator gdm file-roller grub xorg networkmanager sudo htop git base-devel man-db man-pages

pacstrap /mnt base linux linux-firmware vim

# Enter the filesystem as root
arch-chroot /mnt

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen

----------------  System User Configuration ----------------

echo 'Enter System Name:'
read system_name
echo System Name Set as $system_name

# Set the root password
echo 'Set root password:'
passwd

echo archy > /etc/hostname
echo 127.0.0.1   localhost$'\n'::1         localhost$'\n'127.0.1.1   archy >> /etc/hosts


----------------  User Configuration ----------------

echo 'Enter Username:'
read $username
echo Username set as $username

useradd -m $username
passwd
usermod -aG wheel,audio,video,storage $username
echo 'When editing this next file, uncomment the first wheel'
sleep 3
EDITOR=vim visudo

----------------  Grub Configuration ----------------

# Encryption configuration
echo GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptdisk"$'\n'GRUB_ENABLE_CRYPTDISK=y >> /etc/default/grub

echo MODULES=()$'\n'BINARIES$'\n'Files=()$'\n''HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
mkiniticpio -p linux

# Actual Grub Install
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

----------------  Final Touches  ----------------

# Enabling display and network managers
systemctl enable gdm.service
systemctl enable NetworkManager.service

exit
umount -a
echo 'When system shuts down, remove the installation media'
sleep 5
shutdown now
