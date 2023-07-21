#!/bin/bash

###
#
# The Minimal Gnome install profile.
#
#   This profile will only install the packages that are absolutely
#   necessary for gnome to function.
#
###

pacman -Sy gnome-control-center gnome-backgrounds gnome-terminal gnome-keyring gnome-logs gnome-settings-daemon gnome-calculator gnome-software gvfs malcontent mutter gdm nautilus xdg-user-dirs-gtk xorg --noconfirm

sudo systemctl enable gdm

clear
exit
