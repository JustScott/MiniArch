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
source /shared_lib

STDOUT_LOG_PATH="/dev/null"
STDERR_LOG_PATH="/miniarcherrors.log"

INSTALLATION_VARIABLES_FILE=/activate_installation_variables.sh

#----------------  System Configuration ----------------

{
    {
        echo "$system_name" > /etc/hostname
        echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Set system name: '$system_name'"
    [[ $? -ne 0 ]] && exit 1
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
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Set up user: '$username'"
    [[ $? -ne 0 ]] && exit 1
}

#----------------  System Settings & Packages ----------------

{
    {
        # Set the keyboard orientation
        echo $user_locale >> /etc/locale.gen
        export LANG="$(echo $user_locale | awk '{print $1}')"
        echo "LANG=$LANG" > /etc/locale.conf
        locale-gen
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Configure locale: '$user_locale'"
    [[ $? -ne 0 ]] && exit 1

    if [[ -n "$user_timezone" ]]
    then
        ln -sf /usr/share/zoneinfo/$user_timezone /etc/localtime >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Set timezone: '$user_timezone'"
        [[ $? -ne 0 ]] && exit 1
    fi
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
            } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Create & configure swapfile for the '$filesystem' filesystem"
            [[ $? -ne 0 ]] && exit 1
            ;;
        'btrfs')
            {
                btrfs subvolume create /swap
                btrfs filesystem mkswapfile --size 2g --uuid clear /swap/swapfile
                swapon /swap/swapfile
                echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab
            } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Create & configure swapfile for the '$filesystem' filesystem"
            [[ $? -ne 0 ]] && exit 1
            ;;
    esac
}

#----------------  Grub Configuration ----------------

{
    {
        if [[ "$encrypt_system" == true ]]; then
            root_partition_UUID="$( \
                blkid "$root_partition" \
                | awk -F'UUID="' '{print $2}' \
                | awk -F'"' '{print $1}')"

            if [[ -z "$root_partition_UUID" ]]
            then
                printf "\e[31m%s\e[0m" "Failed to get root partition UUID. This shouldn't happen. Stopping"
                exit 1
            fi

            # Encryption configuration
            echo "GRUB_CMDLINE_LINUX='cryptdevice=UUID=${root_partition_UUID}:cryptdisk'" >> /etc/default/grub
            echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev microcode autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
        fi
        echo -e '\nGRUB_DISABLE_OS_PROBER=false\nGRUB_SAVEDEFAULT=true\nGRUB_DEFAULT=saved' >> /etc/default/grub
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Configure Grub (with encryption if chosen)"
    [[ $? -ne 0 ]] && exit 1
}

#----------------  Cleanup & Prepare  ----------------

{
    # Temporary fix to mkinitcpio error ('file not found: /etc/vconsole.conf')
    if ! [[ -f "/etc/vconsole.conf" ]]
    then
        touch /etc/vconsole.conf &>/dev/null
    fi

    mkinitcpio --allpresets >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Generate initial ramdisk environment"
    [[ $? -ne 0 ]] && exit 1

    if [[ $uefi_enabled == true ]]
    then
        grub-install --efi-directory=/boot $removable_flag \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "EFI Grub Install"
        [[ $? -ne 0 ]] && exit 1
    else
        grub-install $boot_partition \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Non-EFI Grub Install"
        [[ $? -ne 0 ]] && exit 1
    fi

    grub-mkconfig -o /boot/grub/grub.cfg \
        >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Make grub config"
    [[ $? -ne 0 ]] && exit 1

    {
        systemctl enable NetworkManager
        rm /finish_install.sh
        shred -zu $INSTALLATION_VARIABLES_FILE "$STDERR_LOG_PATH"
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Enable systemd services & delete temporary MiniArch files"
    [[ $? -ne 0 ]] && exit 1
}

exit 0
