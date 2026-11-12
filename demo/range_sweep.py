"""Scope input-range sweep: EVM vs. the VSA/scope range (volts peak) on given scope channels.

usage: py range_sweep.py --ch 2 3 --ranges 0.008 0.011 0.016 0.022 0.032 0.045 0.064 --n 5
Also prints the scope-specific parameters VSA exposes (INP:EXT:PAR?). Ends with autorange.
"""
import argparse, time, numpy as np, pyvisa

p = argparse.ArgumentParser()
p.add_argument('--ch', nargs='+', default=['2', '3'])
p.add_argument('--ranges', type=float, nargs='+', default=[0.008, 0.011, 0.016, 0.022, 0.032, 0.045, 0.064])
p.add_argument('--n', type=int, default=5)
a = p.parse_args()
v = pyvisa.ResourceManager().open_resource('TCPIP0::localhost::hislip_vsa0::INSTR'); v.timeout = 120000
q = lambda s: v.query(s).strip()
def flush():
    while not q('SYST:ERR?').startswith('+0'): pass
try:
    print('scope extension params:', q(':INP:EXT:PAR?')[:1500])
except Exception as e:
    print('no extension params:', e)
flush()
tt = next(t for t in range(1, int(q(':TRAC:COUN?')) + 1) if 'Syms/Errs' in q(f':TRAC{t}:DATA:NAME?'))
for ch in a.ch:
    v.write(f':INP:CHAN:CONF:CUST "{ch}"'); q('*OPC?')
    v.write(':INP:ANAL:RANG:AUTO'); q('*OPC?'); auto = float(q(':INP:ANAL:RANG?'))
    print(f'ch{ch}: autorange = {auto} V')
    for r in sorted(set(a.ranges + [auto])):
        v.write(f':INP:ANAL:RANG {r}'); q('*OPC?'); time.sleep(1.5)
        evm, last, tries = [], None, 0
        while len(evm) < a.n and tries < 40:
            tries += 1; time.sleep(0.6)
            try:
                row = [float(q(f':TRAC{tt}:DATA:TABL? "{k}"')) for k in ('EVM', 'Syms', 'FreqErr', 'BitRate')]
            except ValueError:
                continue
            if tuple(row[:3]) == last or abs(row[3] - 24e6) > 1: continue
            last = tuple(row[:3]); evm.append(row[0])
        stat = int(q(':MEAS:STAT?')); ovl = bool(stat & 2097152)
        flush()
        if evm:
            e = np.sqrt(np.mean(np.square(evm)))
            print(f'  range {q(":INP:ANAL:RANG?"):>8} V: EVM {e:5.2f} % ({20*np.log10(e/100):6.2f} dB){"  OVERLOAD" if ovl else ""}'
                  f'{"  <- auto" if abs(r-auto) < 1e-9 else ""}', flush=True)
        else:
            print(f'  range {r} V: no valid frames{"  OVERLOAD" if ovl else ""}', flush=True)
    v.write(':INP:ANAL:RANG:AUTO'); q('*OPC?')
flush()
