%% ZC706 + AD-FMCOMMS5-EBZ basic test
clear;
clc;
close all;

URI = 'ip:<BOARD_IP>';   % e.g. ip:192.168.0.99

Fc = 2.4e9;      % RF center frequency: 2.4 GHz
Fs = 10e6;       % sample rate: 10 MSPS
BW = 10e6;       % analog RF bandwidth
N  = 65536;      % samples per capture


%% ============================================================
%  RX: RECEIVE FROM ALL 4 CHANNELS
% =============================================================

rx = adi.FMComms5.Rx('uri', URI);

% Common sampling rate
rx.SamplingRate = Fs;

% AD9361 A
rx.CenterFrequency = Fc;
rx.RFBandwidth = BW;

% AD9361 B
rx.CenterFrequencyChipB = Fc;
rx.RFBandwidthChipB = BW;

% All four receivers
rx.EnabledChannels = [1 2 3 4];

rx.SamplesPerFrame = N;


%% Manual gain

% AD9361 A
rx.GainControlModeChannel0 = 'manual';
rx.GainControlModeChannel1 = 'manual';

rx.GainChannel0 = 30;
rx.GainChannel1 = 30;

% AD9361 B
rx.GainControlModeChannel0ChipB = 'manual';
rx.GainControlModeChannel1ChipB = 'manual';

rx.GainChannel0ChipB = 30;
rx.GainChannel1ChipB = 30;


%% Capture one frame

valid = false;

while ~valid
    [data, valid] = rx();
end

fprintf("Received %d samples from %d channels\n", ...
    size(data,1), size(data,2));


%% ============================================================
%  TIME DOMAIN
% =============================================================

t = (0:N-1) / Fs;

figure;

for ch = 1:4
    subplot(4,1,ch);

    plot(t * 1e3, real(data(:,ch)));
    grid on;

    ylabel(sprintf('RX%d',ch));

    if ch == 1
        title('FMCOMMS5 received I samples');
    end
end

xlabel('Time [ms]');


%% ============================================================
%  FREQUENCY DOMAIN
% =============================================================

f = (-N/2:N/2-1) * Fs/N;

figure;

for ch = 1:4

    x = data(:,ch);

    X = fftshift(fft(x));
    P = 20*log10(abs(X) / max(abs(X)) + eps);

    subplot(4,1,ch);

    plot(f/1e6, P);
    grid on;
    ylim([-100 5]);

    ylabel(sprintf('RX%d [dB]',ch));

    if ch == 1
        title('FMCOMMS5 RX spectrum');
    end
end

xlabel('Baseband frequency [MHz]');


%% Release RX

release(rx);



%% ============================================================
%  TX: TRANSMIT A CONTINUOUS COMPLEX TONE
% =============================================================

tx = adi.FMComms5.Tx('uri', URI);

tx.SamplingRate = Fs;

% AD9361 A
tx.CenterFrequency = Fc;
tx.RFBandwidth = BW;

% AD9361 B
tx.CenterFrequencyChipB = Fc;
tx.RFBandwidthChipB = BW;


%% Use only TX channel 1 for first test

tx.EnabledChannels = 1;

% Host-generated IQ waveform
tx.DataSource = 'DMA';

% Repeat the buffer continuously
tx.EnableCyclicBuffers = true;

% Start with substantial attenuation
tx.AttenuationChannel0 = -30;


%% Generate +1 MHz complex baseband tone

fTone = 1e6;

Ntx = 16384;
n = (0:Ntx-1).';

amplitude = 0.25 * 2^15;

txData = amplitude * exp(1j * 2*pi*fTone/Fs * n);


%% Start TX

tx(txData);

fprintf('TX running\n');
fprintf('RF carrier: %.6f GHz\n', Fc/1e9);
fprintf('Baseband tone: %.3f MHz\n', fTone/1e6);
fprintf('Expected RF tone: %.6f GHz\n', (Fc + fTone)/1e9);


%% Let it transmit for 10 seconds

pause(10);


%% Stop TX

release(tx);

disp('TX stopped');