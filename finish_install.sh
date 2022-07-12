#----------------  Defining Functions ----------------

set_username() {
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

echo ' - Set System Name - '
set_username
system_name = $username

clear

# Set the root password
set_user_password root

echo $system_name > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '$system_name >> /etc/hosts


#----------------  User Configuration ----------------
clear

echo -e ' - Set Your Username - '
set_username
useradd -m $username
clear
set_user_password $username
usermod -aG wheel,audio,video,storage $username


#----------------  System Settings & Packages ----------------
clear

echo -e '\n##Appended to file via install script (MiniArch)\n%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen


#----------------  Grub Configuration ----------------
clear

uefi_enabled=`cat uefi_state.temp`
rm uefi_state.temp

encrypt_system=`cat encrypted_system.temp`
rm encrypted_system.temp

if [ $encrypt_system=='y' ] || [ $encrypt_system=='Y' ] || [ $encrypt_system=='yes' ]
then
  # Encryption configuration
  echo -e '\n#Appended to file via install script (MiniArch) \nGRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptdisk"' >> /etc/default/grub
  echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
fi

mkinitcpio -p linux
if [ $? != 0 ]
then
  pacman -S --noconfirm linux
  mkinitcpio -p linux

# Actual Grub Install
if [ $uefi_enabled == True ]
then
  pacman -S --noconfirm efibootmgr dosfstools os-prober mtools
  grub-install --target=x86_64-efi --bootloader-id=GRUB --recheck
else
  grub-install /dev/sda
fi
grub-mkconfig -o /boot/grub/grub.cfg

#----------------  Final Touches  ----------------

# Enabling display and network managers
systemctl enable gdm NetworkManager

clear

rm finish_install.sh

exit
