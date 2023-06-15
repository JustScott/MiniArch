import os
from copy import deepcopy


TERABYTE_IN_BYTES = 1099511627776
GIGABYTE_IN_BYTES = 1073741824
MEGABYTE_IN_BYTES = 1048576
SECTOR_SIZE = 512
# Converts gigabytes to sectors
terabytes_to_sectors = lambda terabytes: int((terabytes * TERABYTE_IN_BYTES) / SECTOR_SIZE) 
gigabytes_to_sectors = lambda gigabytes: int((gigabytes * GIGABYTE_IN_BYTES) / SECTOR_SIZE)
megabytes_to_sectors = lambda megabytes: int((megabytes * MEGABYTE_IN_BYTES) / SECTOR_SIZE) 


sectors_to_terabytes = lambda sectors: int((sectors * SECTOR_SIZE) / TERABYTE_IN_BYTES) 
sectors_to_gigabytes = lambda sectors: int((sectors * SECTOR_SIZE) / GIGABYTE_IN_BYTES)
sectors_to_megabytes = lambda sectors: int((sectors * SECTOR_SIZE) / MEGABYTE_IN_BYTES) 


def get_remaining_disk_space():
    '''
    Returns each disk, along with its remaining free space
    '''
    ## Filter the return of the lsblk command
    lsblk_output = os.popen('lsblk').read()
    rows = lsblk_output.split('\n')[1:]
    block_data = [list(filter(None,row.split(' '))) for row in rows]
    
    def convert_size_to_sector(size: str) -> int:
        size = size.lower()

        if 'm' in size:
            size = size.replace('m', '')
            if '.' in size:
                size = float(size)
            return megabytes_to_sectors(int(size))
        elif 'g' in size:
            size = size.replace('g', '')
            if '.' in size:
                size = float(size)
            return gigabytes_to_sectors(int(size))
        elif 't' in size:
            size = size.replace('t', '')
            if '.' in size:
                size = float(size)
            return terabytes_to_sectors(int(size))

    def disk_labels_sizes():
        disks = [row for row in block_data if 'disk' in row]
        return {row[0]:convert_size_to_sector(row[3]) for row in disks}

    def partition_labels_sizes():
        partitions = [row for row in block_data if 'part' in row]
        return {
            row[0].replace('├─','').replace('└─', ''):convert_size_to_sector(row[3]) 
            for row in partitions
        }


    disk_labels_sizes_dict = disk_labels_sizes()
    partition_labels_sizes_dict = partition_labels_sizes()


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

        if size_in_megabytes < 1000:
           disk_labels_sizes_dict[disk_label] = f'{size_in_megabytes}M'
        elif size_in_gigabytes < 1000:
            disk_labels_sizes_dict[disk_label] = f'{size_in_gigabytes}G'
        elif size_in_terabytes < 1000:
            disk_labels_sizes_dict[disk_label] = f'{size_in_terabytes}T'


    return disk_labels_sizes_dict


def get_disk_name(disk_labels_sizes_dict: dict):
    format_max_size = max(map(len,disk_labels_sizes_dict.keys()))

    ## Ask the User which disk to write over
    os.system('clear')
    while True:
        print(f'\n  Name  |  Free Space\n')

        new_disk_labels_sizes_dict = deepcopy(disk_labels_sizes_dict)
        for disk,size in disk_labels_sizes_dict.items():
            # Require a size above 5 gigabytes before displaying
            #  the disk as an option
            if 'm' in size.lower():
                del new_disk_labels_sizes_dict[disk]
                continue
            elif 'g' in size.lower():
                if int(size.lower().replace('g','')) < 5:
                    del new_disk_labels_sizes_dict[disk]
                    continue
            spacing = (format_max_size - len(disk)) + 3
            spacing *= " "
            print(f' {disk}{spacing}{size}')

        disk_label = input('\nType the name of the disk to install Arch on: ')
   
        disk_labels_sizes_dict = deepcopy(new_disk_labels_sizes_dict)
        if disk_label not in disk_labels_sizes_dict:
            os.system('clear')
            print("\n * Error: That disk isn't in the list! * \n")
            continue
        break

    if disk_label == 'nvme0n1':
        disk_numbering = 'nvme0n1p'
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

    # Convert disk_size to integer
    if disk_size.isdigit():
        int_disk_size = int(disk_size)
    else:
        int_disk_size = disk_size.lower()
        if 'g' in int_disk_size:
            int_disk_size = int_disk_size.replace('g','')
        if '.' in int_disk_size:
            int_disk_size = int(float(int_disk_size))
        else:
            int_disk_size = int(int_disk_size)


    while True:
        partition_size_in_gigabytes = input("Root partition size in Gigabytes (leave blank to fill disk): ")
        if not partition_size_in_gigabytes:
            return ''
        if partition_size_in_gigabytes.isdigit():
            if (
                int(partition_size_in_gigabytes) < int_disk_size
                and int(partition_size_in_gigabytes) > 5
            ):
                partition_size_in_gigabytes = int(partition_size_in_gigabytes)
                return gigabytes_to_sectors(partition_size_in_gigabytes)
            else:
                print(f'\n** Must be an integer smaller than {int_disk_size}, and larger than 5 gigabytes **')


        else:
            print('\n** Must be an integer, no characters or decimals! **')



## Writes the label and numbering to files for further use in the bash scripts
disk_label, disk_numbering, disk_size = get_disk_name(get_remaining_disk_space())
with open('disk_label.temp', 'w')as f:
    f.write(disk_label)
with open('disk_number.temp', 'w')as f:
    f.write(disk_numbering)

root_partition_size_in_sectors = get_partition_size(disk_size)

uefi = None

## Different table types are needed for uefi and none-uefi systems
with open('uefi_state.temp', 'r')as f:
    uefi = f.read().strip()

if uefi == 'True':
    table = f'''
label: gpt
device: /dev/{disk_label}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576,                          type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/{disk_numbering}2 : start=     1050624, size=     {root_partition_size_in_sectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
'''

elif uefi == 'False':
    table = f'''
label: dos
device: /dev/{disk_label}
unit: sectors
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576,                          type=83, bootable
/dev/{disk_numbering}2 : start=     1050624, size=     {root_partition_size_in_sectors}, type=83
'''


with open('partition_table.txt', 'w')as f:
    f.write(table)

os.system(f'sfdisk /dev/{disk_label} < partition_table.txt')

os.system('rm partition_table.txt')


