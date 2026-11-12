# ZCU102 boot-time bridge service

Runs on the ZCU102 (ADI Kuiper 2023_R2). At boot it puts both AD9361 of the AD-FMCOMMS5 into RF bridge mode.

| File | Install to |
|---|---|
| `fmcomms5-bridge.conf` | `/etc/fmcomms5-bridge.conf` (settings: LO, RX gain, TX attenuation, loopback) |
| `fmcomms5-bridge.sh` | `/usr/local/bin/fmcomms5-bridge.sh` (chmod 755) |
| `fmcomms5-bridge.service` | `/etc/systemd/system/` then `systemctl daemon-reload && systemctl enable fmcomms5-bridge` |

Default settings are 2 GHz, RX gain 8 dB (manual) and TX attenuation -20 dB. These are the best settings for an MXG output of -4 dBm
(about -11 dBm per RX input after the 1:4 splitter) and give 2.0-2.2 % EVM (-33.5 dB) on all four outputs.
To change them, edit the .conf and run `systemctl restart fmcomms5-bridge`. Log: `journalctl -u fmcomms5-bridge`.
Turn the bridge off with `LOOPBACK=0`, or for good with `systemctl disable fmcomms5-bridge`.
