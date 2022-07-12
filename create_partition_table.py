import os

disk_labels = ['sda','nvme0n1','hda']

lsblk_output = os.popen('lsblk').read()
for label in disk_labels:
    if label in lsblk_output:
        disk_label = label
        disk_numbering = label
        if disk_label == 'nvme0n1':
            disk_numbering = 'nvme0n1p'
        break

with open('uefi_state.temp', 'r')as f:
    uefi = bool(f.read().strip())

if uefi:
    table = f'''
label: gpt
device: /dev/{disk_label}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/{disk_numbering}2 : start=     1050624, size=     4194304, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/{disk_numbering}3 : start=     5244928, size=  , type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
'''

else:
    table = f'''
label: dos
device: /dev/{disk_label}
unit: sectors
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576, type=83, bootable
/dev/{disk_numbering}2 : start=     1050624, size=     4194304, type=82
/dev/{disk_numbering}3 : start=     5244928, size=     , type=83
'''


with open('partition_table.txt', 'w')as f:
    f.write(table)
    
