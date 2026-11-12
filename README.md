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
| `demo/iio_net.py` | Dependency-free libiio **network** client (iiod text protocol, port 30431): read and write AD9361 attributes, debug attributes and registers from Windows with no libiio installed |

Clone with `git clone --recursive`.

## Notes from bring-up

* After boot both AD9361s come up at 2.4 GHz with `loopback = 0` and the DAC source set to DDS
  at scale 0, so **TX is silent until bridge mode is switched on again** (run `soc_builder.m`, or
  write `loopback = 2` through `demo/iio_net.py`).
* DSOS604A firmware 06.74: if the HiSLIP server hangs (`VI_ERROR_IO` when the session opens, even
  though the raw HiSLIP handshake works), VXI-11 `inst0` still answers. VSA, however, only
  accepts addresses that its discovery has found.
* VSA can be scripted over SCPI at `TCPIP0::localhost::hislip_vsa0::INSTR`.

## Status

Work in progress: scripted MXG waveform download, board setup at 2 GHz, and VSA Custom OFDM setup with EVM readout.
