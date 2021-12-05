import os

fd_rd = os.open("/dev/xdma0_user", os.O_RDONLY)
fd_wr = os.open("/dev/xdma0_user", os.O_WRONLY)

num1 = 0xf

print("Writing num 1 to address 0:", num1.to_bytes(4, byteorder='big').hex())
os.pwrite(fd_wr, num1.to_bytes(4, byteorder='little'), 0x0)

rnum = os.pread(fd_rd, 4, 0x0)
print("First number: ", rnum[::-1].hex())

os.close(fd_rd)
os.close(fd_wr)