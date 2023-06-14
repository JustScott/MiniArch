import os

def get_disk_name():
    ## Filter the return of the lsblk command
    lsblk_output = os.popen('lsblk').read()
    rows = lsblk_output.split('\n')[1:]
    disk_data = [list(filter(None,row.split(' '))) for row in rows]
    disks = [row for row in disk_data if 'disk' in row]
    disk_labels = [row[0] for row in disks]
    disk_sizes = [row[3] for row in disks]

    format_max_size = max(map(len,disk_labels))

    ## Ask the User which disk to write over
    os.system('clear')
    while True:
        print(f'\n  Name  |  Size\n')

        for disk,size in zip(disk_labels, disk_sizes):
            spacing = (format_max_size - len(disk)) + 3
            spacing *= " "
            print(f' {disk}{spacing}{size}')

        disk_label = input('\nType the name of the disk to install Arch on: ')
    
        if disk_label in disk_labels:
            if 'g' not in disk_sizes[disk_labels.index(disk_label)].lower():
                os.system('clear')
                print(f"\n * {disk_label} isn't large enough * \n")
                continue
            break
        else:
            os.system('clear')
            print("\n * Error: That disk isn't in the list! * \n")

    if disk_label == 'nvme0n1':
        disk_numbering = 'nvme0n1p'
    else:
        disk_numbering = disk_label

    disk_size = disk_sizes[disk_labels.index(disk_label)]

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
    gigabyte_in_bytes = 1024*1024*1024
    default_sector_size = 512

    convert_gigabytes_to_sectors = lambda gigabytes,sector_size: int((gigabytes * gigabyte_in_bytes) / sector_size)

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
            if int(partition_size_in_gigabytes) < int_disk_size:
                partition_size_in_gigabytes = int(partition_size_in_gigabytes)
                return convert_gigabytes_to_sectors(partition_size_in_gigabytes, default_sector_size)
            else:
                print(f'\n** Must be an integer smaller than {int_disk_size} **')

        else:
            print('\n** Must be an integer, no characters or decimals! **')



## Writes the label and numbering to files for further use in the bash scripts
disk_label, disk_numbering, disk_size = get_disk_name()
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


