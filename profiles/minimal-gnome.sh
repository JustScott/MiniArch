#!/bin/bash
#
# miniaml-gnome.sh - part of the MiniArch project
# Copyright (C) 2023, Scott Wyman, development@justscott.me
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

###
#
# The Minimal Gnome install profile.
#
#   This profile will only install the packages that are absolutely
#   necessary for gnome to function.
#
###

pacman -Sy --noconfirm \
    gnome-control-center gnome-backgrounds gnome-terminal \
    gnome-keyring gnome-logs gnome-settings-daemon \
    gnome-calculator gnome-software gvfs malcontent mutter \
    gdm nautilus xdg-user-dirs-gtk xorg

sudo systemctl enable gdm

clear
exit
