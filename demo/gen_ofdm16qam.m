% Generate an IEEE 802.11a OFDM 16-QAM frame (MCS 4, 20 MHz) for the MXG.
% Output: demo/ofdm16qam_80M.bin  (int16 big-endian interleaved IQ, N5182B ARB format)
cfg = wlanNonHTConfig('ChannelBandwidth','CBW20','MCS',4,'PSDULength',1500);   % MCS4 = 16-QAM, R=1/2 (24 Mb/s)
rng(1); psdu = randi([0 1], cfg.PSDULength*8, 1);
osr = 4;                                                     % 20 MHz * 4 = 80 MSa/s
x = wlanWaveformGenerator(psdu, cfg, 'NumPackets',1, 'IdleTime',20e-6, 'OversamplingFactor',osr);
fs = wlanSampleRate(cfg)*osr;
x = x(:) / max(abs([real(x); imag(x)])) * 0.7;               % 70% of DAC full scale (MXG headroom)
n = numel(x); n = n - mod(n,2);  x = x(1:n);
iq = zeros(2*n,1,'int16'); iq(1:2:end) = int16(round(real(x)*32767)); iq(2:2:end) = int16(round(imag(x)*32767));
here = fileparts(mfilename('fullpath'));
fid = fopen(fullfile(here,'ofdm16qam_80M.bin'),'w','ieee-be'); fwrite(fid, iq, 'int16'); fclose(fid);
fprintf('fs=%.0f  samples=%d  dur=%.1f us  PAPR=%.1f dB\n', fs, n, n/fs*1e6, 10*log10(max(abs(x).^2)/mean(abs(x).^2)));
