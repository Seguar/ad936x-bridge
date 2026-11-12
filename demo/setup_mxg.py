"""Download an IQ .bin (int16 BE interleaved) to the N5182B MXG and play it.
usage: py setup_mxg.py [--addr ...] [--freq 2e9] [--pow -40] [--file ofdm16qam_80M.bin] [--rate 80e6]"""
import argparse, os, pyvisa
p = argparse.ArgumentParser()
p.add_argument('--addr', default=os.environ.get('MXG_ADDR', 'TCPIP0::<MXG_IP>::inst0::INSTR'))
p.add_argument('--freq', type=float, default=2e9); p.add_argument('--pow', type=float, default=-40)
p.add_argument('--file', default=os.path.join(os.path.dirname(__file__), 'ofdm16qam_80M.bin'))
p.add_argument('--rate', type=float, default=80e6); p.add_argument('--name', default='OFDM16QAM')
a = p.parse_args()
g = pyvisa.ResourceManager().open_resource(a.addr); g.timeout = 60000
data = open(a.file, 'rb').read()
g.write(':OUTP OFF')
g.write_binary_values(f':MMEM:DATA "WFM1:{a.name}",', list(data), datatype='B')
g.write(f':RAD:ARB:WAV "WFM1:{a.name}"'); g.write(f':RAD:ARB:SCL:RATE {a.rate}')
g.write(':RAD:ARB ON'); g.write(':OUTP:MOD ON')
g.write(f':FREQ {a.freq}'); g.write(f':POW {a.pow}'); g.write(':OUTP ON')
g.query('*OPC?')
print(g.query(':RAD:ARB:WAV?').strip(), g.query(':FREQ?').strip(), g.query(':POW?').strip(),
      'ARB', g.query(':RAD:ARB?').strip(), 'RF', g.query(':OUTP?').strip(), 'err', g.query(':SYST:ERR?').strip())
