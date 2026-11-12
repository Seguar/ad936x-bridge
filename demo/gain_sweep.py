"""2-D sweep of AD9361 RX gain x TX attenuation in bridge mode; EVM from VSA per scope channel.

usage: py gain_sweep.py --rx 30 33 36 39 42 --tx 0 -5 -10 -15 --ch 2 3 --n 5 --csv sweep.csv
Leaves the board at --final-rx / --final-tx when done.
"""
import argparse, csv, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from iio_net import IIO

p = argparse.ArgumentParser()
p.add_argument('--host', default='192.168.0.99')
p.add_argument('--mxg-pow', type=float, default=None, help='set MXG power [dBm] before the sweep')
p.add_argument('--rx', type=float, nargs='+', default=[30, 33, 36, 39, 42])
p.add_argument('--tx', type=float, nargs='+', default=[0, -5, -10, -15])
p.add_argument('--ch', nargs='+', default=['2', '3'])
p.add_argument('--n', type=int, default=5)
p.add_argument('--csv', default='gain_sweep.csv')
p.add_argument('--final-rx', type=float, default=36); p.add_argument('--final-tx', type=float, default=-10)
a = p.parse_args()
c = IIO(a.host)
import re
PHY = [d for d, n in re.findall(r'<device id="([^"]+)" name="([^"]+)"', c.xml()) if n.startswith('ad9361-phy')]
print('phy devices:', PHY, flush=True)
if a.mxg_pow is not None:
    import pyvisa
    g = pyvisa.ResourceManager().open_resource(os.environ.get('MXG_ADDR', 'TCPIP0::<MXG_IP>::inst0::INSTR')); g.write(f':POW {a.mxg_pow}'); g.query('*OPC?')
    print('MXG power', g.query(':POW?').strip(), flush=True)


def setg(rx, tx):
    for d in PHY:
        for ch in ('voltage0', 'voltage1'):
            c.write(d, 'hardwaregain', rx, ch); c.write(d, 'hardwaregain', tx, ch, True)


here = os.path.dirname(os.path.abspath(__file__))
with open(a.csv, 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['rx_gain_dB', 'tx_att_dB', 'scope_ch', 'evm_pct', 'evm_dB', 'iq_offset_dB', 'range_V'])
    for tx in a.tx:
        for rx in a.rx:
            setg(rx, tx)
            out = subprocess.run([sys.executable, '-I', os.path.join(here, 'vsa_wlan_evm.py'), '--ch', *a.ch, '--n', str(a.n)],
                                 capture_output=True, text=True).stdout
            for line in out.splitlines():
                if not line.startswith('ch'): continue
                if 'no valid' in line:
                    w.writerow([rx, tx, line[2], '', '', '', '']); print(f'RX {rx:4.0f} TX {tx:4.0f} {line}', flush=True); continue
                t = line.replace('(', ' ').replace(')', ' ').split()
                evm, evmdb = float(t[2]), float(t[4]); iq = float(t[t.index('IQoffset') + 1]); rng = float(t[t.index('range') + 1])
                w.writerow([rx, tx, line[2], evm, evmdb, iq, rng]); f.flush()
                print(f'RX {rx:4.0f} TX {tx:4.0f}  ch{line[2]}: EVM {evm:5.2f} % ({evmdb:6.2f} dB)  IQoff {iq:6.1f}  range {rng} V', flush=True)
setg(a.final_rx, a.final_tx)
print(f'board left at RX {a.final_rx} dB, TX {a.final_tx} dB')
