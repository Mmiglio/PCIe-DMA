from rw_registers import RWcontroller

class Si570(object):
    def __init__(self,
                 rw_ctrl: RWcontroller,
                 reg_cfg: dict,
                 verbosity: int = 0) -> None:
        self.rw_ctrl = rw_ctrl
        self.f0 = 156.25  # MHz
        self.reg_cfg = reg_cfg
        self.verbosity = verbosity

    def set_freq(self, new_freq: float) -> None:
        # reset si570 default value
        self.rw_ctrl.handle_operation(curr_reg=self.reg_cfg['rst_si570'],
                                      op='a')
        # trigger read
        self.rw_ctrl.handle_operation(curr_reg=self.reg_cfg['rd_si570'],
                                      op='a')
        # read si570 registers
        reg_vals = []
        for reg_name in self.reg_cfg['si570_rd_reg']:
            r_val = self.rw_ctrl.handle_operation(
                curr_reg=self.reg_cfg[reg_name], op='r')
            reg_vals.append(r_val)

        # compute new values for target frequency
        new_reg_vals = self._compute_new_vals(new_freq=new_freq,
                                              data_reg=reg_vals,
                                              verbosity=self.verbosity)

        # write new values
        for reg_name, r_val in zip(self.reg_cfg['si570_wr_reg'], new_reg_vals):
            self.rw_ctrl.handle_operation(curr_reg=self.reg_cfg[reg_name],
                                          op='w',
                                          val=r_val)

        # trig write
        self.rw_ctrl.handle_operation(curr_reg=self.reg_cfg['wr_si570'],
                                      op='a')

        # trigger read
        self.rw_ctrl.handle_operation(curr_reg=self.reg_cfg['rd_si570'],
                                      op='a')

    def _compute_new_vals(self, new_freq, data_reg, verbosity):

        hs_div = get_hs_div(data_reg)
        n1 = get_n1(data_reg)
        ref_freq = get_rfreq(data_reg)

        # compute the nominal crystal frequency
        fxtal = (self.f0 * hs_div * n1) / ref_freq
        fxtal = round(fxtal, 6)

        if verbosity > 0:
            print("\n%%%% READ %%%%")
            print("%% HS_DIV: {}".format(hs_div))
            print("%% N1: {}".format(n1))
            print("%% RFREQ: {:.6f} MHz".format(ref_freq))
            print("%% => Nominal crystal frequency: {:.6f} MHz".format(fxtal))

        # check boundary for the new frequency
        fdco, new_hs_div, new_n1 = find_dividers(new_freq)
        if verbosity > 0:
            print("\n%%%% FOUND DIVIDERS %%%%")
            print("%% new HS_DIV: {}".format(new_hs_div))
            print("%% new N1: {}".format(new_n1))
            print("%% fdco: {} MHz".format(fdco))

        # compute new reference frequency
        new_ref_freq = int((fdco / fxtal) * 2**28)

        data_wr_reg = write_values(new_ref_freq, new_n1, new_hs_div)

        if verbosity > 0:
            print("\n%%%% CONFIGURATION FOR THE NEW FREQUENCY %%%%")
            for i in range(len(data_wr_reg)):
                print("%% register {:>2} -> {:>6}".format(
                    i + 7, hex(data_wr_reg[i])))
        return data_wr_reg


def write_values(ref_freq, n1, hs_div):
    """
    Create list with the new configurations
    => list with one entry for register, starting 7
    """
    # value for reg7
    # -> three bits for hs_div
    reg_7 = (hs_div - 4) << 5
    # -> 5 bits for n1
    reg_7 = reg_7 | ((n1 - 1) >> 2)

    # values for reg 8
    # -> two bits for N1
    reg_8 = (n1 - 1) & 0x3
    # -> 6 bits for rfreq
    reg_8 = (reg_8) << 6 | (ref_freq >> 32)

    # values for reg 9
    reg_9 = (ref_freq >> 24) & 0xff

    # values for reg 10
    reg_10 = (ref_freq >> 16) & 0xff

    # values for reg 11
    reg_11 = (ref_freq >> 8) & 0xff

    # values for reg 12
    reg_12 = ref_freq & 0xff

    data_wr_reg = [reg_7, reg_8, reg_9, (reg_10), reg_11, reg_12]

    return data_wr_reg


def find_dividers(f1):
    """
    Find valid dividers given the target frequency
    Start from a fixed HS_DIV and change N1
    """
    valid_hs_div = [4, 5, 6, 7, 9, 11]

    hd_div_idx = 3
    start_n1 = 1

    get_fdco = lambda f1, hs_div, n1: f1 * hs_div * n1

    num_it = 0
    curr_n1 = start_n1
    while num_it <= 500:
        curr_div = valid_hs_div[hd_div_idx]
        curr_fdco = get_fdco(f1, curr_div, curr_n1)

        if check_fdco(curr_fdco):
            return curr_fdco, curr_div, curr_n1
        else:
            if curr_fdco < 4900:
                if curr_n1 > 100:
                    curr_n1 = start_n1
                    hd_div_idx += 1
                else:
                    curr_n1 += 1
            elif curr_fdco > 5600:
                hd_div_idx -= 1
                curr_n1 = start_n1
        num_it += 1

    return 9999, 4, 7


def check_fdco(fdco):
    """
    The output dividers must ensure that the DCO 
    oscillation frequency (fdco) is between
    4.85 GHz <= fdco <= 5.67 GHz
    fdco = f1 * HS_DIV * N1
    """
    if (4900 <= fdco) and (fdco <= 5600):  # conservative choice
        return True
    else:
        return False


def get_rfreq(data_rd_reg):
    """
    Reference Frequency
    => first 6 bits of reg 8 (5 downto 0)
        reg9, reg10, reg11, reg12
    """
    reg_8 = data_rd_reg[1]

    # get bits 5 downto 0
    rfreq = reg_8 & 0x3F

    # concatenate with the value of other registers
    for data_reg in data_rd_reg[2:]:
        rfreq = (rfreq << 8) | data_reg

    return rfreq / 2**28


def get_n1(data_rd_reg):
    """
    CLKOUT output divider
    => first 5 bits of register 7 (4 downto 0)
        last 2 bits of register  8 (7 downto 6)
    """
    reg_7 = data_rd_reg[0]
    reg_8 = data_rd_reg[1]

    n1_7 = reg_7 & 0x3F
    n1_8 = reg_8 >> 6

    res = (n1_7 << 2 | n1_8) + 1
    return res


def get_hs_div(data_rd_reg):
    """
    high speed divider HS_DIV:
    => last 3 bits of register 7
        (bit 7 to 5)
    """
    reg_7 = data_rd_reg[0]

    # map from the datasheet
    # 000 = 4
    # 001 = 5
    # ...
    # 100, 111 not used
    HS_DIV = (reg_7 >> 5) + 4

    if HS_DIV in [8, 9]:
        return 9999
    else:
        return HS_DIV
