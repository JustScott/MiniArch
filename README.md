# <p align='center'>MiniArch</p>

<h3>Steps to take before running the install script</h3>
<br>

```python
$ cfdisk
# Create 3 paritions:
  |-> /dev/sda1 - 512M - bootable
  |-> /dev/sda2 - 2G - swap
  |-> /dev/sda3 - default

# Connecting to a network
$ iwctl
[iwd] device list # List the your computers network devices
[iwd] station wlan0 get-networks  # List the available networks
[iwd] station wlan0 connect <ssid>  # Connect to your network
[iwd] exit

pacman -Sy git

# Clone this repo
$ git clone https://www.github.com/JustScott/MiniArch.git

# Run the install script
$ bash MiniArch/install.sh

```

