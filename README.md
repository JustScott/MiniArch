# MiniArch
A Minimal `x86_64` Arch Linux Installer

## WARNING
**Dual booting with existing operating systems IS NOT supported** and existing
boot entries will more than likely be deleted from your boot partition. However,
after installing Arch you can use another distros installer to use the boot partition
created by MiniArch.

I hope to add this ability in the future.

## How to run

MiniArch can only operate on empty diskspace, as in, you must first make
space on your disk with something like `cfdisk` before MiniArch will make
the disk available to select for installation.

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

curl -L https://raw.githubusercontent.com/JustScott/MiniArch/refs/heads/main/install_repo.sh | bash
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
