#!/bin/bash
#
# create_vm.sh - part of the MiniArch project
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

VM_NAME="$1"
ISO_FILE="archlinux-x86_64.iso"

VM_NAME="MiniArchTestingVM"
if ! virsh list --all | grep "$VM_NAME" &>/dev/null
then
    echo "...Create Virtual Machine: '$VM_NAME'..."
    virt-install \
        --name $VM_NAME \
        --memory 1024 \
        --vcpus 1 \
        --cdrom $ISO_FILE \
        --disk size=12,format=qcow2 \
        --boot uefi \
        --graphics spice \
        --os-variant=archlinux \
        --network user \
        --rng /dev/urandom >/dev/null 2>>/tmp/miniarcherrors.log \
            || { 
                echo "[FAIL] cant create VM... wrote error log to /tmp/miniarcherrors.log"
                exit 1
            }
else
    echo "[ERROR] VM already exists... delete the old VM before running again"
    exit 1
fi
