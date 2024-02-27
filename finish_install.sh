#!/bin/bash
#
# finish_install.sh - part of the MiniArch project
# Copyright (C) 2023, Scott Wyman, development@justscott.me
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


source /activate_installation_variables.sh

#----------------  System Configuration ----------------

{
    echo "$system_name" > /etc/hostname
    echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
}


#----------------  User Configuration ----------------

{
    useradd -m "$username"

    clear
    echo "$username":"$user_password" | chpasswd
    usermod -aG wheel,audio,video,storage "$username"
}


#----------------  System Settings & Packages ----------------

{
    clear

    chmod u+w /etc/sudoers
    echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers
    chmod u-w /etc/sudoers

    # Set the keyboard orientation
    echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
    echo LANG='en_US.UTF-8' > /etc/locale.conf
    export LANG=en_US.UTF-8
    locale-gen
}


#----------------  Swap File Configuration ----------------

{
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    echo '/swapfile none swap 0 0' >> /etc/fstab
}

#----------------  Grub Configuration ----------------

{

    if [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]]
    then
        # Encryption configuration
        echo "GRUB_CMDLINE_LINUX='cryptdevice=${root_partition}:cryptdisk'" >> /etc/default/grub
        echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
    fi

    echo -e '\nGRUB_DISABLE_OS_PROBER=false\nGRUB_SAVEDEFAULT=true\nGRUB_DEFAULT=saved' >> /etc/default/grub
}


#----------------  Cleanup & Prepare  ----------------

{
    pacman -S --noconfirm linux linux-lts os-prober
    mkinitcpio --allpresets

    # Only install grub if a boot partition doesn't already exist
    if [[ $existing_boot_partition != True ]];
    then
        # Actual Grub Install
        if [ $uefi_enabled == true ]
        then
            pacman -Sy --noconfirm efibootmgr dosfstools mtools
            grub-install --efi-directory=/boot
        else
            grub-install $boot_partition
        fi
    fi
    grub-mkconfig -o /boot/grub/grub.cfg

    systemctl enable NetworkManager

    rm /finish_install.sh
    shred -zu /activate_installation_variables.sh

    exit
}
