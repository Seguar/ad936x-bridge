"""Inter-channel phase / delay / gain of the 4 bridge outputs, measured directly on the DSOS604A.

Pauses VSA (if running), captures CH1..CH4 simultaneously, digitally downconverts at fc,
and compares every channel to CH1. Repeats --n times to show stability.
usage: py phase_check.py --scope TCPIP0::<SCOPE_IP>::hislip0::INSTR [--fc 2e9] [--n 10] [--csv out.csv]
"""
import argparse, time, numpy as np, pyvisa
from numpy.fft import fft, ifft

p = argparse.ArgumentParser()
p.add_argument('--scope', required=True)
p.add_argument('--vsa', default='TCPIP0::localhost::hislip_vsa0::INSTR')
p.add_argument('--fc', type=float, default=2e9)
p.add_argument('--bw', type=float, default=9e6, help='one-sided analysis bandwidth')
p.add_argument('--n', type=int, default=10)
p.add_argument('--tspan', type=float, default=20e-6, help='capture length [s]')
p.add_argument('--vdiv', type=float, default=0.005)
p.add_argument('--csv', default=None)
p.add_argument('--vsa-analyzer', default='Analyzer3', help='VSA hardware config of the scope, restored at the end')
a = p.parse_args()
rm = pyvisa.ResourceManager()

vsa = None
try:
    vsa = rm.open_resource(a.vsa, open_timeout=3000); vsa.timeout = 60000
    vsa.write(':INIT:CONT 0'); vsa.write(':INIT:ABOR'); vsa.query('*OPC?')
    vsa.write(':SYST:VSA:HARD:CONF:SEL:ANAL "Analyzer1"'); vsa.query('*OPC?')   # release the scope lock
except Exception:
    vsa = None

s = rm.open_resource(a.scope); s.timeout = 120000
w = s.write; q = lambda c: s.query(c).strip()
w(':STOP'); w(':ACQ:MODE RTIM'); w(':ACQ:SRAT:ANAL 20E9')
w(':ACQ:POIN:AUTO OFF'); w(f':ACQ:POIN {int(a.tspan*20e9)}')
w(f':TIM:SCAL {a.tspan/10}'); w(':TIM:POS 0'); w(':TRIG:SWE AUTO')
for c in range(1, 5):
    w(f':CHAN{c}:DISP ON'); w(f':CHAN{c}:INP DC50'); w(f':CHAN{c}:SCAL {a.vdiv}'); w(f':CHAN{c}:OFFS 0')
w(':WAV:FORM WORD'); w(':WAV:BYT LSBF'); w(':WAV:STR OFF'); q('*OPC?')
print('scope:', q(':ACQ:POIN?'), 'pts,', [q(f':CHAN{c}:DISP?') + '/' + q(f':CHAN{c}:SCAL?') for c in range(1, 5)], q(':SYST:ERR?'))

def grab():
    w(':DIG CHAN1,CHAN2,CHAN3,CHAN4'); q('*OPC?')
    out = []
    for c in range(1, 5):
        w(f':WAV:SOUR CHAN{c}')
        yinc, yor, xinc = float(q(':WAV:YINC?')), float(q(':WAV:YOR?')), float(q(':WAV:XINC?'))
        d = np.array(s.query_binary_values(':WAV:DATA?', datatype='h', container=np.array), float)
        out.append(d * yinc + yor)
    return np.array(out), 1 / xinc

def bb(x, fs):
    n = np.arange(x.shape[1]); z = x * np.exp(-2j * np.pi * a.fc / fs * n)
    Z = fft(z, axis=1); f = np.fft.fftfreq(x.shape[1], 1 / fs)
    Z[:, np.abs(f) > a.bw] = 0
    return ifft(Z, axis=1), Z, f

rows = []
for k in range(a.n):
    x, fs = grab()
    z, Z, f = bb(x, fs)
    ref = z[0]; pw = np.mean(np.abs(z) ** 2, axis=1)
    band = np.abs(f) <= a.bw
    r = []
    for c in range(4):
        ph = np.angle(np.vdot(ref, z[c]))                           # phase of ch_c relative to ch1 @ fc
        # group delay from the slope of the cross-spectrum phase across the band
        # (averaged in 32 sub-bands over the occupied OFDM band, DC excluded, then unwrapped)
        occ = (np.abs(f) < 8e6) & (np.abs(f) > 0.3e6)
        X = Z[c, occ] * np.conj(Z[0, occ]); fb = f[occ]; o = np.argsort(fb); X, fb = X[o], fb[o]
        sb = np.array_split(np.arange(len(fb)), 32)
        Xs = np.array([X[i].sum() for i in sb]); fs_ = np.array([fb[i].mean() for i in sb])
        slope = np.polyfit(fs_, np.unwrap(np.angle(Xs)), 1)[0]
        tau = -slope / (2 * np.pi)
        g = 10 * np.log10(pw[c] / pw[0])
        r.append((np.degrees(ph), tau * 1e12, g, 10 * np.log10(pw[c] / 50 * 1e3)))
    rows.append(r)
    print(f'#{k+1:2d} ' + ' | '.join(f'ch{c+1}: {r[c][0]:+7.1f} deg {r[c][1]:+7.0f} ps {r[c][2]:+5.2f} dB' for c in range(1, 4)))
    time.sleep(0.3)

R = np.array(rows)              # [n, ch, (phase, delay, gain, pwr)]
print('\nrelative to CH1 (mean +- std over %d captures, fs=%.0f GSa/s, %d samples)' % (a.n, fs / 1e9, x.shape[1]))
for c in range(4):
    ph = R[:, c, 0]; m = np.degrees(np.angle(np.mean(np.exp(1j * np.radians(ph)))))
    sd = np.degrees(np.sqrt(-2 * np.log(np.abs(np.mean(np.exp(1j * np.radians(ph - m)))) + 1e-300)))
    print(f'CH{c+1}: phase {m:+7.1f} +- {sd:4.1f} deg | delay {R[:,c,1].mean():+7.0f} +- {R[:,c,1].std():4.0f} ps | '
          f'gain {R[:,c,2].mean():+5.2f} dB | power {R[:,c,3].mean():6.1f} dBm')
if a.csv:
    np.savetxt(a.csv, R.reshape(a.n, -1), delimiter=',', fmt='%.4f',
               header=','.join(f'ch{c+1}_{k}' for c in range(4) for k in ('phase_deg', 'delay_ps', 'gain_dB', 'pwr_dBm')))
w(':RUN')
s.close()
if vsa is not None:                                   # give the scope back to VSA
    vsa.write(f':SYST:VSA:HARD:CONF:SEL:ANAL "{a.vsa_analyzer}"'); vsa.query('*OPC?')
    vsa.write(':INIT:CONT 1')
    while not vsa.query('SYST:ERR?').startswith('+0'): pass
