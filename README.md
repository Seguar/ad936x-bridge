# AD936x bridge (FMCOMMS5 RF repeater) — EVM test bench

An AD-FMCOMMS5 (2× AD9361, 4 RX / 4 TX) acts as an RF **bridge**: whatever comes into the RX
ports goes straight back out of the TX ports. The test bench measures how much EVM the bridge
adds, first on a **ZC706** carrier and then on a **ZCU102**.

## Test setup

```
 N5182B MXG ──► 1:4 splitter ──► RX1A_A, RX2A_A, RX1A_B, RX2A_B   (FMCOMMS5 on ZC706 / ZCU102)
  (OFDM 16-QAM, 2 GHz,                                   │  FPGA RX→TX loopback
   from Keysight IQtools)                                ▼
                         DSOS604A ch1..4 ◄── TX1A_A, TX2A_A, TX1A_B, TX2A_B
                              │
                              └─► 89600 VSA (Custom OFDM demod → EVM)
```

* **Bridge mode**: the AD9361 driver's `loopback = 2` debug attribute (shown as "RF Rx -> RF Tx" in
  MATLAB `BISTLoopbackMode`) routes the ADC samples back to the DAC inside the FPGA
  (`axi_ad9361`), per chip.
* The bitstream is an HDL Coder SoC build (`mwipcore`, `mwbypassrx/tx` IP), see `AD/soc_builder.m`.

## Contents

| Path | What |
|---|---|
| `AD/fmcomms5_all_control.m` | Every `sdrtx`/`sdrrx` FMCOMMS5 property, documented, incl. bridge (BIST loopback) mode |
| `AD/soc_builder.m` | Minimal 4×TX / 4×RX configuration that switches the board into RF RX → RF TX loopback |
| `AD/test.m` | Basic ZC706 + FMCOMMS5 check with ADI Transceiver Toolbox: 4-channel RX capture + TX tone |
| `AD/TransceiverToolbox` | Submodule: [analogdevicesinc/TransceiverToolbox](https://github.com/analogdevicesinc/TransceiverToolbox) |
| `demo/gen_ofdm16qam.m`, `demo/setup_mxg.py`, `demo/bridge_on.m`, `demo/vsa_wlan_evm.py`, `demo/phase_check.py` | EVM demo chain (see below) |
| `demo/iio_net.py` | Dependency-free libiio **network** client (iiod text protocol, port 30431): read and write AD9361 attributes, debug attributes and registers from Windows with no libiio installed |

Clone with `git clone --recursive`.

## Demo: EVM through the bridge (ZC706)

```
# 1. waveform: IEEE 802.11a OFDM, 16-QAM R=1/2 (MCS 4, 24 Mb/s), 80 MSa/s -> demo/ofdm16qam_80M.bin
matlab -batch "cd demo; gen_ofdm16qam"
# 2. MXG: download + play at 2 GHz, -40 dBm
set MXG_ADDR=TCPIP0::<MXG_IP>::inst0::INSTR
py demo/setup_mxg.py --freq 2e9 --pow -40
# 3. board: bridge on via SoC Builder support package (keeps MATLAB open so the bridge stays on)
matlab -batch "cd demo; bridge_on"          # env BOARD_IP, BRIDGE_FC, BRIDGE_RXG, BRIDGE_TXG
# 4. VSA (scope selected as analyzer, SCPI enabled): 802.11a demod, EVM per scope channel
py demo/vsa_wlan_evm.py --fc 2e9 --ch 1 2 3 4 --n 10 --leave 1
# 5. optional: inter-channel phase / delay / gain, measured directly on the scope (VSA hands the scope over automatically)
py demo/phase_check.py --scope TCPIP0::<SCOPE_IP>::hislip0::INSTR --n 10
```

Results, 2026-11-12: ZC706 + FMCOMMS5 at 2 GHz. MXG at -40 dBm through a 1:4 splitter (about -47 dBm per input), TX attenuation -10 dB.

| Scope | Output (input) | EVM, RX gain 31 dB | EVM, RX gain 36 dB (final) |
|---|---|---|---|
| CH1 | TX2A_B (RX2A_B) | 2.96 % | 1.97 % (-34.1 dB) |
| CH2 | TX1A_B (RX1A_B) | 2.57 % | 2.03 % (-33.8 dB) |
| CH3 | TX2A_A (RX2A_A) | 2.87 % | 1.96 % (-34.1 dB) |
| CH4 | TX1A_A (RX1A_A) | 2.66 % | 2.06 % (-33.7 dB) |

* With the MXG 10 MHz output driving the scope 10 MHz input (VSA reference External), the frequency error is below 2 Hz (it was 37 Hz before) and EVM is unchanged.
* Reference with the MXG wired straight to the scope at the same scope level: 0.69 % (-43.2 dB), so the bridge adds about 1.9 % EVM.
* RX gain sweep: 36 dB is the best setting. Below it, the TX LO leakage dominates; above about 43 dB, the TX path compresses.
* Phase (`demo/phase_check.py`): the offset between the two paths of one chip is fixed (about -10 deg on chip B, about +14 deg on chip A).
  The offset between chip A and chip B jumps in 90 deg steps on every LO retune, so it needs calibration after each tune.
  RX1->TX1 runs one sample (32.7 ns) ahead of RX2->TX2 on both chips.

`demo/setup_board.py` sets the same LO and `loopback=2` directly over iiod. With RX AGC on, however,
it produced a large, signal-independent carrier, so use `bridge_on.m` (the MATLAB path) for measurements.

## Notes from bring-up

* After boot both AD9361s come up at 2.4 GHz with `loopback = 0` and the DAC source set to DDS
  at scale 0, so **TX is silent until bridge mode is switched on again** (run `soc_builder.m`, or
  write `loopback = 2` through `demo/iio_net.py`).
* DSOS604A firmware 06.74: if the HiSLIP server hangs (`VI_ERROR_IO` when the session opens, even
  though the raw HiSLIP handshake works), VXI-11 `inst0` still answers. VSA, however, only
  accepts addresses that its discovery has found.
* VSA can be scripted over SCPI at `TCPIP0::localhost::hislip_vsa0::INSTR`.

## Status

The ZC706 measurements are done (EVM, reference, gain sweep, phase). Next: the same test on ZCU102.
