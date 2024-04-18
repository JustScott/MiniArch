# MiniArch
A Minimal `x86_64` Arch Linux Installer

## WARNING
**Dual booting with existing operating systems IS NOT supported** and existing
boot entries will more than likely be deleted from your boot partition. However,
after installing Arch you can use another distros installer to use the boot partition
created by MiniArch.

I hope to add this ability in the future.

## Steps to take before running the install script

```bash
# Connect to a network
#
#  You can find your Wifi Adapter name
#  via the `ip address` command, 
#  probably named "wlan0" or something
#  close to that 
#
wpa_passphrase <Network SSID> <Network Password> | tee /etc/wpa_supplicant.conf
wpa_supplicant -Bc /etc/wpa_supplicant.conf -i <Wifi Adapter>


pacman-key --init
pacman-key --populate
pacman -Sy git --noconfirm
# -- -- # 
# Only run the pacman commands below if you experience key errors
#  with the above pacman command
umount /etc/pacman.d/gnupg
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate
pacman -Sy archlinux-keyring git --noconfirm
# -- -- #

# Clone this repo
git clone https://www.github.com/JustScott/MiniArch.git

# Run the install script
bash MiniArch/start_install.sh
```

## Development
Testing is done in Virtual Machines to simulate a real environment. If you're
 using QEMU for virtualization, you can cd into the `tests` directory and run
 `make test` to automatically create a fresh Virtual Machine for testing. 


## Troubleshooting post installation issues (not related to MiniArch)

### UEFI System unable to find newly created boot partition
Sometimes motherboard creators only allow booting from partition with the
label "Windows Boot Partition"
```bash
# `-l` as in 'Lima' (some fonts make it hard to differentiate between 
#   uppercase I and lowercase l)
sudo efibootmgr -c -L "Windows Boot Manager" -l "\EFI\arch\grubx64.efi"
```
