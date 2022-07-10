# Remove this script to remove clutter now that its running
rm finish_install.sh

#----------------  System User Configuration ----------------
clear

echo -n 'Enter System Name: '
read system_name
echo System Name Set as $system_name

clear

# Set the root password
echo '- Set root password -'
passwd

echo $system_name > /etc/hostname
echo -e '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   '$system_name >> /etc/hosts


#----------------  User Configuration ----------------
clear

echo ' - Create A User - '
echo -n 'Enter Username: '
read username
echo Username set as $username

useradd -m $username
passwd $username
usermod -aG wheel,audio,video,storage $username


#----------------  System Settings & Packages ----------------
clear

# Install the default pacman application
pacman -S --noconfirm gnome-control-center gnome-backgrounds gnome-terminal gnome-settings-daemon gnome-calculator gdm file-roller grub xorg networkmanager sudo htop base-devel vim git man-db man-pages

echo -e '\n##Appended to file via install script (MiniArch)\n%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

# Set the keyboard orientation
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG='en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
locale-gen


#----------------  Grub Configuration ----------------
clear

encrypt_system=`cat temp_var.txt`
rm temp_var.txt

if [ $encrypt_system=='y' ] || [ $encrypt_system=='Y' ] || [ $encrypt_system=='yes' ]
then
  # Encryption configuration
  echo -e '\n#Appended to file via install script (MiniArch) \nGRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptdisk"' >> /etc/default/grub
  echo -e 'MODULES=()\nBINARIES=()\nFiles=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)' > /etc/mkinitcpio.conf
fi

mkinitcpio -p linux

# Actual Grub Install
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

#----------------  Final Touches  ----------------

# Enabling display and network managers
systemctl enable gdm NetworkManager

clear

echo -e '\n Type 'exit' to finish the installation \n'

exit
