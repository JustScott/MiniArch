#----------------  Defining Functions ----------------

{
    set_username() {
        #
        # Doesn't actually set the username, just returns it in
        #  the variable '$username'
        #
        while : 
        do
            echo -n 'Enter Username: '
            read username
            echo -n 'Verify Username: '
            read username_verify

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

    set_user_password() {
        echo -e "\n - Set Password for '$1' - "
        while :
        do
            passwd $1 \
                && break \
                || { clear; echo -e " - Passwords Don't Match - \n"; } 
        done
    }
}


#----------------  System Configuration ----------------

{
    clear
    # Use the 'set_username' function to get the system name
    echo ' - Set System Name - '
    set_username
    system_name="$username"

    echo "$system_name" > /etc/hostname
    echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
}


#----------------  User Configuration ----------------

{
    clear
    echo -e ' - Set Your Username - '
    set_username
    useradd -m "$username"

    clear
    set_user_password "$username"
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
    source /activate_installation_variables.sh

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
    rm /activate_installation_variables.sh

    exit
}
