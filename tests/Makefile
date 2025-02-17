#
# Makefile - part of the MiniArch project
# Copyright (C) 2024-2025, JustScott, development@justscott.me
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

VM_NAME := "MiniArchTestingVM"


update_iso:
	@bash scripts/update_arch_iso.sh

test: delete_vm create_vm

create_vm: update_iso
	@bash scripts/create_vm.sh ${VM_NAME}

delete_vm:
	@bash scripts/delete_vm.sh ${VM_NAME}

clean:
	rm /tmp/miniarcherrors.log
