from rw_registers import RWRegisters
import time
import yaml


class RWcontroller(RWRegisters):
    def __init__(self, dev, verbosity):
        super().__init__(dev, verbosity)

    def write_value(self, addr, start, width, value):
        # read current reg content
        curr_val = self.read_reg(addr, 4)

        # modify only the selected bits
        write_mask = (2**width - 1) << start
        not_mask = (2**32 - 1) - write_mask
        write_val = ((value << start) & write_mask) | (not_mask & curr_val)
        print(hex(write_val))
        self.write_reg(addr, write_val, size=4)

    def read_value(self, addr, start, width):
        read_val = self.read_reg(addr, size=4)
        read_mask = (2**width - 1)
        read_val = (read_val >> start) & read_mask
        return read_val


if __name__ == '__main__':

    # load reg cfg map
    with open("reg_map.yaml", "r") as stream:
        try:
            reg_cfg = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    rw = RWcontroller('/dev/xdma0_user', 1)

    curr_reg = reg_cfg['data_wr_reg7']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x61)
    curr_reg = reg_cfg['data_wr_reg8']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x42)
    curr_reg = reg_cfg['data_wr_reg9']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0xc1)
    curr_reg = reg_cfg['data_wr_reg10']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x99)
    curr_reg = reg_cfg['data_wr_reg11']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0xee)
    curr_reg = reg_cfg['data_wr_reg12']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x47)

    #write new freqs
    curr_reg = reg_cfg['wr_pll_reg']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x1)
    time.sleep(0.1)
    rw.write_value(addr, start, width, 0x0)

    curr_reg = reg_cfg['rst_pll_freq']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x1)
    time.sleep(0.1)
    rw.write_value(addr, start, width, 0x0)

    curr_reg = reg_cfg['rd_pll_reg']
    addr = curr_reg['addr']
    start = curr_reg['start']
    width = curr_reg['width']
    rw.write_value(addr, start, width, 0x1)
    time.sleep(0.1)
    rw.write_value(addr, start, width, 0x0)

    rw.close()