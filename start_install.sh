#!/bin/bash

sfdisk /dev/sda < MiniArch/dos_partition_table.txt

clear

echo -n 'Using Encrypted System?[y/n](default:n): '
read encrypt_system


#----------------  Parition Formatting ---------------- 
  
if [ $encrypt_system=='y' ] || [ $encrypt_system=='Y' ] || [ $encrypt_system=='yes' ]
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
pacstrap /mnt base linux linux-firmware

# Tell the system where the partitions are when starting
genfstab -U /mnt >> /mnt/etc/fstab

# Move our final script to /mnt
mv MiniArch/finish_install.sh /mnt

# Create a file to pass a variable to finish_install.sh
echo $encrypt_system > /mnt/temp_var.txt

# Chroot into /mnt, and run the finish_install.sh script
clear
arch-chroot /mnt bash finish_install.sh

# After finish_install.sh is done
clear
umount -a
echo -e '\n - Remove the installation media before starting the system again - \n'
echo 'Shutting down in 10 seconds...'
sleep 10

shutdown now
