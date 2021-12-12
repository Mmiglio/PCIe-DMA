from rw_registers import RWcontroller
from components import Si570
import time
import yaml

if __name__ == '__main__':

    # load reg cfg map
    with open("reg_map.yaml", "r") as stream:
        try:
            reg_cfg = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    rw_ctrl = RWcontroller('/dev/xdma0_user', 1)
    c_si570 = Si570(rw_ctrl, reg_cfg, 1)
    c_si570.set_freq(120)
    rw_ctrl.dump_regs(16)

    # close controller
    rw_ctrl.close()