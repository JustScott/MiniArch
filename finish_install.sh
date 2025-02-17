#!/bin/bash
#
# finish_install.sh - part of the MiniArch project
# Copyright (C) 2024-2025, JustScott, development@justscott.me
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
source /root/MiniArch/shared_lib

STDOUT_LOG="/dev/null"
STDERR_LOG="$HOME/miniarcherrors.log"


#----------------  System Configuration ----------------

{
    {
        echo "$system_name" > /etc/hostname
        echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
    } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Set system name: '$system_name'"
    [[ $? -ne 0 ]] && exit 1

    sleep 1
}


#----------------  User Configuration ----------------

{
    {
        useradd -G wheel,audio,video,storage -m "$username"

        if [[ -n "$user_password" ]]
        then 
            echo "$username":"$user_password" | chpasswd
        else 
            passwd -d "$username"
        fi

        chmod u+w /etc/sudoers
        echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers
        chmod u-w /etc/sudoers
    } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Set up user: '$username'"
    [[ $? -ne 0 ]] && exit 1

    sleep 1
}

#----------------  System Settings & Packages ----------------

{
    {
        # Set the keyboard orientation
        echo $user_locale >> /etc/locale.gen
        export LANG="$(echo $user_locale | awk '{print $1}')"
        echo "LANG=$LANG" > /etc/locale.conf
        locale-gen
    } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Configure locale: '$user_locale'"
    [[ $? -ne 0 ]] && exit 1

    sleep 1

    if [[ -n "$user_timezone" ]]
    then
        ln -sf /usr/share/zoneinfo/$user_timezone /etc/localtime >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
        task_output $! "$STDERR_LOG" "Set timezone: '$user_timezone'"
        [[ $? -ne 0 ]] && exit 1
    fi

    sleep 1
}


#----------------  Swap File Configuration ----------------

{
    case $filesystem in
        'ext4')
            {
                fallocate -l 2G /swapfile
                chmod 600 /swapfile
                mkswap /swapfile
                echo '/swapfile none swap 0 0' >> /etc/fstab
            } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
            task_output $! "$STDERR_LOG" "Create & configure swapfile for the '$filesystem' filesystem"
            [[ $? -ne 0 ]] && exit 1
            ;;
        'btrfs')
            {
                btrfs subvolume create /swap
                btrfs filesystem mkswapfile --size 2g --uuid clear /swap/swapfile
                swapon /swap/swapfile
                echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab
            } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
            task_output $! "$STDERR_LOG" "Create & configure swapfile for the '$filesystem' filesystem"
            [[ $? -ne 0 ]] && exit 1
            ;;
    esac

    sleep 1
}

#----------------  Grub Configuration ----------------

{
    {
        if [[ "$encrypt_system" == true ]]; then
            # Encryption configuration
            echo "GRUB_CMDLINE_LINUX='cryptdevice=${root_partition}:cryptdisk'" >> /etc/default/grub
            echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
        fi
        echo -e '\nGRUB_DISABLE_OS_PROBER=false\nGRUB_SAVEDEFAULT=true\nGRUB_DEFAULT=saved' >> /etc/default/grub
    } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Configure Grub (with encryption if chosen)"
    [[ $? -ne 0 ]] && exit 1

    sleep 1
}


#----------------  Cleanup & Prepare  ----------------

{
    mkinitcpio --allpresets >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Generate initial ramdisk environment"
    [[ $? -ne 0 ]] && exit 1

    sleep 1

    # Only install grub if a boot partition doesn't already exist
    if [[ $existing_boot_partition != True ]]
    then
        # Actual Grub Install
        if [[ $uefi_enabled == true ]]
        then
            grub-install --efi-directory=/boot $removable_flag >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
            task_output $! "$STDERR_LOG" "EFI Grub Install"
            [[ $? -ne 0 ]] && exit 1
        else
            grub-install $boot_partition >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
            task_output $! "$STDERR_LOG" "Normal Grub Install"
            [[ $? -ne 0 ]] && exit 1
        fi
    fi

    grub-mkconfig -o /boot/grub/grub.cfg >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Make grub config"
    [[ $? -ne 0 ]] && exit 1

    sleep 1


    {
        systemctl enable NetworkManager
        rm /finish_install.sh
        shred -zu /activate_installation_variables.sh /miniarcherrors.log
    } >"$STDOUT_LOG" 2>>"$STDERR_LOG" &
    task_output $! "$STDERR_LOG" "Enable systemd services & delete temporary MiniArch files"
    [[ $? -ne 0 ]] && exit 1

    sleep 1
}
    
exit
