#!/bin/bash

clear

echo -n 'Using Encrypted System?[y/n](default:n): '
read encrypt_system

----------------  System Settings & Packages ----------------
clear

# Install the default pacman application
pacman -S --noconfirm gnome-control-center gnome-backgrounds gnome-terminal gnome-settings-daemon gnome-calculator gdm file-roller grub xorg networkmanager sudo htop base-devel man-db man-pages

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

clear

# Set the root password
echo '- Set root password -'
passwd

echo archy > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   archy' >> /etc/hosts


----------------  User Configuration ----------------
clear

echo ' - Create A User - '
echo -n 'Enter Username: '
read username
echo Username set as $username

useradd -m $username
passwd
usermod -aG wheel,audio,video,storage $username
echo -e '\n##Appended to file via install script (MiniArch)\n%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

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
