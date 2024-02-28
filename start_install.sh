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

    get_installation_profile() {
        while true;
        do
            installation_profiles=("Minimal Gnome" "No GUI")

            echo -e "\n # Choose an installation profile"

            # Print the array elements in uniform columns
            for ((i=1;i<${#installation_profiles[@]}+1;i++)); do
                printf "\n %-2s  %-15s" "$i." "${installation_profiles[$i-1]}"
            done

            # Get the users profile choice
            read -p $'\n\n--> ' profile_int

            if [ $profile_int -gt 0 ];
            then
                # Convert back to strings for case for better code readability
                case ${installation_profiles[$profile_int-1]} in
                    "Minimal Gnome")
                        install_profile=gnome_installation_profile
                        break
                        ;;
                    "No GUI")
                        break
                        ;;
                esac
            fi

            clear
            echo -e "\n --- Must Choose option 1 or 2 --- \n"
        done
    }

    get_username() {
        while : 
        do
            read -p 'Enter Username: ' username
            read -p 'Verify Username: ' username_verify

            if [[ $username == $username_verify ]]
            then
                clear
                echo -e " - Set as '$username' - \n"
                sleep 2
                break
            else
                clear
                echo -e " - Usernames Don't Match - \n"
            fi
        done
    }

    get_user_password() {
        echo -e "\n - Set Password for '$1' - "
        while :
        do
            read -s -p 'Set Password: ' user_password
            read -s -p $'\nverify Password: ' user_password_verify

            if [[ $user_password == $user_password_verify ]]
            then
                clear
                echo -e " - Set password for $1! - \n"
                sleep 2
                clear
                break
            else
                clear
                echo -e " - Passwords Don't Match - \n"
            fi 
        done
    }
}


#----- Assign System, User, and Partition Information to Variables -----

{
    [ -d /sys/firmware/efi/efivars ] && export uefi_enabled=true || export uefi_enabled=false
    echo "uefi_enabled=\"$uefi_enabled\"" >> activate_installation_variables.sh

    clear
    echo -e "* Prompt [1/6] *\n"
    # Run python script, exit if the script returns an error code
    python3 MiniArch/create_partition_table.py \
        || { echo -e "\n - Failed to create the partition table - \n"; exit; } 

    clear
    echo -e "* Prompt [2/6] *\n"
    echo ' - Set System Name - '
    get_username
    echo -e "\nsystem_name=\"$username\"" >> activate_installation_variables.sh

    clear
    echo -e "* Prompt [3/6] *\n"
    echo ' - Set User Name - '
    get_username
    echo -e "\nusername=\"$username\"" >> activate_installation_variables.sh

    clear 
    echo -e "* Prompt [4/6] *\n"
    get_user_password "$username"
    echo -e "\nuser_password=\"$user_password\"" >> activate_installation_variables.sh

    source activate_installation_variables.sh

    clear
    echo -e "* Prompt [5/6] *\n"
    get_installation_profile

    clear
    echo -e "* Prompt [6/6] *\n"
    ask_set_encryption
    echo -e "\nencrypt_system=\"$encrypt_system\"" >> activate_installation_variables.sh
}


#----------------  Create and Format Partitions ---------------- 

{
    if [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]]
    then
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

        # Format the root partition with ext4
        echo 'y' | mkfs.ext4 /dev/mapper/cryptdisk
        mount /dev/mapper/cryptdisk /mnt
    else
        # Format the unencrypted root partition
        echo 'y' | mkfs.ext4 $root_partition
        mount $root_partition /mnt
    fi

    # Only create a new boot partition if one doesn't already exist
    if [[ $existing_boot_partition != True ]];
    then
        if [[ $uefi_enabled == true ]];
        then
            echo 'y' | mkfs.fat -F 32 $boot_partition
        else
            echo 'y' | mkfs.ext4 $boot_partition
        fi
    fi

    mkdir -p /mnt/boot
    mount $boot_partition /mnt/boot
}


#----------------  Prepare the root partition ------------------

{
    clear
    echo -e "\n - Starting Installation (no more user interaction needed) - \n"

    ACTION="Update the keyring"
    echo -n "...$ACTION..."
    pacman -Sy --noconfirm archlinux-keyring >/dev/null 2>>~/miniarcherrors.log \
        && echo "[SUCCESS]" \
        || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Install UEFI setup tools"
    echo -n "...$ACTION..."
    { [[ $uefi_enabled == true ]] && pacstrap /mnt efibootmgr dosfstools mtools; } >/dev/null 2>>~/miniarcherrors.log \
        && echo "[SUCCESS]" \
        || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Install the kernel and base operating system packages (this may take a while)"
    echo -n "...$ACTION..."
    pacstrap /mnt \
        base linux linux-lts linux-firmware os-prober \
        xdg-user-dirs-gtk grub networkmanager sudo htop \
        base-devel git vim man-db man-pages >/dev/null 2>>~/miniarcherrors.log \
            && echo "[SUCCESS]" \
            || { "[FAIL] wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    ACTION="Update fstab with new partition table"
    genfstab -U /mnt >> /mnt/etc/fstab >/dev/null 2>>~/miniarcherrors.log \
        && echo "[SUCCESS] $ACTION" \
        || { "[FAIL] $ACTION... wrote error log to ~/miniarcherrors.log"; exit; }

    sleep 1

    # Run a chroot with the chosen installation profile
    ACTION="Run installation profile"
    $install_profile >/dev/null 2>>~/miniarcherrors.log \
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

    umount -a
    [[ $encrypt_system == "y" || $encrypt_system == "Y" || $encrypt_system == "yes" ]] \
        && cryptsetup luksClose cryptdisk
    reboot
}
