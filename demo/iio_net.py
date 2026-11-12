"""Minimal libiio network (iiod ASCII protocol) client - no libiio install needed."""
import socket, re, sys
class IIO:
    def __init__(s, host='192.168.0.99', port=30431):
        s.s = socket.create_connection((host, port), timeout=5); s.f = s.s.makefile('rb')
    def _cmd(s, c):
        s.s.sendall((c + '\r\n').encode()); return int(s.f.readline().strip())
    def xml(s):
        n = s._cmd('PRINT'); d = s.f.read(n); s.f.readline(); return d.decode()
    def read(s, dev, attr, chan=None, out=False, debug=False):
        kind = 'DEBUG ' if debug else ('' if chan is None else ('OUTPUT ' if out else 'INPUT ') + chan + ' ')
        n = s._cmd(f'READ {dev} {kind}{attr}')
        if n < 0: return f'ERR{n}'
        d = s.f.read(n); s.f.readline(); return d.decode().rstrip('\x00').strip()
    def write(s, dev, attr, val, chan=None, out=False, debug=False):
        kind = 'DEBUG ' if debug else ('' if chan is None else ('OUTPUT ' if out else 'INPUT ') + chan + ' ')
        v = str(val).encode()
        s.s.sendall(f'WRITE {dev} {kind}{attr} {len(v)}\r\n'.encode() + v)
        return int(s.f.readline().strip())
    def phys(s):
        x = s.xml(); return re.findall(r'<device id="([^"]+)" name="ad9361-phy[^"]*"', x), x
