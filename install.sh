#!/bin/bash

echo -n 'Use Encrypted System?[y/n](default:n): '
read encrypt_system

----------------  Parition Configuration ----------------

# Boot Parition
mkfs.ext4 /dev/sda1
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# Swap Partition
mkswap /dev/sda2
swapon /dev/sda2

# Encrypted Storage Partition
if [ encrypt_system == 'y' ] || [ encrypt_system == 'Y' ] || [ encrypt_system == 'yes' ]
then
  cryptsetup luksFormat -s 512 -h sha512 /dev/sda3
  cryptsetup open /dev/sda3 cryptdisk
  mkfs.ext4 /dev/mapper/cryptdisk
  mount /dev/mapper/cryptdisk /mnt
else
  mkfs.ext4 /dev/sda3
  mount /dev/sda3 /mnt
if

----------------  Network Configuration ----------------
clear

echo -n 'Do you need to setup a wirless connection?[y/n](default:y): '
read wireless

if [ $wireless == 'y' ] || [ $wireless == '' ]
then
  echo ' -- Use These Commands -- '
  echo 'device list'
  echo 'station wlan0 scan'
  echo 'station wlan0 get-networks'
  echo 'station wlan0 connect <ssid>'
  echo 'exit'
  iwctl
fi

----------------  System Settings & Packages ----------------
clear

# Install the default pacman application
pacman -S --noconfirm gnome-control-center gnome-backgrounds gnome-terminal gnome-settings-daemon gnome-calculator gdm file-roller grub xorg networkmanager sudo htop git base-devel man-db man-pages

# Base filesystem packages
pacstrap /mnt base linux linux-firmware vim

# Tell the system where the partitions are when starting
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the filesystem as root
arch-chroot /mnt

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen


----------------  System User Configuration ----------------
clear

echo -n 'Enter System Name: '
read system_name
echo System Name Set as $system_name

# Set the root password
echo 'Set root password'
passwd

echo archy > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   archy' >> /etc/hosts


----------------  User Configuration ----------------
clear

echo -n 'Enter Username: '
read $username
echo Username set as $username

useradd -m $username
passwd
usermod -aG wheel,audio,video,storage $username
echo 'When editing this next file, uncomment the first wheel'
sleep 3
EDITOR=vim visudo

----------------  Grub Configuration ----------------
clear

if [ encrypt_system == 'y' ] || [ encrypt_system == 'Y' ] || [ encrypt_system == 'yes' ]
then
  # Encryption configuration
  echo -e 'GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptdisk"\nGRUB_ENABLE_CRYPTDISK=y' >> /etc/default/grub
  echo -e 'MODULES=()\nBINARIES\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
fi

mkiniticpio -p linux

# Actual Grub Install
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

----------------  Final Touches  ----------------
clear

# Enabling display and network managers
systemctl enable gdm.service
systemctl enable NetworkManager.service

exit
umount -a
echo 'When system shuts down, remove the installation media'
sleep 5
shutdown now
