#!/bin/bash

#----------------  Defining Functions ----------------

encrypt_partition() {
    clear
    while :
    do
        cryptsetup luksFormat -s 512 -h sha512 $(cat next_open_partition.temp)
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


run_installation_profile() {
    clear
    while true;
    do
        echo -e "\n # Choose an installation profile\n #"
        echo -e "\n 1. Minimal Gnome"
        echo -e " 2. No GUI"
        echo -en "\n\n--> "
        read -r install_profile_integer

        if [[ $install_profile_integer == 1 ]];
        then
            mv MiniArch/profiles/minimal-gnome.sh /mnt
            arch-chroot /mnt bash minimal-gnome.sh
            break
        fi
        if [[ $install_profile_integer == 2 ]];
        then
            # Break since everything for this profile is
            #  already installed
            break
        fi

        clear
        echo -e "\n --- Must Choose option 1 or 2 --- \n"
    done
}

#----------------  Create and Format Partitions ---------------- 

pacman -Sy python --noconfirm

check_uefi
uefi_enabled=$(cat uefi_state.temp)

# Run python script, exit if script returns error code
python3 MiniArch/create_partition_table.py
if [ $? == 1 ]
then
    exit
fi

# Bring in variables put in files by the 'create_partition_table.py` script
#
boot_partition=$(cat boot_partition.temp)
existing_boot_partition=$(cat existing_boot_partition.temp)
system_partition=$(cat next_open_partition.temp)

ask_set_encryption

if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
then
    # Encrypt Filesystem Partition
    encrypt_partition

    # Prompt the user for the encrypted partitions key until
    #  they enter the correct one
    while :
    do
        cryptsetup open $system_partition cryptdisk
        if [ $? == 0 ]
        then
            break
        else
            clear
            echo -e " - Try Again - \n"
        fi
    done

    echo 'y' | mkfs.ext4 /dev/mapper/cryptdisk
    mount /dev/mapper/cryptdisk /mnt
else
    # Unencrypted Filesystem Partition
    echo 'y' | mkfs.ext4 $system_partition
    mount $system_partition /mnt
fi

# Only create a new boot partition if one doesn't already exist
if [[ $existing_boot_partition != True ]];
then
    if [[ $uefi_enabled == True ]];
    then
        echo 'y' | mkfs.fat -F 32 $boot_partition
    else
        echo 'y' | mkfs.ext4 $boot_partition
    fi
fi

mkdir -p /mnt/boot
mount $boot_partition /mnt/boot


#----------------  /mnt Prepping ----------------

# Install linux and linux-lts kernels, along with the most basic packages
pacman -Sy archlinux-keyring --noconfirm
pacstrap /mnt \
    base linux linux-lts linux-firmware os-prober \
    xdg-user-dirs-gtk grub networkmanager sudo htop \
    base-devel git vim man-db man-pages

# Tell the system where the partitions are when starting
genfstab -U /mnt >> /mnt/etc/fstab

# Runs a chroot with the custom installation profile
run_installation_profile

# Move our final script to /mnt
mv MiniArch/finish_install.sh /mnt

# Create files to pass variables to finish_install.sh
echo $encrypt_system > /mnt/encrypted_system.temp
mv uefi_state.temp /mnt
mv next_open_partition.temp /mnt
mv boot_partition.temp /mnt
mv existing_boot_partition.temp /mnt

# Chroot into /mnt, and run the finish_install.sh script
arch-chroot /mnt bash finish_install.sh
if [ $? == 1 ]
then
    echo "'arch-chroot /mnt bash finish_install.sh' failed"
    exit
fi

# After finish_install.sh is done
umount -a

clear

echo -e '\n - Installation Successful! - \n'
echo 'Rebooting in 10 seconds...'
sleep 10

reboot
