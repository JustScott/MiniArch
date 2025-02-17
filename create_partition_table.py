#
# create_partition_table.py - part of the MiniArch project
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


import os

__author__ = "Scott Wyman (development@justscott.me)"

__license__ = "GPLv3"

__date__ = "February 26, 2024"

__all__ = []

__doc__ = (
'''
Creates the partition table and gives the necessary partition information
 to the rest of the bash scripts.
'''
)

import os
from copy import deepcopy
import subprocess
import json

# Need the size in bytes for conversion to sectors
TERABYTE_IN_BYTES = 1099511627776
GIGABYTE_IN_BYTES = 1073741824
MEGABYTE_IN_BYTES = 1048576
# Default sector size used for the partitions
SECTOR_SIZE = 512

# Converts terabytes, gigabytes, and megabytes to sectors
terabytes_to_sectors = lambda terabytes: int((terabytes * TERABYTE_IN_BYTES) / SECTOR_SIZE) 
gigabytes_to_sectors = lambda gigabytes: int((gigabytes * GIGABYTE_IN_BYTES) / SECTOR_SIZE)
megabytes_to_sectors = lambda megabytes: int((megabytes * MEGABYTE_IN_BYTES) / SECTOR_SIZE) 

# Converts sectors to terabytes, gigabytes, and megabytes
sectors_to_terabytes = lambda sectors: int((sectors * SECTOR_SIZE) / TERABYTE_IN_BYTES) 
sectors_to_gigabytes = lambda sectors: int((sectors * SECTOR_SIZE) / GIGABYTE_IN_BYTES)
sectors_to_megabytes = lambda sectors: int((sectors * SECTOR_SIZE) / MEGABYTE_IN_BYTES) 

# Minimum size in Gigabytes for the root partition
MIN_PARTITION_SIZE = 8

def convert_size_to_sector(disk_size: str) -> int:
    '''
    Converts the size of a disk from megabytes, gigabytes, or terabytes, to
    sectors of the size 512.

    Args:
        disk_size (str):
            The size of the disk as formatted by the lsblk command, 
            example: '480G' or '552M'
    '''
    size = disk_size.lower()

    suffix_func = {
        'm': megabytes_to_sectors,
        'g': gigabytes_to_sectors,
        't': terabytes_to_sectors
    }


    for suffix, conversion_func in suffix_func.items():
        if suffix in size:
            return conversion_func(
                int(float(size.replace(suffix, '')))
            )

def get_remaining_disk_space() -> dict:
    '''
    Returns each disk, along with its remaining free space

    Args:
        None

    Returns:
        dict:
            A dict containing the disks and labels.
            {
                'sda': '900G',
                'sdb': '1T',
                'sdc': '560M'
            }
        disk_labels_sizes_dict
    '''
    ## Filter the return of the lsblk command
    lsblk_output = os.popen('lsblk').read()
    rows = lsblk_output.split('\n')[1:]
    block_data = [list(filter(None,row.split(' '))) for row in rows]
    

    def disk_labels_sizes() -> dict:
        '''
        Get the disk labels and their sizes (in sectors) from the 
        lsblk command's output

        Args:
            None

        Returns:
            dict:
                A dict of each disk's label, and its 
                corresponding size in sectors
                {
                    'disk_label': int(disk_size),
                    'sda1': 123456
                }
        '''
        disks = [row for row in block_data if 'disk' in row]
        return {
            row[0]:convert_size_to_sector(row[3])
            for row in disks
        }

    def partition_labels_sizes() -> dict:
        '''
        Get the partitions and their sizes (in sectors) from the 
        lsblk command's output

        Args:
            None

        Returns:
            dict:
                A dict of each partition's label, and its 
                corresponding sector size
                {
                    'partition_label': int(partition_size),
                    'sda1': 123456
                }
        '''
        partitions = [row for row in block_data if 'part' in row]
        return {
            row[0].replace('├─','').replace('└─', ''):convert_size_to_sector(row[3]) 
            for row in partitions
        }

    # Disks and their free space, ignoring filled up disks
    disk_labels_sizes_dict = {
        key:value 
        for key,value in disk_labels_sizes().items()
        if value
    }
    partition_labels_sizes_dict = partition_labels_sizes()

    # Go through each disks partitions and subtract taken space from the total
    #  size to get the disks free space
    for disk_label,disk_size in disk_labels_sizes_dict.items():
        for partition_label,partition_size in partition_labels_sizes_dict.items():
            if disk_label in partition_label:
                disk_labels_sizes_dict[disk_label] = (
                    disk_labels_sizes_dict[disk_label]-partition_size
                )
                if disk_labels_sizes_dict[disk_label] < 0:
                    disk_labels_sizes_dict[disk_label] = 0

        size_in_megabytes = sectors_to_megabytes(disk_labels_sizes_dict[disk_label])
        size_in_gigabytes = sectors_to_gigabytes(disk_labels_sizes_dict[disk_label])
        size_in_terabytes = sectors_to_terabytes(disk_labels_sizes_dict[disk_label])

        # Convert to the next largest unit if above 1000 of the current,
        #  up to terabytes
        if size_in_megabytes < 1000:
           disk_labels_sizes_dict[disk_label] = f'{size_in_megabytes}M'
        elif size_in_gigabytes < 1000:
            disk_labels_sizes_dict[disk_label] = f'{size_in_gigabytes}G'
        # If the size is greater than 1000 Gigabytes and Megabytes,
        #  convert it to terabytes, even if over 1000 terabytes
        elif True:
            disk_labels_sizes_dict[disk_label] = f'{size_in_terabytes}T'


    return disk_labels_sizes_dict


def get_disk_information(disk_labels_sizes_dict: dict) -> tuple[str,str,str]:
    '''
    Prompts the user to choose a disk for their partitions, and returns
    the disks label, partition numbering scheme, and remaining space

    Args:
        disk_labels_sizes_dict (dict):
            The systems disks and their remaining free space

    Returns:
        str:
            The chosen disks label
        str:
            The chosen disks partition numbering scheme
        str:
            The chosen disks remaining free space
    '''
    format_max_size = max(map(len,disk_labels_sizes_dict.keys()))

    ## Ask the User which disk to write over
    while True:
        print(f'\n  Name  |  Free Space\n')

        suitable_disk_option = False

        new_disk_labels_sizes_dict = deepcopy(disk_labels_sizes_dict)
        for disk,size in disk_labels_sizes_dict.items():
            # Require a size above 5 gigabytes before displaying
            #  the disk as an option
            if 'm' in size.lower():
                del new_disk_labels_sizes_dict[disk]
                continue
            elif 'g' in size.lower():
                if int(size.lower().replace('g','')) < MIN_PARTITION_SIZE:
                    del new_disk_labels_sizes_dict[disk]
                    continue

            suitable_disk_option = True

            spacing = (format_max_size - len(disk)) + 3
            spacing *= " "
            print(f' {disk}{spacing}{size}')

        # If none of the disks are large enough for installation
        if not suitable_disk_option:
            print('\nNone of the disks have enough free space for installation')
            print('Please make space before attempting to install again...\n')
            quit(1)

        disk_label = input('\nType the name of the disk to install Arch on: ')

        disk_labels_sizes_dict = deepcopy(new_disk_labels_sizes_dict)
        if disk_label not in disk_labels_sizes_dict:
            os.system('clear')
            print("\n * Error: That disk isn't in the list! * \n")
            continue
        break

    if disk_label[-1].isdigit():
        disk_numbering = disk_label + 'p'
    else:
        disk_numbering = disk_label

    disk_size = disk_labels_sizes_dict[disk_label]

    return disk_label, disk_numbering, disk_size


def get_partition_size(disk_size:str) -> int:
    '''
    Gets the user requested partition size (in sectors)

    Args:
        disk_size (str):
            The size of the disk where the partitions will be
            stored (user chosen). Should be formatted like so: '250G'.

    Returns:
        int:
            Requested size of the partition in sectors
    '''

    sectors = convert_size_to_sector(disk_size)
    disk_size = sectors_to_gigabytes(sectors)

    while True:
        partition_size_in_gigabytes = input("Root partition size in Gigabytes (leave blank to fill remaining disk space): ")
        if not partition_size_in_gigabytes:
            return '' # Fills remaining disk free space
        if partition_size_in_gigabytes.isdigit():
            if (
                int(partition_size_in_gigabytes) < disk_size
                and int(partition_size_in_gigabytes) >= MIN_PARTITION_SIZE
            ):
                partition_size_in_gigabytes = int(partition_size_in_gigabytes)
                return gigabytes_to_sectors(partition_size_in_gigabytes)
            else:
                print(f'\n**Must be an integer less than {disk_size} Gigabytes, and greater than {MIN_PARTITION_SIZE-1} Gigabytes.**')


        else:
            print('\n** Must be an integer, no characters or decimals! **')


# Alias to subprocess.run to avoid entering all the arguments each time
#  it's used
run_command = lambda command: subprocess.run(
    command,
    shell=True,
    capture_output=True,
    text=True
)    

def write_vars_to_file(
        boot_partition: str, 
        existing_boot_partition: bool, 
        next_open_partition: str
    ):
    '''
    Writes variables to files so the bash scripts can read them
    '''
    with open("activate_installation_variables.sh", "a") as file:
        file.write(f"\nboot_partition=\"{boot_partition}\"")
        file.write(f"\nexisting_boot_partition={str(existing_boot_partition)}")
        file.write(f"\nroot_partition=\"{next_open_partition}\"")

def create_partition_table(
        uefi: bool, 
        root_partition_size_in_sectors: int, 
        disk_label: str, 
        disk_numbering: str
    ) -> str | None:
    '''
    Creates the partition table and writes it to the disk

    Args:
        uefi (bool): 
            Whether the system is uefi or not defines the type
            of partition table to use

        root_partition_size_in_sectors (int): As the name implies

    Returns:
        str: The next open partition
        OR
        None: if something failed and the partition table wasn't written to disk
    '''
    existing_partition_table = run_command(f"sfdisk /dev/{disk_label} -d")
    # Get the json output
    existing_partition_table_json = run_command(f"sfdisk /dev/{disk_label} -J")
    # Convert the json to a dict
    partitions_dict = {}
    try:
        partitions_dict = json.loads(existing_partition_table_json.stdout)
    except json.decoder.JSONDecodeError:
        pass

    # Default next partition when no others exist on the disk (boot takes 1)
    next_open_partition = f"/dev/{disk_numbering}2"

    # If no partitions exist on this disk, create a new partition table from scratch
    if "partitions" not in partitions_dict.get("partitiontable", {}):
        if uefi:
            table = f'''
label: gpt
device: /dev/{disk_label}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576,                          type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
{next_open_partition} : start=     1050624, size=     {root_partition_size_in_sectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
'''

        elif not uefi:
            table = f'''
label: dos
device: /dev/{disk_label}
unit: sectors
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576,                          type=83, bootable
{next_open_partition} : start=     1050624, size=     {root_partition_size_in_sectors}, type=83
'''

    # If a partition table exists
    else:
        # Loop through the disk to find the partition using the last blocks
        top_start_block = 0
        top_start_partition_size = 0
        top_start_partition_name = ""
        for partition_dict in partitions_dict["partitiontable"]["partitions"]:
            if partition_dict["start"] > top_start_block:
                top_start_block = partition_dict["start"]
                top_start_partition_size = partition_dict["size"]
                top_start_partition_name = partition_dict["node"]

        # The next open partition number will be the last partition number +1
        next_open_partition = f"/dev/{disk_numbering}{int(top_start_partition_name[-1])+1}"
        # The next partitions start block will be the last partitions start + size
        next_partition_start_block = top_start_block + top_start_partition_size

        partition_type = "83"
        if uefi:
            partition_type = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"

        new_partition_entry = f"/dev/{disk_numbering}{next_open_partition} : start=     {next_partition_start_block}, size=     {root_partition_size_in_sectors}, type={partition_type}"

        table = existing_partition_table.stdout + new_partition_entry

    if table:
        with open('partition_table.txt', 'w') as file:
            file.write(table)

        os.system(f'sfdisk /dev/{disk_label} < partition_table.txt')

        os.system('rm partition_table.txt')

        return next_open_partition


def get_boot_partition_information(next_open_partition: str, disk_numbering: str) -> tuple[bool, str]:
    '''
    If a new partition was appended to an existing partition 
    table, find the name of the existing boot partition in that table
    (for mounting and updating grub in the installation scripts)

    Args:
        str: The next open partition space, ex) '/dev/vda3'

        str: 
            Disk names that end in an integer, like 'nvme0n1', need a character
            like 'p' before the partition number, ex) '/dev/nvme0n1p3'. So this
            parameter should be something like: 'vda' or 'nvme0n1p'.

    Returns:
        bool: True if there's existing boot partition

        str: 
            Either the existing boot partition, or the partition
            that will be made into the new boot partition
    '''
    # These will be returned if the conditions below aren't met
    boot_partition = f"/dev/{disk_numbering}1"
    existing_boot_partition = False

    # If there are other partitions on the disk
    if next_open_partition != f"/dev/{disk_numbering}2":
        # Get the existing partiton table
        output = run_command(f"parted /dev/{disk_label} print -j")
        if output.returncode == 0:
            disk_dict = json.loads(output.stdout)
            # Loop each partition checking for the boot flag
            for partition_info_dict in disk_dict["disk"]["partitions"]:
                if "flags" in partition_info_dict:
                    if "boot" in partition_info_dict["flags"]:
                        partition_number = partition_info_dict["number"]
                        boot_partition = f"/dev/{disk_numbering}{partition_number}"
                        existing_boot_partition = True
                        break

    return existing_boot_partition, boot_partition



if __name__=="__main__":
    disk_label_remaining_size_dict = get_remaining_disk_space()

    disk_label, disk_numbering, disk_size = get_disk_information(
        disk_label_remaining_size_dict
    )

    root_partition_size_in_sectors = get_partition_size(disk_size)

    uefi_string = os.environ["uefi_enabled"].lower()
    if uefi_string == 'true':
        uefi = True
    elif uefi_string == 'false':
        uefi = False
    else:
        quit(1)

    next_open_partition = create_partition_table(
        uefi, 
        root_partition_size_in_sectors,
        disk_label, 
        disk_numbering
    )

    existing_boot_partition, boot_partition = get_boot_partition_information(
        next_open_partition, disk_numbering
    )

    write_vars_to_file(boot_partition, existing_boot_partition, next_open_partition)

