#!/bin/sh
# Configure both AD9361 of the AD-FMCOMMS5 as an RF bridge (RX -> FPGA loopback -> TX).
# Settings: /etc/fmcomms5-bridge.conf. Log: journalctl -u fmcomms5-bridge
CONF=/etc/fmcomms5-bridge.conf
LO_HZ=2000000000; RX_GAIN_DB=8; TX_ATT_DB=-20; LOOPBACK=2
[ -f "$CONF" ] && . "$CONF"

# wait for both AD9361 drivers
for i in $(seq 1 90); do
    A=$(grep -lx 'ad9361-phy' /sys/bus/iio/devices/*/name 2>/dev/null)
    B=$(grep -lx 'ad9361-phy-B' /sys/bus/iio/devices/*/name 2>/dev/null)
    [ -n "$A" ] && [ -n "$B" ] && break
    sleep 1
done
if [ -z "$A" ] || [ -z "$B" ]; then echo "fmcomms5-bridge: AD9361 not found (FMCOMMS5 fitted?)"; exit 1; fi
mount | grep -q ' /sys/kernel/debug ' || mount -t debugfs none /sys/kernel/debug

for f in $A $B; do
    d=$(dirname "$f"); dev=$(basename "$d")
    echo "$LO_HZ" > "$d/out_altvoltage0_RX_LO_frequency"
    echo "$LO_HZ" > "$d/out_altvoltage1_TX_LO_frequency"
    for c in 0 1; do
        echo manual        > "$d/in_voltage${c}_gain_control_mode"
        echo "$RX_GAIN_DB" > "$d/in_voltage${c}_hardwaregain"
        echo "$TX_ATT_DB"  > "$d/out_voltage${c}_hardwaregain"
    done
    echo "$LOOPBACK" > "/sys/kernel/debug/iio/$dev/loopback"
done
# re-apply the sample rate: re-initialises the digital interface (avoids a constant offset in the loopback path)
for f in $A $B; do d=$(dirname "$f"); fs=$(cat "$d/in_voltage_sampling_frequency"); echo "$fs" > "$d/in_voltage_sampling_frequency"; done

for f in $A $B; do
    d=$(dirname "$f"); dev=$(basename "$d")
    echo "fmcomms5-bridge: $(cat $f) LO $(cat $d/out_altvoltage0_RX_LO_frequency)/$(cat $d/out_altvoltage1_TX_LO_frequency) Hz," \
         "RX $(cat $d/in_voltage0_hardwaregain)/$(cat $d/in_voltage1_hardwaregain)," \
         "TX $(cat $d/out_voltage0_hardwaregain)/$(cat $d/out_voltage1_hardwaregain)," \
         "loopback $(cat /sys/kernel/debug/iio/$dev/loopback), Fs $(cat $d/in_voltage_sampling_frequency)"
done
