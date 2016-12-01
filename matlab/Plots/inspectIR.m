function inspectIR(fileName_or_x,fs,name)

if ischar(fileName_or_x)
    [x,fs] = audioread(fileName_or_x);
elseif isvector(fileName_or_x)
    x = fileName_or_x;
end

%%

% close all;

% for now only inspecting first channel
x = x(:,1);

minPlotDB = -60; % minimum value in DB to be plotted
frameSizeMS = 30; % minimum frame length, in ms
overlap = 0.5; %fraction of frame overlapping

%% Regular plot

figure
T = linspace(0,length(x)/fs,length(x));
subplot(5,1,1)
plot(T,x)
if (ischar(fileName_or_x) && nargin >= 2 && ~isempty(name)) ...
        || (isvector(fileName_or_x) && nargin >=3 && ~isempty(name))
    title(sprintf('%s Impulse Response', name));
else
    title('Impulse Response'); 
end
xlabel('Time (s)'); ylabel('Magnitude')
axis tight

%% STFT params

% calculate STFT frames
minFrameLen = fs*frameSizeMS/1000; 
frameLenPow = nextpow2(minFrameLen);
frameLen = 2^frameLenPow; % frame length = fft size

[B,F,T] = spectrogram(x, hann(frameLen), overlap*frameLen, frameLen,fs);
B_db = TrimFillNorm(20*log10(abs(B)), minPlotDB);

subplot(5,1,2)
surf(T(1:size(B_db,2)),F/1e3,B_db);
set(gca,'YScale','log')
title('STFT'); xlabel('Time (s)');ylabel('Frequency (kHz)');zlabel('Magnitude (dB)');
zlim([minPlotDB 0]);
axis tight; zoom on; shading interp;
view(0,90);

%% EDR
[B_EDRdb,F,T,frameLen,stride] = edr(x,fs,0);
B_EDRdb = TrimFillNorm(B_EDRdb,minPlotDB);

subplot(5,1,3)
surf(T(:,1:size(B_EDRdb,2)),F(1:size(B_EDRdb,1))/1e3,B_EDRdb);
set(gca,'YScale','log')
title('Normalized Energy Decay Relief (EDR)');xlabel('Time (s)');ylabel('Frequency (kHz)');zlabel('Magnitude (dB)');
axis tight; zoom on; shading interp;
view(0,90);

%% EDC

EDC_db = edc_db(x);
T = linspace(0,length(x)/fs,length(x));
I = find(EDC_db < minPlotDB,1);
subplot(5,1,4)
plot(T(1:I),EDC_db(1:I));
title('EDC')
xlabel('Time (s)');ylabel('Energy (dB)')
axis tight; grid on;

%% Zero crossings

zc = zcPerFrame(x,fs,frameSizeMS);
subplot(5,1,5);
T = linspace(0,length(zc)*frameSizeMS/1000,length(zc));
plot(T,zc);
title('Zero Crossings Per Frame');
xlabel('Time (s)'); ylabel('Crossings');
axis tight;



%% Hear it for reference

soundsc(x,fs);
% [sig,fs_sig] = audioread('flamenco.wav');
% if fs_sig ~= fs
%     sig = resample(sig,fs,fs_sig);
% end
% conv_out = conv(sig,x);
% soundsc(conv_out,fs);

