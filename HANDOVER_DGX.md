# Handover: laptop -> DGX (2026-11-12, 21:30 UTC)

The laptop session paused at a clean point. Everything is committed and pushed (`main`, last code commit `2d2a138`).
No project file changed after the 21:20 UTC sync. The DGX copy at `/home/sega/work/PhD/ad936x_bridge` is current.

## State

* **ZC706 + FMCOMMS5** (MATLAB SoC Builder firmware): measured and documented. The board is now off the bench.
* **ZCU102 + FMCOMMS5** (ADI Kuiper 2023_R2 on the 32 GB SD card): running as the bridge.
  * A boot-time service (`board/zcu102/`, installed on the card) sets 2 GHz, RX 8 dB, TX -20 dB and loopback 2 at every boot.
    These are the best settings for MXG -4 dBm and give 2.0-2.2 % EVM (-33.5 dB), checked after a reboot.
  * Network: dhcpcd falls back to 192.168.0.99/24 on the direct link (laptop "Ethernet 3", 192.168.0.2). Console: CP2108 interface 0 (COM5 on the laptop).
* **Bench as left:** MXG N5182B at 2 GHz / -4 dBm, playing `WFM1:OFDM16QAM` (volatile: lost on an MXG power cycle; re-download with `demo/setup_mxg.py`).
  The MXG 10 MHz output drives the scope 10 MHz input. VSA (89600, on the laptop) uses Analyzer3 = DSOS604A with Reference External, WLAN 802.11a on CH1.
* **Report:** `report/FMCOMMS5_bridge_EVM_report_v5.pdf` (12 pages). Generators: `report/make_report_v5.py`, with `patch_v5.py` and `figs_v5.py` for the
  v4 -> v5 additions. `report/` is git-ignored on purpose because it lists lab instrument addresses; it reached the DGX through the folder sync, not git.
* **Results in short:** relay floor about -40 dB EVM at -37 to -17 dBm per input (ZC706 -38.5 dB, ZCU102 -39.7 dB mean); MXG-to-scope reference -43.2 dB.
  At -11 dBm per input the AD9361 RX compresses (-33.5 dB). The inter-chip phase jumps in 90 deg steps on every LO retune; the phase inside a chip is fixed.

## Next steps

1. **Send the summary e-mail** (draft in the session) with the v5 PDF attached. No hardware needed.
2. Optional: a public copy of the report with instrument addresses replaced by placeholders. Can be done on the DGX.
3. **Input at -4 dBm:** test a 10 dB attenuator in front of the splitter with RX gain about 18 dB (expected about -40 dB EVM), then update
   `/etc/fmcomms5-bridge.conf` on the board. Needs hardware.
4. **TX->RX leakage hypothesis** (EVM follows the loop gain): VSA channel-response ripple vs loop gain; repeat with the outputs terminated or attenuated. Needs hardware.
5. **Phase:** lock the FMCOMMS5 to the 10 MHz reference; de-embed cables and splitter; inter-chip phase calibration and 1-sample path alignment in the HDL.
   The analysis can be done on the DGX; the measurements need hardware.
6. Root cause of the occasional signal-independent LO carrier in loopback (seen once on each board; cleared by reboot plus re-applying the sample rate). Needs hardware.

## Steps that need the laptop (or dsp) hardware

| Step | Why |
|---|---|
| Any EVM / phase / gain measurement (`demo/vsa_wlan_evm.py`, `phase_check.py`, `gain_sweep.py`, `range_sweep.py`) | 89600 VSA, Keysight VISA and the LAN to the MXG and scope run on the laptop |
| `demo/setup_mxg.py`, `demo/gen_ofdm16qam.m` (MATLAB WLAN Toolbox) | MATLAB and VISA on the laptop |
| `demo/bridge_on.m` (ZC706, MATLAB SoC Builder support package) | MATLAB on the laptop |
| `demo/setup_board.py`, `demo/iio_net.py` against the board | Board reachable on the laptop direct link 192.168.0.0/24 |
| `demo/zcu_console.py` | ZCU102 USB-UART (COM5) on the laptop |
| `tools/write_sd.ps1` | Admin PowerShell plus the USB SD-card reader on the laptop |

Code editing, report generation (`report/make_report_v5.py`; needs reportlab, matplotlib, pypdfium2 and the Arial/Consolas fonts, so fonts may need
swapping on Linux), data analysis (`data/*.csv`) and git work can all run on the DGX.

## Files changed since 21:20 UTC

* None apart from this file (`HANDOVER_DGX.md`), which is committed and pushed.
* On the board (not in this tree, nothing to sync): the boot service was installed before 21:20 UTC; its source is in `board/zcu102/`.
