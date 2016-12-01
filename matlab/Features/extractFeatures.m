function Verb = extractFeatures(filename_or_x,fs,name)

mindB = -60;
if ischar(filename_or_x)
    [x,fs] = audioread(filename_or_x);
else
    x = filename_or_x;
end

x = x/(max(abs(x)));
env = audioEnv(x,0.01,.06);
envdB = 20*log10(env);
ltls = find(envdB > mindB,1);
ltl = find(envdB > mindB,1,'last');
if ~isempty(ltl)
    x = x(ltls:ltl);
    env = env(ltls:ltl);
    envdB = envdB(ltls:ltl);
end

cc = melfcc(x,fs,'wintime',0.03,'hoptime',0.015,'numcep',26,'minfreq',20, ...
            'maxfreq',20e3);

[e,F,T,frameLen,stride,logPow,linPow,linF] = edr(x,fs,1);
cent = centroid(linPow,linF);
[rt60f, rt60Freqs] = rtcurve(x,fs,-60,1);

Verb = struct('fs',fs,'IR',x, 'IRTime',linspace(0,length(x)/fs,length(x))', ...
    'EDT',rt(x,fs,-10), 'RT60',rt(x,fs,-60),...
    'RT20',rt(x,fs,-20),'RT30',rt(x,fs,-30), ...
    'C50',clarity(x,fs,50), ...
    'C80',clarity(x,fs,80), 'D50',definition(x,fs,50),'EDC',edc_db(x,-100),...
    'MFCC',cc,'STFT',logPow,'STFTFreqs',linF,'EDR',e,'EDRFreqs',F,'EDRTime',T,'EDRframeLen',frameLen,  ...
    'EDRstride',stride,'RT60f',rt60f,'RT60Freqs',rt60Freqs', 'TS',centerTime(x,fs),...
    'Centroid',cent,'InitCentroid',cent(1),'env',env,'envdB',envdB);

if ischar(filename_or_x)
    Verb.filename = filename_or_x;
    Verb.name = filename_or_x(1:end-4);
    if ~isempty(find(isnan(cc),1))
        warning('File "%s" MFCC matrix has NaNs',Verb.name);
    end
elseif nargin >= 3
    Verb.filename = name;
    Verb.name = name;
else
    Verb.filename = '';
    Verb.name = '';
end
    