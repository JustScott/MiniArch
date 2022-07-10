#!/bin/bash

clear

echo -n 'Using Encrypted System?[y/n](default:n): '
read encrypt_system


#----------------  Parition Formatting ---------------- 
  
if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
then
  # Encrypted Filesystem Partition
  cryptsetup luksFormat -s 512 -h sha512 /dev/sda3
  cryptsetup open /dev/sda3 cryptdisk
  mkfs.ext4 /dev/mapper/cryptdisk
  mount /dev/mapper/cryptdisk /mnt
else
  # Unencrypted Filesystem Partition
  mkfs.ext4 /dev/sda3
  mount /dev/sda3 /mnt
fi

# Swap Partition
mkswap /dev/sda2
swapon /dev/sda2

# Boot Parition
mkfs.ext4 /dev/sda1
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot


#----------------  /mnt Prepping ----------------

# Put the basic linux dependices on your filesystem parition, + vim,git
$ pacstrap /mnt base linux linux-firmware

# Tell the system where the partitions are when starting
$ genfstab -U /mnt >> /mnt/etc/fstab

# Enter your filesystem
$ arch-chroot /mnt


#----------------  System User Configuration ----------------
clear

echo -n 'Enter System Name: '
read system_name
echo System Name Set as $system_name

clear

# Set the root password
echo '- Set root password -'
passwd

echo $system_name > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '$system_name >> /etc/hosts


#----------------  User Configuration ----------------
clear

echo ' - Create A User - '
echo -n 'Enter Username: '
read username
echo Username set as $username

useradd -m $username
passwd $username
usermod -aG wheel,audio,video,storage $username


#----------------  System Settings & Packages ----------------
clear

# Install the default pacman application
pacman -S --noconfirm gnome-control-center gnome-backgrounds gnome-terminal gnome-settings-daemon gnome-calculator gdm file-roller grub xorg networkmanager sudo htop base-devel vim git man-db man-pages

echo -e '\n##Appended to file via install script (MiniArch)\n%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen


#----------------  Grub Configuration ----------------
clear

if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
then
  # Encryption configuration
  echo -e '\n#Appended to file via install script (MiniArch) \nGRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptdisk"' >> /etc/default/grub
  echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
fi

mkinitcpio -p linux

# Actual Grub Install
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

#----------------  Final Touches  ----------------

# Enabling display and network managers
systemctl enable gdm NetworkManager

clear

echo -e '\n - Run these commands to finish the installation - \n'
echo '( Remove the installation media before restarting )'
echo -e '\n - exit\n - umount -a\n - shutdown now\n'
