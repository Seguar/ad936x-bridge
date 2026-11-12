"""Put both AD9361s of the FMCOMMS5 into bridge mode (RF RX -> FPGA -> RF TX) at one LO.
usage: py setup_board.py [--host 192.168.0.99] [--lo 2e9] [--rxgain 35] [--txatt -25] [--fs 30.72e6] [--off]"""
import argparse, time
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from iio_net import IIO
p = argparse.ArgumentParser()
p.add_argument('--host', default='192.168.0.99'); p.add_argument('--lo', type=float, default=2e9)
p.add_argument('--rxgain', default='35'); p.add_argument('--txatt', type=float, default=-25)
p.add_argument('--off', action='store_true', help='disable loopback (TX silent)')
p.add_argument('--fs', type=float, default=None, help='sample rate to (re)apply after loopback; default: keep current')
p.add_argument('--no-resync', action='store_true', help='skip the sample-rate re-write (diagnostics)')
a = p.parse_args()
c = IIO(a.host)
import re
phys = [d for d, n in re.findall(r'<device id="([^"]+)" name="([^"]+)"', c.xml()) if n.startswith('ad9361-phy')]
for d in phys:
    c.write(d, 'frequency', int(a.lo), 'altvoltage0', True)          # RX LO
    c.write(d, 'frequency', int(a.lo), 'altvoltage1', True)          # TX LO
    for ch in ('voltage0', 'voltage1'):
        if a.rxgain == 'agc':
            c.write(d, 'gain_control_mode', 'slow_attack', ch)
        else:
            c.write(d, 'gain_control_mode', 'manual', ch); c.write(d, 'hardwaregain', float(a.rxgain), ch)
        c.write(d, 'hardwaregain', a.txatt, ch, True)
    c.write(d, 'loopback', 0 if a.off else 2, debug=True)          # 2 = FPGA RX->TX
if not a.off and not a.no_resync:
    # Re-applying the sample rate re-initialises the AD9361 digital interface. Without it the FPGA loopback
    # path can deliver a constant offset to the DACs (big carrier at the LO, independent of the input).
    for d in phys:
        fs = int(a.fs) if a.fs else int(c.read(d, 'sampling_frequency', 'voltage0'))
        c.write(d, 'sampling_frequency', fs, 'voltage0')
time.sleep(0.5)
for d in phys:
    print(d, 'RXLO', c.read(d, 'frequency', 'altvoltage0', True), 'TXLO', c.read(d, 'frequency', 'altvoltage1', True),
          'loopback', c.read(d, 'loopback', debug=True),
          '| rxgain', [c.read(d, 'hardwaregain', ch) for ch in ('voltage0', 'voltage1')],
          'rssi', [c.read(d, 'rssi', ch) for ch in ('voltage0', 'voltage1')],
          '| txatt', [c.read(d, 'hardwaregain', ch, True) for ch in ('voltage0', 'voltage1')])
