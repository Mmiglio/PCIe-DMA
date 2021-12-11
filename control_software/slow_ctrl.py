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
        self.write_reg(addr, write_val, size=4)
        return 0

    def read_value(self, addr, start, width):
        read_val = self.read_reg(addr, size=4)
        read_mask = (2**width - 1)
        read_val = (read_val >> start) & read_mask
        return read_val

    def dump_regs(self, nregs):
        print("%%%% Read all regs %%%%")
        print("%% WRITE REGS %%")
        for i in range(nregs):
            self.read_reg(addr=0x4 * i, size=4)
        print("%% READ REGS %%")
        for i in range(nregs, nregs * 2):
            self.read_reg(addr=0x4 * i, size=4)

    def handle_operation(self, curr_reg, op='r', val=None):
        if op not in ['r', 'w', 'a']:
            print("Invalid request. Use `r`/`w`/`a` for \
                read/write/activate operations")
            return -1
        if op == 'w' and val == None:
            print("Selected write operation but no data \
                have been passed")
            return -1

        addr = curr_reg['addr']
        start = curr_reg['start']
        width = curr_reg['width']

        if op == 'r':
            return self.read_value(addr, start, width)
        elif op == 'w':
            self.write_value(addr, start, width, val)
        elif op == 'a':
            self.write_value(addr, start, width, 0x1)
            time.sleep(0.1)
            self.write_value(addr, start, width, 0x0)


if __name__ == '__main__':

    # load reg cfg map
    with open("reg_map.yaml", "r") as stream:
        try:
            reg_cfg = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    rw_ctrl = RWcontroller('/dev/xdma0_user', 1)

    # reset to default value
    rw_ctrl.handle_operation(curr_reg=reg_cfg['rst_si570'], op='a')

    # trigger read
    rw_ctrl.handle_operation(curr_reg=reg_cfg['rd_si570'], op='a')

    # read si570 registers
    for reg_name in reg_cfg['si570_rd_reg']:
        r_val = rw_ctrl.handle_operation(curr_reg=reg_cfg[reg_name], op='r')
        print("reg: {} -> {}".format(reg_name, hex(r_val)))
    
    # dump registers
    rw_ctrl.dump_regs(16)

    # close controller
    rw_ctrl.close()