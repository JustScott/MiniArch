#!/bin/bash

#----------------  Defining Functions ----------------

{
    ask_set_encryption() {
        while : 
        do
            echo -n 'Use An Encrypted System? [y/N]: '
            read encrypt_system
            echo -n 'Are you sure? [y/N]: '
            read verify_encrypt

            [[ $encrypt_system == $verify_encrypt ]] \
                && break \
                || { clear; echo -e "\n - Answers Don't Match - \n"; } 
        done
    }

    run_installation_profile() {
        clear
        while true;
        do
            installation_profiles=("Minimal Gnome" "No GUI")

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

    [ -d /sys/firmware/efi/efivars ] && export uefi_enabled=true || export uefi_enabled=false
    echo "uefi_enabled=\"$uefi_enabled\"" >> activate_installation_variables.sh

    # Run python script, exit if the script returns an error code
    python3 MiniArch/create_partition_table.py \
        || { echo -e "\n - Failed to create the partition table - \n"; exit; } 

    source activate_installation_variables.sh
}


#----------------  Create and Format Partitions ---------------- 

{
    ask_set_encryption

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

    # Move necessary scripts to /mnt
    mv MiniArch/finish_install.sh /mnt
    mv activate_installation_variables.sh /mnt

    echo "encrypt_system=\"$encrypt_system\"" >> /mnt/activate_installation_variables.sh
    
    # Create files to pass variables to fin
    # Chroot into /mnt, and run the finish_install.sh script
    arch-chroot /mnt /bin/bash finish_install.sh \
        || { echo -e "\n - 'arch-chroot /mnt bash finish_install.sh' failed - \n"; exit; } 

    # After finish_install.sh is done
    umount -a

    clear

    echo -e '\n - Installation Successful! - \n'
    echo 'Rebooting in 10 seconds...'
    sleep 10

    reboot
}
