function plotIRComparison(feats1,feats2,opts)

global st;
figure(st.progFig)
clf
% plot(feats1.env)
% hold on
% plot(feats2.env,'r')

if nargin < 3 || isempty(opts)
    opts = struct('designFiltsFromMel',false);
    opts.fitMethod = 'env';
    opts.fitWithdB = false;
end

subplot(4,2,1)
if opts.designFiltsFromMel == true
    semilogx(feats1.BarkFreqs,feats1.RT60Bark);
    hold on
    semilogx(feats2.BarkFreqs,feats2.RT60Bark,'r');
else
    semilogx(feats1.LinFreqs,feats1.RT60Lin);
    hold on
    semilogx(feats2.LinFreqs,feats2.RT60Lin,'r');
end
axis tight; grid on;
legend('Tar','Test','location','SouthWest');
xlabel('Frequency - Hz'); ylabel('RT60 - seconds'); title('RT60 vs. Frequency')

subplot(4,2,2)

% t60 = rt(feats1.IR,feats1.fs,st.toneCorrMindB);
% clip = feats1.IR(st.earlyIRLen_samps:round(t60*feats1.fs));
% 
% for i=1:length(st.thirdOctFilts)
%     feat1AvgPwr(i) = mean(filter(st.thirdOctFilts(i),clip).^2);
% end
% 
% t602 = rt(feats2.IR,feats2.fs,st.toneCorrMindB);
% clip = feats2.IR(st.earlyIRLen_samps:round(t602*feats2.fs));
% for i=1:length(st.thirdOctFilts)
%     feat2AvgPwr(i) = mean(filter(st.thirdOctFilts(i),clip).^2);
% end
% 
% semilogx(st.thirdOctFreqs, 10*log10(feat1AvgPwr));
% hold on;
% semilogx(st.thirdOctFreqs, 10*log10(feat2AvgPwr),'r');
% axis tight; grid on;
% legend('Target','Test')
% xlabel('Frequency - Hz'); ylabel('Power - dB'); title('Average Spectral Shape')

t60 = rt(feats1.IR,feats1.fs,st.toneCorrMindB);
sInd = find(feats1.FrameTimes > st.earlyIRLen_samps/st.fs,1);
eInd = find(feats1.FrameTimes > t60,1)-1;

clip = feats1.STFT(:,sInd:eInd);
feat1AvgPwr = 10*log10(mean(clip.^2,2));

t602 = rt(feats2.IR,feats2.fs,st.toneCorrMindB);
sInd = find(feats2.FrameTimes > st.earlyIRLen_samps/st.fs,1);
eInd = find(feats2.FrameTimes > t602,1)-1;
clip = feats2.STFT(:,sInd:eInd);
feat2AvgPwr = 10*log10(mean(clip.^2,2));

semilogx(feats1.LinFreqs, feat1AvgPwr);
hold on;
semilogx(feats2.LinFreqs, feat2AvgPwr,'r');
axis tight; grid on;
legend('Target','Test','location','SouthWest')
xlabel('Frequency - Hz'); ylabel('Power - dB'); title('Average Spectral Shape')

% semilogx(feats1.LinFreqs,feats1.STFTdB(:,1));
% hold on
% semilogx(feats2.LinFreqs,feats2.STFTdB(:,1),'r');

% axis tight; grid on;
% legend('Tar','Test','location','SouthWest');
% xlabel('Frequency - Hz'); ylabel('Magnitude - dB'); title('Onset Spectrum')

subplot(4,2,3:4)
plot(feats1.IRTime,abs(feats1.IR),'b');
hold on; axis tight;
plot(feats1.EnvTime,(max(abs(feats1.IR))^2) *feats1.env,'k','LineWidth',1);
ylabel('IR Magnitude'); xlabel('Time (s)');
title(sprintf('%s IR Magnitude and Envelope',feats1.name));

plot(feats1.IRTime,abs(feats1.IR),'r');
hold on; axis tight;
plot(feats1.EnvTime,(max(abs(feats1.IR))^2) *feats1.env,'k','LineWidth',1);
ylabel('IR Magnitude'); xlabel('Time (s)');
title('IR Magnitude and Envelope');

subplot(4,2,5:6)
plot(feats2.IRTime,abs(feats2.IR),'b');
hold on; axis tight;
semilogy(feats2.EnvTime,(max(abs(feats2.IR))^2)*feats2.env,'k','LineWidth',1);
title(sprintf('%s',feats2.name));
ylabel('IR Magnitude'); xlabel('Time (s)');
title(sprintf('%s IR Magnitude and Envelope',feats1.name));

subplot(4,2,7:8)
hold on
if strcmp(opts.fitMethod,'env') || strcmp(opts.fitMethod,'ls')
    if opts.fitWithdB == true
        plot(feats1.EnvTime,feats1.envdB);
        plot(feats2.EnvTime,feats2.envdB,'r');
        axis tight; grid on;
        xlabel('Time - seconds'); ylabel('Magnitude - dB'); title('Impulse Response')
    else
        plot(feats1.EnvTime,feats1.env);
        plot(feats2.EnvTime,feats2.env,'r');
        axis tight; grid on;
        xlabel('Time - seconds'); ylabel('Magnitude'); title('Impulse Response')
    end
elseif strcmp(opts.fitMethod,'edc')
    if opts.fitWithdB == true
        plot(feats1.IRTime,10*log10(feats1.EDC));
        plot(feats2.IRTime,10*log10(feats2.EDC),'r');
        axis tight; grid on;
        xlabel('Time - seconds'); ylabel('Magnitude - dB'); title('Energy Decay Cureve (EDC)')
    else
        plot(feats1.IRTime(1:length(feats1.EDC)),feats1.EDC);
        plot(feats2.IRTime(1:length(feats2.EDC)),feats2.EDC,'r');
        axis tight; grid on;
        xlabel('Time - seconds'); ylabel('Magnitude'); title('Energy Decay Cureve (EDC)')
    end
elseif strcmp(opts.fitMethod,'edr')
    if opts.fitWithdB == true
        error('EDR dB not implemented');
    else
        minLen = min(size(feats1.EDR,2),size(feats2.EDR,2));
        logDif = 10*log10(abs(feats1.EDR(:,1:minLen) - feats2.EDR(:,1:minLen)));
        surf(feats1.FrameTimes(1:minLen),feats1.LinFreqs,logDif)
        view(0,90)
        set(gca,'YScale','log')
        colorbar
        axis tight; shading interp;
        xlabel('Time - seconds'); ylabel('Power - dB'); title('Energy Decay Relief Error')
    end
end

% figure
% plot(feats1.EnvTime,feats1.envdB);
% hold on
% plot(feats2.EnvTime,feats2.envdB,'r');
% axis tight; grid on;
% xlabel('Time - seconds'); ylabel('Magnitude - dB'); title('Impulse Response')