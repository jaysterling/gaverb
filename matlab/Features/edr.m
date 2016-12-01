function [e,F,T,frameLen,stride,logP,linP,linF] = edr(x,fs,doAsMel)

if nargin<3
    doAsMel = 0;
end

minPlotDB = -100; % minimum value in DB to be plotted
frameSizeMS = 20; % minimum frame length, in ms
overlap = 0.5; %fraction of frame overlapping
windowType = 'hann'; % type of windowing used for each frame

% calculate STFT frames
minFrameLen = fs*frameSizeMS/1000; 
frameLenPow = nextpow2(minFrameLen);
frameLen = 2^frameLenPow; % frame length = fft size
frameLen_sec = frameLen/fs;
stride = (1-overlap)*frameLen;
eval(['frameWindow = ' windowType '(frameLen);']);
[B,F,T] = spectrogram(x, hann(frameLen), overlap*frameLen, frameLen,fs);
linF = F;

if doAsMel==1
    [pspectrum,~] = powspec(x, fs, frameLen_sec, overlap*frameLen_sec, 0);
    linP = pspectrum;
    melBands = 26;
    [B,F] = audspec(pspectrum, fs, melBands, 'mel');
    T = linspace(frameLen/(2*fs),(frameLen/2 + (size(B,2)-1)*stride)/fs,size(B,2));
else
    linP = B;
end

[nBins,nFrames] = size(B);

B_energy = B.*conj(B);
B_energy = B_energy/(max(max(B_energy)));
logP = 10*log10(B_energy);
B_EDR = zeros(nBins,nFrames);
for i=1:nBins
    B_EDR(i,:) = fliplr(cumsum(fliplr(B_energy(i,:))));
end
B_EDRdb = 10*log10(abs(B_EDR));

% normalize EDR to 0 dB and truncate the plot below a given dB threshold
offset = max(max(B_EDRdb));
B_EDRdbN = B_EDRdb-offset;

B_EDRdbN_trunc = B_EDRdbN;
for i=1:nFrames
  I = find(B_EDRdbN(:,i) < minPlotDB);
  if (I)
    B_EDRdbN_trunc(I,i) = minPlotDB;
  end
end

for i=1:nFrames
  I = find(logP(:,i) < minPlotDB);
  if (I)
    logP(I,i) = minPlotDB;
  end
end

% sInd = find(F>20,1);
% eInd = find(F>20e3,1);
if doAsMel==0
    e = B_EDRdbN_trunc; 
%     F = F(sInd:eInd);
%     e = B_EDRdbN_trunc(sInd:eInd,:);
else
   e = B_EDRdbN_trunc; 
   F = F(2:end-1);
end
e = TrimFillNorm(e,minPlotDB);
logP = TrimFillNorm(logP,-1000);
logP = logP(:,1:size(e,2));
T = T(1:size(e,2));