# <p align='center'>MiniArch</p>

<h3>Steps to take before running the install script</h3>
<br>

```python
# Connect to a network
#
#  You can find your Wifi Adapter name
#  via the `ip address` command, 
#  probably named "wlan0" or something
#  close to that 
#
wpa_passphrase <Network SSID> <Network Password> | tee /etc/wpa_supplicant.conf
wpa_supplicant -Bc /etc/wpa_supplicant.conf -i <Wifi Adapter>

# Sometimes it's necessary to install this to be able to install other packages
pacman -Sy archlinux-keyring --noconfirm

pacman -Sy git glibc --noconfirm

# Clone this repo
git clone https://www.github.com/JustScott/MiniArch.git

# Run the install script
bash MiniArch/start_install.sh

```

