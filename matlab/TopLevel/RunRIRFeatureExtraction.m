
close all; 
filenames = dir('RIRs/ForFeatureExtraction/*.wav');

fs = 44100;

% postT60Count = 5;    % find these number of reverbs that minimize overall dist between the RT60s
% finalCount = 2;
% fieldsToMax = {'EDT','C50','D50','TS','InitCentroid'};   % fields to maximize the subset from above over
% mint60 = 0.2;       % min full bandwidth RT60 measure to be considered
% maxt60 = 11;

postT60Count = 40;    % find these number of reverbs that minimize overall dist between the RT60s
finalCount = 7;
fieldsToMax = {'EDT','C50','D50','TS','InitCentroid','RT20'};   % fields to maximize the subset from above over
mint60 = 1.0;       % min full bandwidth RT60 measure to be considered
maxt60 = 1.25;
useMIR = true;
mindB = -80;
stats = struct([]);

if boolean(useMIR)
    for i=1:length(filenames)
        [x,sr] = audioread(filenames(i).name);
        x = x(:,1);
%         audiowrite(sprintf('RIRs/ForFeatureExtraction/%s',filenames(i).name),x,fs);

        RT60 = rt(x,sr,-60);
        if RT60 >= mint60 && RT60 <= maxt60
            
            filenames(i).name
%             stats = [stats extractMIRFeatures(filenames(i).name,mindB,fs)];
            p = struct('name',filenames(i).name,'T60',RT60);
            stats = [stats p];
        end
    end
else
    for i=1:length(filenames)
        [x,sr] = audioread(filenames(i).name);
        if sr ~= fs
            x = resample(x,fs,sr);
        end
        
        sInd_Lin = 10^(sInd_dB/20);
        sInd = find(abs(x)>sInd_Lin,1);
        x = x(sInd:end);
        audiowrite(sprintf('RIRs/ForFeatureExtraction/%s',filenames(i).name),x,fs);

        RT60 = rt(x,fs,-60);
        if RT60 >= mint60 && RT60 <= maxt60
            stats = [stats extractFeatures(filenames(i).name)];
        end
    end
end

%% find the top choices

rtc = zeros(length(stats(1).RT60f),length(stats));
for i = 1:length(stats)
    rtc(:,i) = stats(i).RT60f;
end

% rtc = zeros(1,length(stats));
% for i = 1:length(stats)
%     rtc(i) = stats(i).RT60;
% end

% first, trim down the total number to get some number of IRs with similar
% RT60s
if postT60Count>0
    tight = tightestSubset(rtc, postT60Count,'min');
    rtTrimStats = stats(tight);
else
    rtTrimStats = stats;
    postT60Count = length(stats);
end

% Now, we go over every field we will maximize, normalize the field values
% into 0-1 (so that all fields get a normalized Euclidean weighting), then
% find the set that maximizes the dist between all
normVals = zeros(length(fieldsToMax),postT60Count);
for i = 1:length(fieldsToMax)
    unNormVals = zeros(1,postT60Count);
    for c = 1:postT60Count
        unNormVals(c) = rtTrimStats(c).(fieldsToMax{i});
    end
    % normalize all the vals into 0-1
    unNormVals = unNormVals - min(unNormVals);
    normVals(i,:) = unNormVals/max(unNormVals);
end

finalInds = tightestSubset(normVals, finalCount,'max');
finalStats = rtTrimStats(finalInds);

save('matlab/Features/similarityTestFields','finalStats','fieldsToMax');

%% Convolve all the selected IRs with the drums
system('rm Sounds/Outputs/*.wav');
[drums,fsd] = audioread('DryDrums.wav');
drums = drums(:,1);
if fsd ~= fs
    drums = resample(drums,fs,fsd);
end
for i = 1:length(finalInds)
    [x,sr] = audioread(finalStats(i).filename);
    x = x(:,1);
    if sr ~= fs
        x = resample(x,fs,sr);
    end
    y = conv(drums,x);
    y = 0.99*y/max(abs(y));
%     a = miraudio(y,fs);
%     a = miraudio(y,fs,'Normal');
%     dat = get(miraudio(y,fs,'Normal'),'Data');
%     rms = mirrms(miraudio(y,fs,'Normal'))
%     yn = dat{1}{1};
%     maxDif = max(abs(yn-y));
    audiowrite(sprintf('Sounds/Outputs/Drums_%s',finalStats(i).filename),y,fs);
end

%% Generate plots

scrsz = get(0,'ScreenSize');
system('rm RIRs/InfoPlots/*.png');
close all
figure('Position',[0, 0.05*scrsz(4), scrsz(3), 0.9*scrsz(4)])
h = gcf;
for i =1:length(finalInds)
    set(h,'alpha',1)
    s = finalStats(i);
    suptitle(sprintf('%s --- (RT60=%0.2f s, EDT=%0.2f s, C80=%0.1f dB, D50 %0.2f)', ...
        s.name, s.RT60, s.EDT, s.C80, s.D50));
    
    subplot(4,1,1)
    semilogx(s.EDRFreqs,s.RT60f);
    grid on; axis tight;
    title('RT60(\omega)');ylabel('Time (s)');xlabel('Frequency (Hz)');
    
    subplot(4,1,2)
    surf(s.EDRTime,s.EDRFreqs,s.EDR);
    set(gca,'YScale','log');
    cb = colorbar();
    cb.Label.String = 'Level (dB)';
    axis tight; shading interp; view(0,90);
    title('Energy Decay Relief');ylabel('Frequency (Hz)');xlabel('Time (s)');
    
    subplot(4,1,3)
    surf(s.EDRTime,s.EDRFreqs,s.STFT);
    set(gca,'YScale','log');
    axis tight; shading interp; view(0,90);
    cb = colorbar();
%     set(cb,'Label','Level (dB)');
    cb.Label.String = 'Level (dB)';
    title('Power Spectrum');ylabel('Frequency (Hz)');xlabel('Time (s)');
    
    subplot(4,1,4)
    surf(s.MFCC);
%     set(gca,'YScale','log');
    axis tight; shading interp; view(0,90);
    cb = colorbar();
%     set(cb,'Label','Level (dB)');
    cb.Label.String = 'Level (dB)';
    title('Mel Frequency Cepstral Coefficients');ylabel('Frequency (Hz)');xlabel('Time (s)');
    
    set(h,'Color',[1,1,1])
    pause(0.2)
    I = getframe(h);
    imwrite(I.cdata, sprintf('RIRs/InfoPlots/%s.png', s.name));

end
close(h)
