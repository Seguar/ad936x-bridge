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
    def open_buffer(s, dev, nsamp, mask='00000003', cyclic=False):
        """Open an RX/TX buffer (enables the DMA path). mask = hex word of enabled scan elements."""
        return s._cmd(f'OPEN {dev} {nsamp} {mask}' + (' CYCLIC' if cyclic else ''))
    def read_buffer(s, dev, nbytes):
        """Read nbytes of raw samples from an open buffer (legacy iiod READBUF)."""
        s.s.sendall(f'READBUF {dev} {nbytes}\r\n'.encode()); data = b''
        while len(data) < nbytes:
            n = int(s.f.readline().strip())
            if n < 0: raise IOError(f'READBUF error {n}')
            if n == 0: break
            s.f.readline()                      # mask line
            data += s.f.read(n)
        return data
    def close_buffer(s, dev):
        return s._cmd(f'CLOSE {dev}')
    def phys(s):
        x = s.xml(); return re.findall(r'<device id="([^"]+)" name="ad9361-phy[^"]*"', x), x
