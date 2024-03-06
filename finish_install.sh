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
    ACTION="Set system name: '$system_name'"
    {
        echo "$system_name" > /etc/hostname
        echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}


#----------------  User Configuration ----------------

{
    ACTION="Set up user: '$username'"
    {
        useradd -G wheel,audio,video,storage -m "$username"

        [[ -n "$user_password" ]] \
            && echo "$username":"$user_password" | chpasswd \
            || passwd -d "$username"

        chmod u+w /etc/sudoers
        echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers
        chmod u-w /etc/sudoers
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}

#----------------  System Settings & Packages ----------------

{
    ACTION="Configure locale"
    {
        # Set the keyboard orientation
        echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
        echo LANG='en_US.UTF-8' > /etc/locale.conf
        export LANG=en_US.UTF-8
        locale-gen
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}


#----------------  Swap File Configuration ----------------

{
    ACTION="Create & configure swapfile"
    {
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        echo '/swapfile none swap 0 0' >> /etc/fstab
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}

#----------------  Grub Configuration ----------------

{
    ACTION="Configure Grub (with encryption if chosen)"
    {
        [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]] && {
            # Encryption configuration
            echo "GRUB_CMDLINE_LINUX='cryptdevice=${root_partition}:cryptdisk'" >> /etc/default/grub
            echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
        }
        echo -e '\nGRUB_DISABLE_OS_PROBER=false\nGRUB_SAVEDEFAULT=true\nGRUB_DEFAULT=saved' >> /etc/default/grub
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}


#----------------  Cleanup & Prepare  ----------------

{
    ACTION="Generate initial ramdisk environment"
    echo -n "...$ACTION..."
    mkinitcpio --allpresets >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS]" \
        || { "[FAIL] wrote error log to /miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Finish Grub Installation"
    {
        # Only install grub if a boot partition doesn't already exist
        [[ $existing_boot_partition != True ]] && {
            # Actual Grub Install
            [[ $uefi_enabled == true ]] \
                && grub-install --efi-directory=/boot \
                || grub-install $boot_partition
        }
        grub-mkconfig -o /boot/grub/grub.cfg
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1


    ACTION="Enable systemd services & delete temporary MiniArch files"
    {
        systemctl enable NetworkManager

        rm /finish_install.sh
        shred -zu /activate_installation_variables.sh /miniarcherrors.log
    } >/dev/null 2>>/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to /miniarcherrors.log"; exit; }

    sleep 1
}
    
exit
