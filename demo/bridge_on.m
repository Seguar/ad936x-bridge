% Put FMCOMMS5 (both AD9361) into RF RX -> RF TX bridge via the SoC Builder support package.
% Keeps MATLAB alive (objects not released) so the bridge stays on. Ctrl+C / kill to stop.
IP = getenv('BOARD_IP'); if isempty(IP), IP = '192.168.0.99'; end
Fc = str2double(getenv('BRIDGE_FC'));  if isnan(Fc),  Fc = 2e9;    end
RXg = str2double(getenv('BRIDGE_RXG')); if isnan(RXg), RXg = 31;   end
TXg = str2double(getenv('BRIDGE_TXG')); if isnan(TXg), TXg = -10;  end
Fs = 30.72e6;
tx = sdrtx('FMCOMMS5','IPAddress',IP,'CenterFrequency',Fc,'BasebandSampleRate',Fs, ...
    'ChannelMapping',[1 2 3 4],'Gain',TXg,'ShowAdvancedProperties',true);
info(tx);
rx = sdrrx('FMCOMMS5','IPAddress',IP,'CenterFrequency',Fc,'BasebandSampleRate',Fs, ...
    'ChannelMapping',[1 2 3 4],'GainSource','Manual','Gain',RXg,'SamplesPerFrame',4, ...
    'ShowAdvancedProperties',true,'BISTLoopbackMode','RF Rx -> RF Tx');
[~, valid, ovf] = rx();                       % first call applies the configuration
fprintf('BRIDGE ON  Fc=%.3f GHz  RXgain=%g dB  TXgain=%g dB  valid=%d ovf=%d\n', Fc/1e9, RXg, TXg, valid, ovf);
while true, pause(5); end
