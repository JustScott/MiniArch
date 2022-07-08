# <p align='center'>MiniArch</p>

<h3>Steps to take before running the install script</h3>
<br>

```python
$ cfdisk
# Create 3 paritions:
  |-> /dev/sda1 - 512M - bootable
  |-> /dev/sda2 - 2G - swap
  |-> /dev/sda3 - default

# Boot Parition
$ mkfs.ext4 /dev/sda1
$ mkdir /mnt/boot
$ mount /dev/sda1 /mnt/boot

# Swap Partition
$ mkswap /dev/sda2
$ swapon /dev/sda2

-- Formatting the filesystem parition -- 
  
# Encrypted Filesystem Partition
$ cryptsetup luksFormat -s 512 -h sha512 /dev/sda3
$ cryptsetup open /dev/sda3 cryptdisk
$ mkfs.ext4 /dev/mapper/cryptdisk
$ mount /dev/mapper/cryptdisk /mnt

  or

# Unencrypted Filesystem Partition
$ mkfs.ext4 /dev/sda3
$ mount /dev/sda3 /mnt

-- --

# Connecting to a network
$ iwctl
[iwd] device list # List the your computers network devices
[iwd] station wlan0 get-networks  # List the available networks
[iwd] station wlan0 connect <ssid>  # Connect to your network
[iwd] exit

# Put the basic linux dependices on your filesystem parition, + vim,git
$ pacman -Syu
$ pacstrap /mnt base linux linux-firmware vim git

# Clone this repo
$ git clone https://www.github.com/JustScott/MiniArch.git

# Run the install script
$ bash MiniArch/install.sh

```

