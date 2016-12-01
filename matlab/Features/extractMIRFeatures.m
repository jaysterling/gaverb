function verb = extractMIRFeatures(filename_or_x,mindB,fs)

frameSizeMS = 30; % minimum frame length, in ms
% overlap = 0.5; %fraction of frame overlapping

% calculate STFT frames
minFrameLen = fs*frameSizeMS/1000; 
frameLenPow = nextpow2(minFrameLen);
frameLen = 2^frameLenPow; % frame length = fft size
% frameLen_sec = frameLen/fs;
% stride = (1-overlap)*frameLen;

verb = struct('fs',fs);

% read in the file, compute envelope, trim to mindB on both ends
if ischar(filename_or_x)
    aRaw = miraudio(filename_or_x,'Mono','Sampling',fs,'Channel',1);
    verb.filename = filename_or_x;
    verb.name = filename_or_x;
else
    aRaw = miraudio(filename_or_x,fs,'Label','GAOutput');
    verb.filename = 'GAOutput';
    verb.name = 'GAOutput';
end
e = mirenvelope(aRaw,'Normal','PostDecim',1);
envdB = 20*log10(mirgetdata(e));
sInd =1; %find(envdB > mindB,1);
eInd = find(envdB > mindB,1,'last');

a = miraudio(aRaw,'Extract',sInd,eInd,'sp');
f = mirframe(a,'Length',frameLen,'sp');
e = mirenvelope(a,'Normal','PostDecim',1,'Tau',0.007);
c = mircepstrum(f);
verb.MFCC = mirgetdata(c);
% fb = mirfilterbank(a,'Bark')
% verb.fb = mirgetdata(fb);
% verb.fb = verb.fb(:,1,:);
% verb.fbPow = verb.fb.^2;
% verb.fbFreqs = getmirfield(fb,'Frequency');
verb.env = mirgetdata(e);
verb.envdB = 20*log10(verb.env);
times = getmirfield(f,'FramePos');
verb.FrameTimes = times(1,:)';

stftObj = mirspectrum(f,'Power');
verb.STFT = getmirfield(stftObj,'Data');
verb.LinFreqs = getmirfield(stftObj,'Frequency');
verb.LinFreqs = verb.LinFreqs(:,1);
verb.STFTdB = 10*log10(verb.STFT/max(max(verb.STFT)));

stftBarkObj = mirspectrum(f,'Bark','Power');
verb.STFTBark = getmirfield(stftBarkObj,'Data')';
verb.BarkFreqs = [50, 150, 250, 350, 450, 570, 700, 840, 1000, 1170, 1370, 1600, 1850, 2150, 2500, 2900, 3400, 4000, 4800, 5800, 7000, 8500, 10500, 13500]';

verb.EDR = edrFromPowSpec(verb.STFT);
verb.EDRdB = 10*log10(verb.EDR);
verb.EDRBark = edrFromPowSpec(verb.STFTBark);
verb.EDRBarkdB = 10*log10(verb.EDRBark);
verb.RT60Bark = rtcurveFromEDRdB(verb.EDRBarkdB,verb.FrameTimes,-60);
verb.RT60Lin = rtcurveFromEDRdB(verb.EDRdB,verb.FrameTimes,-60);

verb.IR = mirgetdata(a);
verb.IRTime = getmirfield(a,'Time');
verb.EnvTime = getmirfield(e,'Time');
verb.EDT = rt(verb.IR,fs,-10);
verb.RT60 = rt(verb.IR,fs,-60);
verb.RT20 = rt(verb.IR,fs,-20);
verb.RT30 = rt(verb.IR,fs,-30);
verb.C50 = clarity(verb.IR,fs,50);
verb.C80 = clarity(verb.IR,fs,80);
verb.D50 = definition(verb.IR,fs,50);
verb.EDC = edc(verb.IR);
verb.EDC = verb.EDC/max(verb.EDC);
verb.EDCdB = edc_db(verb.IR,mindB);
verb.TS = centerTime(verb.IR,fs);
verb.Centroid = centroid(verb.STFT,verb.LinFreqs);
verb.InitCentroid = verb.Centroid(1);

% BandsPerOctave = 3;
% N = 8;           % Filter Order
% F0 = 1000;       % Center Frequency (Hz)
% f = fdesign.octave(BandsPerOctave,'Class 1','N,F0',N,F0,fs);
% f.FilterOrder = 6;
% F0 = validfrequencies(f);
% Nfc = length(F0);
% for i=1:Nfc,
%     f.F0 = F0(i);
%     Hd3(i) = design(f,'butter');
% end
% y = zeros(Nfc,length(verb.IR));
% for i=1:Nfc
%     y(i,:) = filter(Hd3(i),verb.IR)';
% %     max(max(abs(y(i,:))))
% %     min(min(abs(y(i,:))))
% end
% 
% verb.fb = y(1:end-1,:);
% verb.fbPow = verb.fb.^2;
% surf(20*log10(abs(verb.fb)));
% shading interp; axis tight;
% view(0,90)
% verb.fbFreqs = F0(1:end-1)';


% y = y/max(max(abs(y)));
% surf(20*log10(abs(y)))
% view(0,90)
% shading interp
% axis tight
% hfvt = fvtool(Hd3,'FrequencyScale','log','color','white');
% axis([0.01 24 -90 5])
% title('1/3-Octave-Band Filter Bank')