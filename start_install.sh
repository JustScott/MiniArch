#!/bin/bash

#----------------  Defining Functions ----------------

encrypt_partition() {
  clear
  while :
    do
      cryptsetup luksFormat -s 512 -h sha512 /dev/sda3
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

sfdisk /dev/sda < partition_table.txt

clear

ask_set_encryption

if [ $encrypt_system=='y' ] || [ $encrypt_system=='Y' ] || [ $encrypt_system=='yes' ]
then
  # Encrypt Filesystem Partition
  encrypt_partition
  cryptsetup open /dev/sda2 cryptdisk
  mkfs.ext4 /dev/mapper/cryptdisk
  mount /dev/mapper/cryptdisk /mnt
else
  # Unencrypted Filesystem Partition
  mkfs.ext4 /dev/sda3
  mount /dev/sda3 /mnt
fi

# Boot Parition
if [ $uefi_enabled == True ]
then
  mkfs.fat -F 32 /dev/sda1
  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
else
  mkfs.ext4 /dev/sda1
  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
fi


#----------------  /mnt Prepping ----------------

# Install basic kernel, filesystem and gnome packages
while :
do
  pacstrap /mnt base linux linux-firmware linux-lts os-prober gnome-control-center gnome-backgrounds gnome-terminal gnome-keyring gnome-logs gnome-settings-daemon gnome-calculator gnome-software gvfs malcontent mutter gdm nautilus xdg-user-dirs-gtk grub xorg networkmanager sudo htop base-devel git vim man-db man-pages
  if [ $? == 0 ]
  then
    break
   else
    # Clear the pacman cache
    pacman -Sc --noconfirm
   fi
done

# Tell the system where the partitions are when starting
genfstab -U /mnt >> /mnt/etc/fstab

# Move our final script to /mnt
mv MiniArch/finish_install.sh /mnt

# Create files to pass variables to finish_install.sh
echo $encrypt_system > /mnt/encrypted_system.temp
echo $uefi_enabled > /mnt/uefi_state.temp

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
