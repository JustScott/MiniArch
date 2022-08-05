#!/bin/bash

#----------------  Defining Functions ----------------

encrypt_partition() {
  clear
  while :
    do
      cryptsetup luksFormat -s 512 -h sha512 /dev/${disk_number}2
      if [ $? == 0 ]
      then
        break
      else
        clear
        echo -e " - Try Again - \n"
      fi
   done
}

ask_set_encryption() {
  while : 
  do
    echo -n 'Use An Encrypted System? [y/n]: '
    read encrypt_system
    echo -n 'Are you sure? [y/n]: '
    read verify_encrypt

    if [ $encrypt_system == $verify_encrypt ]
    then
      break
    else
      clear
      echo -e " - Answers Don't Match - \n"
    fi
  done
}

check_uefi() {
    ls /sys/firmware/efi/efivars
    if [ $? == 0 ]
    then
        efi=True
    else
        efi=False
    fi
    clear

    echo $efi > uefi_state.temp
}

#----------------  Create and Format Partitions ---------------- 

pacman -Sy python --noconfirm

check_uefi
uefi_enabled=`cat uefi_state.temp`

python3 MiniArch/create_partition_table.py

disk_label=`cat disk_label.temp`
disk_number=`cat disk_number.temp`

clear

ask_set_encryption

if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
then
  # Encrypt Filesystem Partition
  encrypt_partition
  cryptsetup open /dev/${disk_number}2 cryptdisk
  mkfs.ext4 /dev/mapper/cryptdisk
  mount /dev/mapper/cryptdisk /mnt
else
  # Unencrypted Filesystem Partition
  mkfs.ext4 /dev/${disk_number}2
  mount /dev/${disk_number}2 /mnt
fi

# Boot Parition
if [ $uefi_enabled == True ]
then
  mkfs.fat -F 32 /dev/${disk_number}1
  mkdir /mnt/boot
  mount /dev/${disk_number}1 /mnt/boot
else
  mkfs.ext4 /dev/${disk_number}1
  mkdir /mnt/boot
  mount /dev/${disk_number}1 /mnt/boot
fi


#----------------  /mnt Prepping ----------------

# Install basic kernel, filesystem and gnome packages
pacman -Sy archlinux-keyring --noconfirm
pacstrap /mnt base linux linux-firmware linux-lts os-prober gnome-control-center gnome-backgrounds gnome-terminal gnome-keyring gnome-logs gnome-settings-daemon gnome-calculator gnome-software gvfs malcontent mutter gdm nautilus xdg-user-dirs-gtk grub xorg networkmanager sudo htop base-devel git vim man-db man-pages

# Tell the system where the partitions are when starting
genfstab -U /mnt >> /mnt/etc/fstab

# Move our final script to /mnt
mv MiniArch/finish_install.sh /mnt

# Create files to pass variables to finish_install.sh
echo $encrypt_system > /mnt/encrypted_system.temp
mv uefi_state.temp /mnt
mv disk_label.temp /mnt
mv disk_number.temp /mnt

# Chroot into /mnt, and run the finish_install.sh script
clear
arch-chroot /mnt bash finish_install.sh

# After finish_install.sh is done
umount -a
clear

echo -e '\n - Remove the installation media before starting the system again - \n'
echo 'Shutting down in 10 seconds...'
sleep 10

shutdown now
