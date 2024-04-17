#!/bin/bash
#
# update_arch_iso.sh - part of the MiniArch project
# Copyright (C) 2024, JustScott, development@justscott.me
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

ISO_URL="https://mirror.arizona.edu/archlinux/iso/latest/archlinux-x86_64.iso"
ISO_FILE="archlinux-x86_64.iso"

SHA256_URL="https://mirror.arizona.edu/archlinux/iso/latest/sha256sums.txt"


if sha256sum -c --ignore-missing <(curl -sL $SHA256_URL) &>/dev/null
then
    echo "ISO up-to-date!"
else
    echo -e "\n - ISO out of date...updating - \n"
    if curl -L $ISO_URL -o $ISO_FILE
    then
        if sha256sum -c --ignore-missing <(curl -sL $SHA256_URL) &>/dev/null
        then
            echo -e "\nDownloaded ISO matches hash!"
        else
            echo -e "\n - [ERROR] ISO sha256sum does not match remote sha256sum... exiting - \n"
            exit 1
        fi
    else
        echo -e "\n - [ERROR] Failed to download ISO... exiting - \n"
        exit 1
    fi
fi
