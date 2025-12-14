#!/bin/bash
#
# start_install.sh - part of the MiniArch project
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

source ./MiniArch/shared_lib

STDOUT_LOG_PATH="/dev/null"
STDERR_LOG_PATH="/miniarcherrors.log"

PACMAN_UPDATED_FILE="/tmp/pacman_update"

INSTALLATION_VARIABLES_FILE=/tmp/activate_installation_variables.sh

MINIMUM_FREE_DISK_SPACE="11G"
# TODO: Remove the need for a buffer with exact sizing
ROOT_BUFFER_SPACE=$(echo "2G" | numfmt --from=iec)

#----------------  Defining Functions ----------------

{
    get_free_disk_space() {
        declare -g free_disk_space=""

        disk_name="$1"

        if ! lsblk | grep " disk " | grep "^$disk_name " &>/dev/null
        then
            printf "\e[31m%s\e[0m" "Disk not found in block devices... this shouldn't happen. Stopping."
            exit 1
        fi

        remaining_disk_space=$(lsblk -nb | grep " disk " | grep "^$disk_name " | awk '{print $4}')

        free_disk_space=$(echo -e "$(lsblk -nb | grep "$disk_name")\nEND OUTPUT" | \
            while IFS= read -r line
        do
            if echo "$line" | grep "END OUTPUT" &>/dev/null
            then
                echo $remaining_disk_space
                return 0
            fi

            if echo "$line" | grep " disk " &>/dev/null
            then
                if ! echo "$line" | grep "^$disk_name " &>/dev/null
                then
                    echo $remaining_disk_space
                    return 0
                fi
            fi

            if echo "$line" | grep " part " &>/dev/null
            then
                partition_size=$(echo "$line" | awk '{print $4}')
                (( remaining_disk_space-=partition_size ))
            fi
        done)
    }

    get_installation_disk() {
        declare -g installation_disk_name=""

        disks_free_space="$(lsblk -nb | grep " disk " | while IFS= read -r line
        do
            disk_name=$(echo "$line" | awk '{print $1}')

            get_free_disk_space "$disk_name"

            if [[ $free_disk_space -gt \
                $(echo "$MINIMUM_FREE_DISK_SPACE" | numfmt --from=iec) ]]
            then
                buffered_free_disk_space=$((free_disk_space-ROOT_BUFFER_SPACE))
                human_readable_disk_size=$(echo "$buffered_free_disk_space" | numfmt --to=iec)
                printf " %-15s %s\n" "$disk_name" "$human_readable_disk_size"
            fi
        done)"

        if [[ -n "$disks_free_space" ]]
        then
            printf "\n%-15s %s\n" "Disk" "Free Space"
            echo "--------------------------"
            echo "$disks_free_space"

            echo -e "\n\n\n"

            while :
            do
                if ((invalid_disk_name))
                then
                    printf "\n\e[31m%s\e[0m\n" " - Must enter a valid disk name - "
                    invalid_disk_name=0
                fi

                read -p 'Enter Disk: ' disk_name

                if [[ -n "$disk_name" ]] \
                    && echo "$disks_free_space" | grep " $disk_name " &>/dev/null
                then
                    installation_disk_name="$disk_name"
                    return
                else
                    invalid_disk_name=1
                    continue
                fi
            done
        else
            printf "\n\e[31m%s\e[0m \e[36m%s\e[0m\n\t%s" \
                "No disks have the minimum required free space for installation" \
                "($MINIMUM_FREE_DISK_SPACE)"
            exit 1
        fi
    }

    set_root_partition_size() {
        declare -g root_partition_size

        if [[ -z "$installation_disk_name" ]]
        then
            printf "\e[31m%s\e[0m" "Installation disk variable not set... this shouldn't happen."
        fi

        get_free_disk_space "$installation_disk_name"

        while :
        do
            read -p 'root partition size in GB (e.g. 20) (leave empty to fill remaining disk space): ' chosen_root_partition_size

            if [[ -z "$chosen_root_partition_size" ]]
            then
                root_partition_size=$((free_disk_space-ROOT_BUFFER_SPACE))
                return
            fi

            if [[ "$chosen_root_partition_size" =~ ^[0-9]+$ && $chosen_root_partition_size -gt 0 ]]
            then
                chosen_root_partition_size_in_bytes=$(\
                    echo "${chosen_root_partition_size}G" | numfmt --from=iec)

                if [[ $chosen_root_partition_size_in_bytes -lt $free_disk_space ]]
                then
                    if [[ \
                        $chosen_root_partition_size_in_bytes -gt\
                        $(echo $MINIMUM_FREE_DISK_SPACE | numfmt --from=iec) ]]
                    then
                        root_partition_size=$chosen_root_partition_size_in_bytes
                        return 0
                    else
                        printf "\e[31m%s\e[0m\e[36m %s\e[0m\n" \
                            "[!] root partition must be larger than" \
                            "'$MINIMUM_FREE_DISK_SPACE'"
                        continue
                    fi
                else
                    printf "\e[31m%s\e[0m\n" "[!] partition must be smaller than the disks free space"
                    continue
                fi
            else
                printf "\e[31m%s\e[0m\n" "[!] Input must be a whole number greater then 0"
                continue
            fi
        done
    }

    configure_partitions() {
        get_installation_disk
        set_root_partition_size

        PARTITION_TABLE_FILE="/tmp/${installation_disk_name}_partition_table"
        DISK_PATH="/dev/$installation_disk_name"
        SECTOR_SIZE=512

        boot_partition_bytes=$(echo "1G" | numfmt --from=iec)

        if lsblk | grep "^$installation_disk_name " | grep " disk " &>/dev/null
        then
            if ! sfdisk -d "$DISK_PATH" &>/dev/null
            then
                echo -e \
                    "label: gpt\ndevice: $DISK_PATH\nunit: sectors\nsector-size: $SECTOR_SIZE" \
                    >> /tmp/new_disk_partition_table
                sfdisk "$DISK_PATH" < /tmp/new_disk_partition_table
            fi

            sfdisk -d "$DISK_PATH" > $PARTITION_TABLE_FILE

            SECTOR_SIZE=$(sfdisk -d "$DISK_PATH" | grep "sector-size: " | awk -F': ' '{print $2}')

            if [[ -z "$SECTOR_SIZE" ]]
            then
                printf "\n\e[31m%s %s\e[0m\n" \
                    "[!] The chosen disk '$DISK_PATH' doesnt contain a default sector size." \
                    "This shouldn't happen. Stopping."
                exit 1
            fi

            boot_partition_sectors=$((boot_partition_bytes/SECTOR_SIZE))
            root_partition_sectors=$((root_partition_size/SECTOR_SIZE))

            echo "size= $boot_partition_sectors, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" \
                >> $PARTITION_TABLE_FILE
            echo "size= $root_partition_sectors, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4" \
                >> $PARTITION_TABLE_FILE

            sfdisk "$DISK_PATH" < $PARTITION_TABLE_FILE \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Update '$DISK_PATH' partition table"
            [[ $? -ne 0 ]] && exit 1
        else
            printf "\n\e[31m%s %s\e[0m\n" \
                "[!] The chosen disk '$DISK_PATH' doesnt exist" \
                "This shouldn't happen. Stopping."
            exit 1
        fi

        new_partitions="$(sfdisk -d "$DISK_PATH" | tail -n2)"
        boot_partition_sector_size=$(( $(echo "1G" | numfmt --from=iec) / 512 ))

        boot_partition="$(echo "$new_partitions" \
            | grep "$boot_partition_sector_size" \
            | awk '{print $1}')"

        root_partition="$(echo "$new_partitions" \
            | grep --invert-match "$boot_partition_sector_size" \
            | awk '{print $1}')"

        echo "boot_partition=\"$boot_partition\"" >> $INSTALLATION_VARIABLES_FILE
        echo "root_partition=\"$root_partition\"" >> $INSTALLATION_VARIABLES_FILE
    }

    ask_set_encryption() {
        declare -g encrypt_system=""
        local encrypt verify_encrypt

        while : 
        do
            read -p 'Use An Encrypted System? [y/N]: ' encrypt
            read -p 'Are you sure? [y/N]: ' verify_encrypt

            if [[ $encrypt == $verify_encrypt ]]; then
                case $encrypt in
                    "y"|"Y"|"yes"|"YES")
                        encrypt_system=true
                        return 0
                    ;;
                    ""|"n"|"N"|"no"|"NO")
                        encrypt_system=false
                        return 0
                    ;;
                    *)
                        echo -e "\n - Invalid response... possible responses are: y|Y|yes|YES|n|N|no|NO - \n"
                        continue
                    ;;
                esac
            else
                clear
                echo -e "\n - Answers Don't Match - \n"
            fi
        done
    }

    ask_removable() {
        declare -g removable_flag=""
        local removable verify_removable

        while : 
        do
            read -p 'Will this system be removable (Installed on a USB drive, for example)? [y/N]: ' removable
            read -p 'Are you sure? [y/N]: ' verify_removable

            if [[ $removable == $verify_removable ]]; then
                case $removable in
                    "y"|"Y"|"yes"|"YES")
                        removable_flag="--removable"
                        return 0
                    ;;
                    ""|"n"|"N"|"no"|"NO")
                        return 0
                    ;;
                    *)
                        echo -e "\n - Invalid response... possible responses are: y|Y|yes|YES|n|N|no|NO - \n"
                        continue
                    ;;
                esac

            else
                clear
                echo -e "\n - Answers Don't Match - \n"
            fi
        done
    }

    get_filesystem_type() {
        declare -g filesystem=""
        local OPTION

        echo -e "\n\e[1mChoose a filesystem type (if you're not sure, choose ext4):\e[0m\n"
        select OPTION in "ext4" "btrfs"; do
            case $OPTION in
                "ext4"|"btrfs")
                    filesystem="$OPTION"
                    break
                ;;
                *)
                    echo "Not an option, try again..."
                ;;
            esac
        done
    }

    get_name() {
        declare -g name=""
        local name_verify

        while : 
        do
            read -p 'Enter Name: ' name
            read -p 'Verify Name: ' name_verify

            if [[ -z "$name" ]]
            then
                clear
                echo -e " - Name Can't Be Empty - \n"
                continue
            fi

            if [[ $name == $name_verify ]]
            then
                clear
                echo -e " - Set as '$name' - \n"
                sleep .5
                break
            else 
                clear
                echo -e " - Names Don't Match - \n"
            fi
        done
    }

    get_user_password() {
        declare -g user_password=""
        local user_password_verify

        echo -e "\n - Set Password for '$1' - "
        while :
        do
            read -s -p 'Set Password: ' user_password
            read -s -p $'\nverify Password: ' user_password_verify

            if [[ $user_password == $user_password_verify ]]
            then
                clear
                echo -e " - Set password for $1! - \n"
                sleep 1
                break
            else
                clear
                echo -e " - Passwords Don't Match - \n"
            fi
        done
    }

    ask_kernel_preference() {
        declare -g kernel=""
        local OPTION kernel_options all_packages \
            chosen_custom_kernel kernel_confirmation

        kernel_options=()
                
        all_packages="$(pacman -Slq)"

        echo "$all_packages" | grep -x "linux" &>/dev/null && kernel_options+=("linux")
        echo "$all_packages" | grep -x "linux-lts" &>/dev/null && kernel_options+=("linux-lts")
        echo "${kernel_options[@]}" | grep "linux " | grep "linux-lts" &>/dev/null \
            && kernel_options+=("linux+linux-lts")

        echo -e "\n\e[1mEnter an integer or a valid kernel name (can pass a custom kernel not show below):\e[0m\n"
        select OPTION in ${kernel_options[@]} "choose custom"; do
            case $OPTION in
                "linux"|"linux-lts")
                    kernel="$OPTION"
                    break
                ;;
                "linux+linux-lts")
                    kernel="linux linux-lts"
                    break
                ;;
                "choose custom")
                    chosen_custom_kernel=$(echo "$all_packages" | fzf --reverse)
                    clear

                    [[ -z "$chosen_custom_kernel" ]] && continue

                    read -p $"Are you sure '$chosen_custom_kernel' is a kernel? [y/N]: " kernel_confirmation
                    case $kernel_confirmation in
                        "y"|"Y"|"yes"|"YES")
                            kernel="$chosen_custom_kernel"
                            break
                        ;;
                        *)
                            continue
                        ;;
                    esac
                ;;
                *)
                    echo "Can only choose a number that correlates with one of the options..."
                ;;
            esac
        done
    }
}


#----- Assign System, User, and Partition Information to Variables -----

if ! [[ -f "$PACMAN_UPDATED_FILE" ]]
then
    pacman -Sy >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Update pacman's database"
    [[ $? -ne 0 ]] && exit 1

    touch $PACMAN_UPDATED_FILE
fi

{
    pacman -S --noconfirm fzf arch-install-scripts \
        >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Install packages needed for script"
    [[ $? -ne 0 ]] && exit 1

    if [[ -d /sys/firmware/efi/efivars ]]; then
        if modprobe efivars &>/dev/null || modprobe efivarfs &>/dev/null; then
            export uefi_enabled=true || export uefi_enabled=false
        fi
    fi
    echo "uefi_enabled=\"$uefi_enabled\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [1/10] *\n"
    configure_partitions
    unset free_disk_space

    source $INSTALLATION_VARIABLES_FILE
    if [[ -z "$root_partition" ]]; then
        echo -e "\n - [ERROR] Failed to get the root partition, this shouldn't happen... stopping - \n"
        exit 1
    fi

    clear
    echo -e "* Prompt [2/10] *\n"
    echo ' - Set System Name - '
    get_name
    if [[ -z "$name" ]]; then
        echo -e "\n - [ERROR] Failed to get a system name, this shouldn't happen... stopping - \n"
        exit 1
    fi
    echo -e "\nsystem_name=\"$name\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [3/10] *\n"
    echo ' - Set User Name - '
    get_name
    if [[ -z "$name" ]]; then
        echo -e "\n - [ERROR] Failed to get a user name, this shouldn't happen... stopping - \n"
        exit 1
    fi
    echo -e "\nusername=\"$name\"" >> $INSTALLATION_VARIABLES_FILE

    clear 
    echo -e "* Prompt [4/10] *\n"
    get_user_password "$name"
    echo -e "\nuser_password=\"$user_password\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [5/10] *\n"
    echo -e "Choose your timezone (start typing to narrow down choices):"

    while :
    do
        user_timezone=$(timedatectl list-timezones | fzf --reverse --height=90%)
        if ! [[ -n "$user_timezone" ]] && \
            timedatectl list-timezones | grep "$user_timezone" &>/dev/null
        then
            printf "\e[31m%s\e[0m" "[!] Timezone not in list, try again."
            continue
        else
            echo -e "\nuser_timezone=\"$user_timezone\"" >> $INSTALLATION_VARIABLES_FILE
            break
        fi
    done

    clear
    echo -e "* Prompt [6/10] *\n"
    echo -e "Choose your locale (press <esc> to use 'en_US.UTF-8 UTF-8' (recommended) ):"
    user_locale="$(cat /usr/share/i18n/SUPPORTED | fzf --reverse --height=90%)"
    [[ -z "$user_locale" ]] && user_locale='en_US.UTF-8 UTF-8'
    echo -e "\nuser_locale=\"$user_locale\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [7/10] *\n"
    ask_kernel_preference
    if [[ -z "$kernel" ]]; then
        echo -e "\n - [ERROR] Failed to get a kernel, this shouldn't happen... stopping - \n"
        exit 1
    fi

    clear
    echo -e "* Prompt [8/10] *\n"
    get_filesystem_type
    if [[ -z "$filesystem" ]]; then
        echo -e "\n - [ERROR] Failed to get a filesystem type, this shouldn't happen... stopping - \n"
        exit 1
    fi
    echo -e "\nfilesystem=\"$filesystem\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [9/10] *\n"
    ask_removable
    echo -e "\nremovable_flag=\"$removable_flag\"" >> $INSTALLATION_VARIABLES_FILE

    clear
    echo -e "* Prompt [10/10] *\n"
    ask_set_encryption
    if [[ -z "$encrypt_system" ]]; then
        echo -e "\n - [ERROR] Failed to get user's choice on encrypting the system, this shouldn't happen... stopping - \n"
        exit 1
    fi
    echo -e "\nencrypt_system=$encrypt_system" >> $INSTALLATION_VARIABLES_FILE
}


#----------------  Create and Format Partitions ---------------- 

{
    fs_device="$root_partition"
    if [[ "$encrypt_system" == true ]]; then
        # Prompt the user to enter encryption keys until they enter
        #  matching keys
        clear
        while :
        do
            cryptsetup luksFormat -s 512 -h sha512 $root_partition \
                && break \
                || { clear; echo -e "\n - Try Again - \n"; } 
        done

        # Prompt the user for the encrypted partitions key until
        #  they enter the correct one
        while :
        do
            if cryptsetup open $root_partition cryptdisk; then
                break
            else
                clear
                echo -e " - Wrong Key, Try Again - \n" 
            fi

        done

        fs_device="/dev/mapper/cryptdisk"
    fi

    clear

    echo -e "\n - Starting Installation (no more user interaction needed) - \n"

    case $filesystem in
        "ext4")
            {
                echo 'y' | mkfs.ext4 $fs_device
                mount $fs_device /mnt
            }>>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Configure System For EXT4"
            [[ $? -ne 0 ]] && exit 1
            ;;
        "btrfs")
            pacman -S --noconfirm btrfs-progs >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Download BTRFS Packages"
            [[ $? -ne 0 ]] && exit 1
            {
                echo 'y' | mkfs.btrfs -f $fs_device
                mount $fs_device /mnt

                btrfs subvolume create /mnt/@
                btrfs subvolume create /mnt/@home

                umount /mnt

                # 256 is /mnt/@
                mount $fs_device -o subvolid=256 /mnt
                mkdir -p /mnt/home
                # 257 is /mnt/@home
                mount $fs_device -o subvolid=257 /mnt/home
            }>>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Configure System For BTRFS"
            [[ $? -ne 0 ]] && exit 1
            ;;
        *)
            printf "\r\e[31m[Error]\e[0m %sNo Filesystem Chosen\n"
            exit 1
            ;;
    esac

    if [[ $uefi_enabled == true ]]
    then
        echo 'y' | mkfs.fat -F 32 $boot_partition >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Format boot partition with FAT32"
        [[ $? -ne 0 ]] && exit 1
    else
        echo 'y' | mkfs.ext4 $boot_partition >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Format boot partition with EXT4"
        [[ $? -ne 0 ]] && exit 1
    fi

    mkdir -p /mnt/boot
    mount $boot_partition /mnt/boot
}


#----------------  Prepare the root partition ------------------

{
    if [[ $uefi_enabled == true ]]
    then
        pacstrap /mnt efibootmgr dosfstools mtools >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install UEFI setup tools"
        [[ $? -ne 0 ]] && exit 1
    fi

    if [[ $filesystem == "btrfs" ]]
    then
        pacstrap /mnt btrfs-progs snapper grub-btrfs >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install btrfs related packages"
        [[ $? -ne 0 ]] && exit 1
    fi

    pacstrap /mnt base linux-firmware $kernel >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Install the kernel(s): '$kernel' (this may take a while)"
    [[ $? -ne 0 ]] && exit 1

    pacstrap /mnt \
        os-prober xdg-user-dirs-gtk grub networkmanager sudo htop \
        base-devel git vim man-db man-pages >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Install base operating system packages (this may take a while)"
    [[ $? -ne 0 ]] && exit 1

    genfstab -U /mnt >> /mnt/etc/fstab 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Update fstab with new partition table"
    [[ $? -ne 0 ]] && exit 1

    # Move necessary scripts to /mnt
    cp MiniArch/shared_lib /mnt
    cp MiniArch/finish_install.sh /mnt
    mv $INSTALLATION_VARIABLES_FILE /mnt
    
    # Create files to pass variables to fin
    # Chroot into /mnt, and run the finish_install.sh script
    arch-chroot /mnt /bin/bash finish_install.sh 2>>"$STDERR_LOG_PATH" \
        || { echo -e "\n - 'arch-chroot /mnt bash finish_install.sh' failed - \n"; exit; } 

    printf "\n\e[32m - Installation Successful! - \e[0m\n"
    echo -e '\n'

    for i in {10..0}; do
        printf "\rRebooting in \e[1;36m$i\e[0m seconds...\e[31m(CTRL+c to cancel)\e[0m"
        sleep 1
    done

    echo -e "\n"

    shred -uz /mnt/miniarcherrors.log &>/dev/null 

    umount /mnt/boot &>/dev/null
    umount /mnt &>/dev/null
    [[ $encrypt_system == true ]] && cryptsetup luksClose cryptdisk &>/dev/null
    umount -a &>/dev/null

    reboot
}
