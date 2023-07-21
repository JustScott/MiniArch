#----------------  Defining Functions ----------------

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

    if [ $username == $username_verify ]
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
      passwd $1
      if [ $? == 0 ]
      then
        break
      else
        clear
        echo -e " - Passwords Don't Match - \n"
      fi
   done
}


#----------------  System User Configuration ----------------
clear

# Use the 'set_username' function to get the system name
echo ' - Set System Name - '
set_username
system_name="$username"

echo "$system_name" > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '"$system_name" >> /etc/hosts
hostnamectl set-hostname "$system_name"

clear

# Set the root password
set_user_password root


#----------------  User Configuration ----------------
clear

echo -e ' - Set Your Username - '
set_username
useradd -m "$username"
clear
set_user_password "$username"
usermod -aG wheel,audio,video,storage "$username"


#----------------  System Settings & Packages ----------------
clear

chmod u+w /etc/sudoers
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers
chmod u-w /etc/sudoers

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen


#----------------  Swap File Configuration ----------------

# Creating the swapfile / swap space
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
echo '/swapfile none swap 0 0' >> /etc/fstab


#----------------  Grub Configuration ----------------
clear

uefi_enabled=`cat uefi_state.temp`

disk_label=`cat disk_label.temp`

disk_number=`cat disk_number.temp`

encrypt_system=`cat encrypted_system.temp`

if [ $encrypt_system == 'y' ] || [ $encrypt_system == 'Y' ] || [ $encrypt_system == 'yes' ]
then
  # Encryption configuration
  echo "GRUB_CMDLINE_LINUX='cryptdevice=/dev/${disk_number}2:cryptdisk'" >> /etc/default/grub
  echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
fi

echo -e '\nGRUB_DISABLE_OS_PROBER=false\nGRUB_SAVEDEFAULT=true\nGRUB_DEFAULT=saved' >> /etc/default/grub

pacman -S --noconfirm linux linux-lts
mkinitcpio --allpresets

# Actual Grub Install
if [ $uefi_enabled == True ]
then
  pacman -S --noconfirm efibootmgr dosfstools mtools
  grub-install --efi-directory=/boot
else
  grub-install /dev/${disk_label}
fi
grub-mkconfig -o /boot/grub/grub.cfg

#----------------  Final Touches  ----------------

# Enabling display and network managers
systemctl enable NetworkManager

rm encrypted_system.temp
rm uefi_state.temp
rm disk_label.temp
rm disk_number.temp
rm finish_install.sh

clear
exit
