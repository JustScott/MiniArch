#!/bin/bash
#
# start_install.sh - part of the MiniArch project
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


#----------------  Defining Functions ----------------

{
    ask_set_encryption() {
        while : 
        do
            read -p 'Use An Encrypted System? [y/N]: ' encrypt_system
            read -p 'Are you sure? [y/N]: ' verify_encrypt

            [[ $encrypt_system == $verify_encrypt ]] \
                && break \
                || { clear; echo -e "\n - Answers Don't Match - \n"; } 
        done
    }

    gnome_installation_profile() {
        mv MiniArch/profiles/minimal-gnome.sh /mnt
        arch-chroot /mnt bash minimal-gnome.sh
    }

    get_filesystem_type() {
        while true;
        do
            filesystem_options=("ext4" "btrfs")

            echo -e "\n # Choose a filesystem type (if you're not sure, choose ext4)"

            # Print the array elements in uniform columns
            for ((i=1;i<${#filesystem_options[@]}+1;i++)); do
                printf "\n %-2s  %-15s" "$i." "${filesystem_options[$i-1]}"
            done

            # Get the users profile choice
            read -p $'\n\n--> ' filesystem_int

            [[ $filesystem_int -gt 0 ]] && {
                # Convert back to strings for case for better code readability
                case ${filesystem_options[$filesystem_int-1]} in
                    "ext4")
                        filesystem="ext4"
                        break
                        ;;
                    "btrfs")
                        filesystem="btrfs"
                        break
                        ;;
                esac
            }

            clear
            echo -e "\n --- Must Choose option by its integer --- \n"
        done
    }

    get_username() {
        while : 
        do
            read -p 'Enter Username: ' username
            read -p 'Verify Username: ' username_verify

            [[ $username == $username_verify ]] && {
                clear
                echo -e " - Set as '$username' - \n"
                sleep 2
                break
            } || { clear; echo -e " - Usernames Don't Match - \n"; } 
        done
    }

    get_user_password() {
        echo -e "\n - Set Password for '$1' - "
        while :
        do
            read -s -p 'Set Password: ' user_password
            read -s -p $'\nverify Password: ' user_password_verify

            [[ $user_password == $user_password_verify ]] && {
                clear
                echo -e " - Set password for $1! - \n"
                sleep 2
                break
            } || { clear; echo -e " - Passwords Don't Match - \n"; } 
        done
    }

    ask_kernel_preference() {
        while true;
        do
            kernel_options=("linux" "linux-lts" "linux & linux-lts")

            echo -e "\n # Which kernel(s) would you like to install?"

            # Print the array elements in uniform columns
            for ((i=1;i<${#kernel_options[@]}+1;i++)); do
                printf "\n %-2s  %-15s" "$i." "${kernel_options[$i-1]}"
            done

            # Get the users profile choice
            read -p $'\n\n--> ' kernel_int

            [[ $kernel_int -gt 0 ]] && {
                # Convert back to strings for case for better code readability
                case ${kernel_options[$kernel_int-1]} in
                    "linux")
                        kernel="linux"
                        break
                        ;;
                    "linux-lts")
                        kernel="linux-lts"
                        break
                        ;;
                    "linux & linux-lts")
                        kernel="linux linux-lts"
                        break
                        ;;
                esac
            }

            clear
            echo -e "\n --- Must Choose option by its integer --- \n"
        done
    }
}


#----- Assign System, User, and Partition Information to Variables -----

{
    ACTION="Update the keyring & install python"
    echo -n "...$ACTION..."
    pacman -Sy --noconfirm archlinux-keyring python arch-install-scripts \
        >/dev/null 2>>~/miniarcherrors.log \
        && echo "[SUCCESS]" \
        || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    [ -d /sys/firmware/efi/efivars ] && export uefi_enabled=true || export uefi_enabled=false
    echo "uefi_enabled=\"$uefi_enabled\"" >> activate_installation_variables.sh

    clear
    echo -e "* Prompt [1/7] *\n"
    # Run python script, exit if the script returns an error code
    python3 MiniArch/create_partition_table.py \
        || { echo -e "\n - Failed to create the partition table - \n"; exit; } 

    clear
    echo -e "* Prompt [2/7] *\n"
    echo ' - Set System Name - '
    get_username
    echo -e "\nsystem_name=\"$username\"" >> activate_installation_variables.sh

    clear
    echo -e "* Prompt [3/7] *\n"
    echo ' - Set User Name - '
    get_username
    echo -e "\nusername=\"$username\"" >> activate_installation_variables.sh

    clear 
    echo -e "* Prompt [4/7] *\n"
    get_user_password "$username"
    echo -e "\nuser_password=\"$user_password\"" >> activate_installation_variables.sh

    # Ask user if want linux or lts or both
    clear
    echo -e "* Prompt [5/7] *\n"
    ask_kernel_preference

    clear
    echo -e "* Prompt [6/7] *\n"
    get_filesystem_type
    echo -e "\nfilesystem=\"$filesystem\"" >> activate_installation_variables.sh

    clear
    echo -e "* Prompt [7/7] *\n"
    ask_set_encryption
    echo -e "\nencrypt_system=\"$encrypt_system\"" >> activate_installation_variables.sh


    source activate_installation_variables.sh
}


#----------------  Create and Format Partitions ---------------- 

{
    fs_device="$root_partition"
    [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]] && {
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
            cryptsetup open $root_partition cryptdisk \
                && break \
                || { clear; echo -e " - Try Again - \n"; } 

        done

        fs_device="/dev/mapper/cryptdisk"
    }

    clear

    echo -e "\n - Starting Installation (no more user interaction needed) - \n"

    ACTION="Create Filesystem: '$filesystem'"
    case $filesystem in
        "ext4")
            {
                echo 'y' | mkfs.ext4 $fs_device
                mount $fs_device /mnt
            }>/dev/null 2>>~/miniarcherrors.log \
                && echo "[SUCCESS] $ACTION" \
                || { "[FAIL] $ACTION... wrote error log to ~/miniarcherrors.log"; exit; }
            ;;
        "btrfs")
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
            }>/dev/null 2>>~/miniarcherrors.log \
                && echo "[SUCCESS] $ACTION" \
                || { "[FAIL] $ACTION... wrote error log to ~/miniarcherrors.log"; exit; }
            ;;
        *)
            "[FAIL] $ACTION... no filesystem chosen"
            exit
            ;;
    esac

    ACTION="Format boot partition"
    # Only create a new boot partition if one doesn't already exist
    [[ $existing_boot_partition != True ]] && {
        [[ $uefi_enabled == true ]] \
            && echo 'y' | mkfs.fat -F 32 $boot_partition \
            || echo 'y' | mkfs.ext4 $boot_partition
    } >/dev/null 2>>~/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to ~/miniarcherrors.log"; exit; }

    mkdir -p /mnt/boot
    mount $boot_partition /mnt/boot
}


#----------------  Prepare the root partition ------------------

{
    ACTION="Install UEFI setup tools"
    echo -n "...$ACTION..."
    {
    [[ $uefi_enabled == true ]] \
        && pacstrap /mnt efibootmgr dosfstools mtools >/dev/null 2>>~/miniarcherrors.log
    } \
        && echo "[SUCCESS]" \
        || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    [[ $filesystem == "btrfs" ]] && {
        ACTION="Install btrfs related packages"
        echo -n "...$ACTION..."
        pacstrap /mnt btrfs-progs snapper grub-btrfs >/dev/null 2>>~/miniarcherrors.log \
                && echo "[SUCCESS]" \
                || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }
    }

    sleep 1

    ACTION="Install the kernel(s): '$kernel' (this may take a while)"
    echo -n "...$ACTION..."
    pacstrap /mnt \
        base linux-firmware $kernel >/dev/null 2>>~/miniarcherrors.log \
            && echo "[SUCCESS]" \
            || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Install base operating system packages (this may take a while)"
    echo -n "...$ACTION..."
    pacstrap /mnt \
        os-prober xdg-user-dirs-gtk grub networkmanager sudo htop \
        base-devel git vim man-db man-pages >/dev/null 2>>~/miniarcherrors.log \
            && echo "[SUCCESS]" \
            || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Update fstab with new partition table"
    genfstab -U /mnt >> /mnt/etc/fstab \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    # Move necessary scripts to /mnt
    mv MiniArch/finish_install.sh /mnt
    mv activate_installation_variables.sh /mnt
    
    # Create files to pass variables to fin
    # Chroot into /mnt, and run the finish_install.sh script
    arch-chroot /mnt /bin/bash finish_install.sh \
        || { echo -e "\n - 'arch-chroot /mnt bash finish_install.sh' failed - \n"; exit; } 

    clear

    echo -e '\n - Installation Successful! - \n'
    echo 'Unmounting partitions & Rebooting in 10 seconds...(hit CTRL+c to cancel)'
    sleep 10

    shred -uz /mnt/miniarcherrors.log 

    umount -a
    [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]] \
        && cryptsetup luksClose cryptdisk
    reboot
}
