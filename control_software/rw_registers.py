import struct
import os


class RWRegisters(object):
    def __init__(self, dev, verbosity):
        print("%%%% Using device: {}".format(dev))
        self.fd_rd = os.open(dev, os.O_RDONLY)
        self.fd_wr = os.open(dev, os.O_WRONLY)

        self.verbosity = verbosity

    def read_reg(self, addr, size=4):
        fmt = "<{}".format("I" * (size // 4))
        rd_val = os.pread(self.fd_rd, size, addr)
        rd_val = struct.unpack(fmt, rd_val)[0]
        if self.verbosity > 0:
            print("%% Read {}-bits from address {}: {}".format(
                size * 8, hex(addr), hex(rd_val)))
        return rd_val

    def write_reg(self, addr, val, size=4):
        fmt = "<{}".format("I" * (size // 4))
        wr_val = struct.pack(fmt, val)
        wr_res = os.pwrite(self.fd_wr, wr_val, addr)
        if self.verbosity > 0:
            print("%% Write {}-bits value to address {}: {}".format(
                size * 8, hex(addr), hex(val)))

    def close(self):
        os.close(self.fd_rd)
        os.close(self.fd_wr)
        print("%%%% Closed file descriptors.")


if __name__ == "__main__":

    device = "/dev/xdma0_user"
    rw_reg = RWRegisters(device, 1)
    rw_reg.write_reg(addr=0x0, val=0x4, size=4)
    rw_reg.write_reg(addr=0x0, val=0x0, size=4)

    print("%% WRITE REGS %%")
    for i in range(16):
        rw_reg.read_reg(addr=0x4 * i, size=4)
    print("%% READ REGS %%")
    for i in range(16, 32):
        rw_reg.read_reg(addr=0x4 * i, size=4)

    rw_reg.close()
