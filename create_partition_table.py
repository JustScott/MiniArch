import os

def get_disk_name():
	## Filter the return of the lsblk command
	lsblk_output = os.popen('lsblk').read()
	rows = lsblk_output.split('\n')[1:]
	disks = [row.split(' ')[0] for row in rows]
	disks = list(filter(None, disks))

	## Ask the User which disk to write over
	os.system('clear')
	while True:
		print(' - Disk Choices - \n')
		for disk in disks:
			print(disk)

		disk_label = input('\nType the name of the disk to install Arch on: ')
		
		if disk_label in disks:
			break
		else:
			os.system('clear')
			print("\n * Error: That disk isn't in the list! * \n")

	if disk_label == 'nvme0n1':
		disk_numbering = 'nvme0n1p'
	else:
		disk_numbering = disk_label

	return disk_label, disk_numbering


disk_label, disk_numbering = get_disk_name()


with open('disk_label.temp', 'w')as f:
	f.write(disk_label)
with open('disk_number.temp', 'w')as f:
	f.write(disk_numbering)
			
with open('uefi_state.temp', 'r')as f:
	uefi = f.read().strip()

if uefi == 'True':
	table = f'''
label: gpt
device: /dev/{disk_label}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/{disk_numbering}2 : start=     1050624, size=  , type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
'''

if uefi == 'False':
    table = f'''
label: dos
device: /dev/{disk_label}
unit: sectors
sector-size: 512

/dev/{disk_numbering}1 : start=        2048, size=     1048576, type=83, bootable
/dev/{disk_numbering}2 : start=     1050624, size=     , type=83
'''


with open('partition_table.txt', 'w')as f:
    f.write(table)

