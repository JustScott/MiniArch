#!/bin/bash

#----------------  Defining Functions ----------------

{
    ask_set_encryption() {
        while : 
        do
            echo -n 'Use An Encrypted System? [y/n]: '
            read encrypt_system
            echo -n 'Are you sure? [y/n]: '
            read verify_encrypt

            [ $encrypt_system == $verify_encrypt ] \
                && break \
                || { clear; echo -e "\n - Answers Don't Match - \n"; } 
        done
    }

    run_installation_profile() {
        clear
        while true;
        do
            installation_profiles=(
                "Minimal Gnome"
                "No GUI"
            )

            echo -e "\n # Choose an installation profile"

            # Print the array elements in uniform columns
            for ((i=1;i<${#installation_profiles[@]}+1;i++)); do
                printf "\n %-2s  %-15s" "$i." "${installation_profiles[$i-1]}"
            done

            # Get the users profile choice
            echo -en "\n\n--> "
            read -r profile_int

            if [ $profile_int -gt 0 ];
            then
                # Convert back to strings for case for better code readability
                case ${installation_profiles[$profile_int-1]} in
                    "Minimal Gnome")
                        mv MiniArch/profiles/minimal-gnome.sh /mnt
                        arch-chroot /mnt bash minimal-gnome.sh
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
}

#----- Assign System and Partition Information to Variables -----

{
    pacman -Sy --noconfirm archlinux-keyring python || {
        echo -e "\n - Pacman had an error (are you connected to the internet?) - \n"
        exit 
    } 

    [ -d /sys/firmware/efi/efivars ] && uefi_enabled=True || uefi_enabled=False
    echo $uefi_enabled > uefi_state.temp

    # Run python script, exit if the script returns an error code
    python3 MiniArch/create_partition_table.py \
        || { echo -e "\n - Failed to create the partition table - \n"; exit; } 

    # Bring in variables put in files by the 'create_partition_table.py` script
    #  exiting if any are empty
    #
    boot_partition=$(cat boot_partition.temp)
    [[ -n $boot_partition ]] \
        || { echo -e "\n - No boot partition (probably a lack of disk space) - \n"; exit; } 

    existing_boot_partition=$(cat existing_boot_partition.temp)
    [[ -n $existing_boot_partition ]] \
        || { echo -e "\n - Something went wrong in create_partition_table.py - \n"; exit; } 

    root_partition=$(cat next_open_partition.temp)
    [[ -n $root_partition ]] \
        || { echo -e "\n - No root partition (probably a lack of disk space) - \n"; exit; } 

}


#----------------  Create and Format Partitions ---------------- 

{
    ask_set_encryption

    if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
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
        if [[ $uefi_enabled == True ]];
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
    # Install linux and linux-lts kernels, along with the most basic packages
    pacstrap /mnt \
        base linux linux-lts linux-firmware os-prober \
        xdg-user-dirs-gtk grub networkmanager sudo htop \
        base-devel git vim man-db man-pages || {
            echo -e "\n - Failed to pacstrap packages into /mnt (are you connected to the internet?) - \n"
            exit
        } 

    # Tell the system where the partitions are when starting
    genfstab -U /mnt >> /mnt/etc/fstab \
        || { echo -e "\n - Failed to write to fstab - \n"; exit; } 

    # Run a chroot with the chosen installation profile
    run_installation_profile

    # Move our final script to /mnt
    mv MiniArch/finish_install.sh /mnt

    # Create files to pass variables to finish_install.sh
    echo $encrypt_system > /mnt/encrypted_system.temp
    mv uefi_state.temp /mnt/
    mv next_open_partition.temp /mnt/
    mv boot_partition.temp /mnt/
    mv existing_boot_partition.temp /mnt/

    # Chroot into /mnt, and run the finish_install.sh script
    arch-chroot /mnt bash finish_install.sh \
        || { echo -e "\n - 'arch-chroot /mnt bash finish_install.sh' failed - \n"; exit; } 

    # After finish_install.sh is done
    umount -a

    clear

    echo -e '\n - Installation Successful! - \n'
    echo 'Rebooting in 10 seconds...'
    sleep 10

    reboot
}
