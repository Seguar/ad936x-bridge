"""Run shell commands on the ZCU102 over its serial console (CP2108 interface 0, PS UART0).

usage: py zcu_console.py "uname -a" "ip -br addr" ...   (each command's output is printed)
       --port COM5 --wait 4   (seconds to wait for output of each command)
"""
import argparse, re, serial, time

p = argparse.ArgumentParser()
p.add_argument('cmds', nargs='+'); p.add_argument('--port', default='COM5'); p.add_argument('--wait', type=float, default=4)
a = p.parse_args()
s = serial.Serial(a.port, 115200, timeout=0.2)
ansi = re.compile(rb'\x1b\[[0-9;?]*[A-Za-z]')


def run(cmd):
    s.reset_input_buffer()
    mark = f'__END{int(time.time()*1000) % 100000}__'
    s.write((cmd + f'; echo {mark}\n').encode())
    buf, t = b'', time.time()
    while time.time() - t < a.wait:
        buf += s.read(65536)
        if (mark + '\r').encode() in buf or (mark + '\n').encode() in buf: break
    txt = ansi.sub(b'', buf).decode(errors='replace').replace('\r', '')
    lines = [l for l in txt.split('\n') if mark not in l and not l.startswith('root@')]
    return '\n'.join(lines).strip()


s.write(b'\n'); time.sleep(0.5); s.read(65536)
for c in a.cmds:
    print(f'$ {c}'); print(run(c)); print()
s.close()
