# <p align='center'>MiniArch</p>

<h3>Steps to take before running the install script</h3>
<br>

```python
$ cfdisk
# Create 3 paritions:
  |-> /dev/sda1 - 512M - bootable
  |-> /dev/sda2 - 2G - swap
  |-> /dev/sda3 - default

# Download git, and clone this repo
$ pacman -S git --noconfirm
$ git clone https://www.github.com/JustScott/MiniArch.git

# Run the install script
$ bash MiniArch/install.sh

```

