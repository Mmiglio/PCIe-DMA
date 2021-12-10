from rw_registers import RWRegisters
import time
import yaml

class RWcontroller(RWRegisters):
	def __init__(self, dev, verbosity):
		super().__init__(dev, verbosity)

	def write_value(self, addr, start, width, value):
		write_mask = (2**width-1)<<start
		write_val = (value << start) & write_mask
		wr_res = self.write_reg(addr, write_val, size=4)

	def read_value(self, addr, start, width):
		read_val = self.read_reg(addr, size=4)
		read_mask = (2**width-1)
		read_val = (read_val >> start) & read_mask
		return read_val

	def handle_singlereg(self, curr_reg, op='r', data=None):
		"""
		Single operation
		"""
		if op == 'w' and data == None:
			print("%% Selected WRITE operation but \
				no data was passed to the function")
			return -1
		if op == 'r' and data != None:
			print("%% Selected READ operation but data \
				were passed to the function. Ignoring.")

		# perform operation
		if op == 'r':
			addr = curr_reg['addr']
			start = curr_reg['start']
			width = curr_reg['width']
			return self.read_value(addr, start, width)
		elif op == 'w':
			addr = curr_reg['addr']
			start = curr_reg['start']
			width = curr_reg['width']
			self.write_value(addr, start, width, data)

	def handle_multireg(self, reg_map, op='r', data=None):
		"""
		Operation with multiple registers
		"""
		if op == 'w' and data == None:
			print("%% Selected WRITE operation but \
				no data was passed to the function")
			return -1
		# an entry of reg map can be mapped into multiple
		# registers -> check data shape for write operation
		if op == 'w' and len(data) != len(reg_map):
			print("%% Size of data doesn't match size of\
				registers: {} vs. {}".format(len(data), len(reg_map)))
			return -1
		if op == 'r' and data != None:
			print("%% Selected READ operation but data \
				were passed to the function. Ignoring.")
		if op == 'r':
			res_list = list()
			for curr_reg in reg_map:
				name = curr_reg['name']
				addr = curr_reg['addr']
				start = curr_reg['start']
				width = curr_reg['width']

				read_val = self.read_value(addr, start, width)
				res_list.append({
					'reg': name,
					'val': read_val
				})
			return res_list
		elif op == 'w':
			for curr_reg in reg_map:
				name = curr_reg['name']
				addr = curr_reg['addr']
				start = curr_reg['start']
				width = curr_reg['width']

				curr_val = data[name]
				self.write_value(addr, start, width, curr_val)

def print_regs(regs):
	print('%%%%%%%%')
	for reg in regs:
		print('{} -> {}'.format(
			reg['reg'], hex(reg['val']))
		)
	print('%%%%%%%%')

if __name__=='__main__':

	# load reg cfg map
	with open("reg_map.yaml", "r") as stream:
		try:
			reg_cfg = yaml.safe_load(stream)
		except yaml.YAMLError as exc:
			print(exc)

	rw = RWcontroller('/dev/xdma0_user', 1)

	curr_reg = reg_cfg['rd_data_pll']
	rw.handle_multireg(curr_reg)
	
	rw.close()
	"""	device = "/dev/xdma0_user"
	rw_reg = RWRegisters(device, 1)
	print("%% Initial value %%")
	rw_reg.read_reg(addr=0x0, size=4)

	print("%% Trigger read %%")
	rw_reg.write_reg(addr=0x0, val=0x4, size=4)
	time.sleep(0.1)
	rw_reg.write_reg(addr=0x0, val=0x0, size=4)

	print("%% Check new value %%")
	rw_reg.read_reg(addr=0x0, size=4)

	rw_reg.close()"""