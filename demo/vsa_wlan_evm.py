"""89600 VSA (DSOS604A as analyzer): 802.11a demod at fc, EVM per scope channel.

usage: py vsa_wlan_evm.py [--fc 2e9] [--ch 1 2 3 4] [--n 10] [--leave 1]
Keeps only frames demodulated as 16-QAM (24 Mb/s), averages EVM (RMS over frames).
"""
import argparse, time, numpy as np, pyvisa

p = argparse.ArgumentParser()
p.add_argument('--addr', default='TCPIP0::localhost::hislip_vsa0::INSTR')
p.add_argument('--fc', type=float, default=2e9)
p.add_argument('--ch', type=int, nargs='+', default=[1, 2, 3, 4])
p.add_argument('--n', type=int, default=10, help='valid frames per channel')
p.add_argument('--rate', type=float, default=24e6, help='expected bit rate (24e6 = 16-QAM 1/2)')
p.add_argument('--leave', type=int, default=None, help='channel to leave displayed at the end')
a = p.parse_args()

v = pyvisa.ResourceManager().open_resource(a.addr); v.timeout = 120000
q = lambda s: v.query(s).strip()
def flush():
    while not q('SYST:ERR?').startswith('+0'): pass

v.write(':MEAS:CONF W11A'); q('*OPC?')
v.write(f':FREQ:CENT {a.fc}'); v.write(':FREQ:SPAN 40e6'); v.write(':INIT:CONT 1'); q('*OPC?')
# find the Syms/Errs table trace
tt = next(t for t in range(1, int(q(':TRAC:COUN?')) + 1) if 'Syms/Errs' in q(f':TRAC{t}:DATA:NAME?'))
res = {}
for ch in a.ch:
    v.write(f':INP:CHAN:CONF:CUST "{ch}"'); q('*OPC?')
    v.write(':INP:ANAL:RANG:AUTO'); q('*OPC?'); time.sleep(1.5)
    evm, pil, fe, iqo, last, tries = [], [], [], [], None, 0
    while len(evm) < a.n and tries < 6 * a.n:
        tries += 1; time.sleep(0.6)
        try:
            row = {k: float(q(f':TRAC{tt}:DATA:TABL? "{k}"')) for k in ('EVM', 'PilotEVM', 'FreqErr', 'IQOffset', 'BitRate', 'Syms')}
        except ValueError:
            continue                                     # '***' = no valid result this sweep
        key = (row['EVM'], row['Syms'], row['FreqErr'])
        if key == last or abs(row['BitRate'] - a.rate) > 1: continue   # stale or misdetected frame
        last = key; evm.append(row['EVM']); pil.append(row['PilotEVM']); fe.append(row['FreqErr']); iqo.append(row['IQOffset'])
    flush()
    if not evm:
        print(f'ch{ch}: no valid 16-QAM frames'); continue
    e = np.sqrt(np.mean(np.square(evm)))
    res[ch] = e
    print(f'ch{ch}: EVM {e:5.2f} %  ({20*np.log10(e/100):6.2f} dB)  min/max {min(evm):.2f}/{max(evm):.2f} %  '
          f'pilotEVM {np.mean(pil):6.1f} dB  freqErr {np.mean(fe):6.1f} Hz  IQoffset {np.mean(iqo):6.1f} dB  '
          f'range {q(":INP:ANAL:RANG?")} V  frames {len(evm)}')
if a.leave:
    v.write(f':INP:CHAN:CONF:CUST "{a.leave}"'); v.write(':INP:ANAL:RANG:AUTO'); q('*OPC?')
flush()
