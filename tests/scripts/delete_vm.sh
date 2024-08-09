#!/bin/bash
#
# delete_vm.sh - part of the MiniArch project
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


if virsh list --all | grep "$VM_NAME" &>/dev/null
then
    virsh destroy $VM_NAME &>/dev/null
    virsh undefine $VM_NAME \
        --managed-save \
        --snapshots-metadata \
        --checkpoints-metadata \
        --nvram \
        --storage $HOME/.local/share/libvirt/images/$VM_NAME.qcow2 \
        --tpm >/dev/null 2>>/tmp/miniarcherrors.log \
            && echo "Deleted old Virtual Machine!" \
            || { 
                echo "[FAIL] couldnt delete VM... wrote error log to /tmp/miniarcherrors.log"
                exit 1
            } 
fi
