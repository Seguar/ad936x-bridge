clear;
clc;
close all;

%% ============================================================
%  GLOBAL SETTINGS
% ============================================================

IP = '192.168.0.99';

Fc = 2.1e9;          % RF center frequency [Hz]
Fs = 61.44e6;        % Baseband sample rate [Hz]

% FMCOMMS5 channel mapping:
%   1 = AD9361 A, RX1A_A / TX1A_A
%   2 = AD9361 A, RX2A_A / TX2A_A
%   3 = AD9361 B, RX1A_B / TX1A_B
%   4 = AD9361 B, RX2A_B / TX2A_B

RX_channels = 1;
TX_channels = 1;

% For all channels:
% RX_channels = [1 2 3 4];
% TX_channels = [1 2 3 4];


%% ============================================================
%  TX CONFIGURATION
% ============================================================

tx = sdrtx('FMCOMMS5', ...
    'IPAddress', IP, ...
    'CenterFrequency', Fc, ...
    'BasebandSampleRate', Fs, ...
    'ChannelMapping', TX_channels, ...
    'Gain', -10, ...
    'ShowAdvancedProperties', true);


%% ---------------- TX MAIN SETTINGS ----------------

% TX attenuation/gain:
%
% Valid range:
%   -89.75 ... 0 dB
% Resolution:
%   0.25 dB
%
% One channel:
tx.Gain = -10;

% Two channels:
% tx.Gain = [-10 -15];

% Four independent channels:
% tx.Gain = [-10 -10 -15 -15];


%% ---------------- TX CENTER FREQUENCY ----------------
%
% CenterFrequency is tunable.
%
% tx.CenterFrequency = 2.1e9;
%
% Later, while object is active:
% tx.CenterFrequency = 2.2e9;


%% ---------------- TX CUSTOM FILTER ----------------

% Default AD9361 filter chain:
tx.UseCustomFilter = false;

% Enable previously designed custom filter:
% tx.UseCustomFilter = true;

% To design one:
% designCustomFilter(tx);


%% ---------------- TX ADVANCED ----------------

tx.ShowAdvancedProperties = true;


%% Bypass custom FPGA user logic
%
% Normally FALSE.
%
tx.BypassUserLogic = false;

% tx.BypassUserLogic = true;


%% ---------------- TX DATA SOURCE ----------------
%
% Input Port = samples supplied by MATLAB
% DDS        = FPGA DDS tone generator

tx.DataSourceSelect = 'Input Port';

% tx.DataSourceSelect = 'DDS';


%% ---------------- TX FPGA DDS ----------------
%
% Only active when:
% tx.DataSourceSelect = 'DDS';

% tx.DDSTone1Freq = 1e6;
% tx.DDSTone2Freq = 2e6;

% Independent values per channel:
% tx.DDSTone1Freq = [1e6 2e6 3e6 4e6];
% tx.DDSTone2Freq = [2e6 3e6 4e6 5e6];

% Scale: 0 ... 1
% tx.DDSTone1Scale = 0.5;
% tx.DDSTone2Scale = 0.25;

% Independent amplitude per channel:
% tx.DDSTone1Scale = [0.5 0.4 0.3 0.2];
% tx.DDSTone2Scale = [0.1 0.1 0.1 0.1];


%% ---------------- TX I/O TIMEOUT ----------------

tx.DataTimeout = Inf;

% Examples:
% tx.DataTimeout = 5;
% tx.DataTimeout = 0;      % non-blocking


%% ---------------- TX BIST LOOPBACK ----------------
%
% Options:
%   'Disabled'
%   'Digital Tx -> Digital Rx'
%   'RF Rx -> RF Tx'

% We're controlling loopback from RX below:
tx.BISTLoopbackMode = 'Disabled';

% tx.BISTLoopbackMode = 'Digital Tx -> Digital Rx';
% tx.BISTLoopbackMode = 'RF Rx -> RF Tx';


%% ---------------- TX BIST INJECTION ----------------
%
% Options:
%   'Disabled'
%   'Tone Inject Tx'
%   'Tone Inject Rx'

tx.BISTToneInject = 'Disabled';

% tx.BISTToneInject = 'Tone Inject Tx';
% tx.BISTToneInject = 'Tone Inject Rx';


%% ---------------- TX BIST GENERATOR ----------------
%
% Only relevant when BISTToneInject != Disabled

% tx.BISTSignalGen = 'PRBS';
% tx.BISTSignalGen = 'Tone';


%% BIST tone frequency
%
% Options:
%   'Fs/32'
%   'Fs/16'
%   'Fs*3/32'
%   'Fs/8'

% tx.BISTToneFreq = 'Fs/32';


%% BIST tone level
%
% Options:
%   '0'
%   '-6'
%   '-12'
%   '-18'

% tx.BISTToneLevel = '-18';


%% ============================================================
%  APPLY TX CONFIGURATION
% ============================================================

txInfo = info(tx);

disp('TX INFO:');
disp(txInfo);


%% ============================================================
%  RX CONFIGURATION
% ============================================================

rx = sdrrx('FMCOMMS5', ...
    'IPAddress', IP, ...
    'CenterFrequency', Fc, ...
    'BasebandSampleRate', Fs, ...
    'ChannelMapping', RX_channels, ...
    'GainSource', 'Manual', ...
    'Gain', 31, ...
    'OutputDataType', 'int16', ...
    'SamplesPerFrame', 4, ...
    'EnableBurstMode', false, ...
    'ShowAdvancedProperties', true);


%% ---------------- RX MAIN SETTINGS ----------------

%% RX gain mode
%
% Options:
%   'Manual'
%   'AGC Slow Attack'
%   'AGC Fast Attack'

rx.GainSource = 'Manual';

% rx.GainSource = 'AGC Slow Attack';
% rx.GainSource = 'AGC Fast Attack';


%% RX manual gain
%
% Used only with:
% rx.GainSource = 'Manual'

rx.Gain = 31;

% Two independent channels:
% rx.Gain = [31 25];

% Four independent channels:
% rx.Gain = [31 31 25 25];


%% ---------------- RX OUTPUT TYPE ----------------
%
% Options:
%   'int16'   raw ADC-like values
%   'single'  normalized ~[-1,+1]
%   'double'  normalized ~[-1,+1]

rx.OutputDataType = 'int16';

% rx.OutputDataType = 'single';
% rx.OutputDataType = 'double';


%% ---------------- RX FRAME SIZE ----------------

rx.SamplesPerFrame = 4;

% Better for actual Ethernet streaming:
% rx.SamplesPerFrame = 32768;

% Larger frames usually improve host streaming efficiency:
% rx.SamplesPerFrame = 65536;


%% ---------------- RX BURST MODE ----------------

rx.EnableBurstMode = false;

% rx.EnableBurstMode = true;
% rx.NumFramesInBurst = 100;


%% ---------------- RX CUSTOM FILTER ----------------

rx.UseCustomFilter = false;

% rx.UseCustomFilter = true;

% Design filter:
% designCustomFilter(rx);


%% ---------------- RX ADVANCED ----------------

rx.ShowAdvancedProperties = true;


%% Bypass custom FPGA user logic

rx.BypassUserLogic = false;

% rx.BypassUserLogic = true;


%% ---------------- RX CORRECTIONS ----------------

% IQ imbalance correction
rx.EnableQuadratureCorrection = true;

% Disable for characterization:
% rx.EnableQuadratureCorrection = false;


% RF DC correction
rx.EnableRFDCCorrection = true;

% rx.EnableRFDCCorrection = false;


% Baseband DC correction
rx.EnableBasebandDCCorrection = true;

% rx.EnableBasebandDCCorrection = false;


%% ---------------- RX I/O TIMEOUT ----------------

rx.DataTimeout = Inf;

% rx.DataTimeout = 5;
% rx.DataTimeout = 0;


%% ============================================================
%  RF RX -> RF TX LOOPBACK
% ============================================================
%
% Options:
%
%   'Disabled'
%
%   'Digital Tx -> Digital Rx'
%       digital internal loopback
%
%   'RF Rx -> RF Tx'
%       RX RF chain -> loopback -> TX RF chain

rx.BISTLoopbackMode = 'RF Rx -> RF Tx';

% rx.BISTLoopbackMode = 'Disabled';
% rx.BISTLoopbackMode = 'Digital Tx -> Digital Rx';


%% ---------------- RX BIST SIGNAL INJECTION ----------------

rx.BISTToneInject = 'Disabled';

% rx.BISTToneInject = 'Tone Inject Rx';
% rx.BISTToneInject = 'Tone Inject Tx';


%% BIST generator

% rx.BISTSignalGen = 'PRBS';
% rx.BISTSignalGen = 'Tone';


%% BIST tone frequency

% rx.BISTToneFreq = 'Fs/32';
% rx.BISTToneFreq = 'Fs/16';
% rx.BISTToneFreq = 'Fs*3/32';
% rx.BISTToneFreq = 'Fs/8';


%% BIST tone level

% rx.BISTToneLevel = '0';
% rx.BISTToneLevel = '-6';
% rx.BISTToneLevel = '-12';
% rx.BISTToneLevel = '-18';


%% ============================================================
%  APPLY RX CONFIGURATION
% ============================================================

[data, valid, overflow] = rx();

disp('RX:');
fprintf('Valid    = %d\n', valid);
fprintf('Overflow = %d\n', overflow);
fprintf('Samples  = %d x %d\n', size(data,1), size(data,2));


%% Read back actual settings

rxInfo = info(rx);

disp('RX INFO:');
disp(rxInfo);


%% ============================================================
%  OPTIONAL: NORMAL MATLAB RX STREAMING
% ============================================================

% Nframes = 100;
%
% for k = 1:Nframes
%
%     [data, valid, overflow] = rx();
%
%     if valid
%         % Process data here
%     end
%
%     if overflow
%         fprintf('RX overflow on frame %d\n', k);
%     end
%
% end


%% ============================================================
%  OPTIONAL: CONTIGUOUS CAPTURE
% ============================================================
%
% RX also supports capture() for contiguous RF captures.
%
% Example:
%
% capturedData = capture(rx, milliseconds(10));


%% ============================================================
%  OPTIONAL: MATLAB -> TX STREAMING
% ============================================================
%
% Disable RF loopback first if you want normal MATLAB TX:
%
% release(rx);
% rx.BISTLoopbackMode = 'Disabled';
%
%
% fTone = 1e6;
% N = 65536;
% n = (0:N-1).';
%
% waveform = 0.2 * exp(1j*2*pi*fTone/Fs*n);
%
% underflow = tx(waveform);
%
% fprintf('TX underflow = %d\n', underflow);


%% ============================================================
%  OPTIONAL: CYCLIC / REPEATED TX
% ============================================================
%
% Download one waveform and continuously repeat it:
%
% fTone = 1e6;
% N = 65536;
% n = (0:N-1).';
%
% waveform = 0.2 * exp(1j*2*pi*fTone/Fs*n);
%
% transmitRepeat(tx, waveform);
%
% Stop it with:
% release(tx);


%% ============================================================
%  OPTIONAL: FPGA DDS TRANSMISSION
% ============================================================
%
% release(tx);
%
% tx.DataSourceSelect = 'DDS';
% tx.DDSTone1Freq  = 1e6;
% tx.DDSTone1Scale = 0.25;
% tx.DDSTone2Freq  = 2e6;
% tx.DDSTone2Scale = 0;
%
% tx();


%% ============================================================
%  OPTIONAL: CHANGE LO WHILE RUNNING
% ============================================================
%
% CenterFrequency is tunable.
%
% rx.CenterFrequency = 2.2e9;
% tx.CenterFrequency = 2.2e9;
%
% rx.CenterFrequency = 2.4e9;
% tx.CenterFrequency = 2.4e9;


%% ============================================================
%  CLEANUP
% ============================================================

% Uncomment when finished:
%
% release(rx);
% release(tx);