
% our fitness function, where x is a row vector with the GA's output, we
% pass back a 0-1 fitVal, where 0 means identical, target is PCM data for
% the target reverb we are approximating

function fitVal = rirFit(vars)
global st

if strcmp(st.toneCorrectionMethod,'emp')
    st.empFirstPass = true;
    [st.empFirstPassIR,st.empParams] = doFDNReverbWithGAOutput(vars);

    st.empFirstPass = false;
    [reverbOut, st.currGAParams] = doFDNReverbWithGAOutput(vars);
else
    [reverbOut, st.currGAParams] = doFDNReverbWithGAOutput(vars);
end
st.currGAFeats = extractMIRFeatures(reverbOut,st.minComparedB,st.fs);
% len = 4096*2;% min(st.currGAParams.m);
% dif = abs(reverbOut(1:len) - st.tarFeats.IR(1:len));
% plot(dif);

% plot(st.currGAFeats.env)
% hold on;
% plot(st.tarFeats.env,'r')

fitVal = getFitnessValue(reverbOut,st.tarFeats.IR,st.fs);

if length(st.fit) < 1 || fitVal < min(st.fit) 
    st.currBestGAFeats = st.currGAFeats;
    st.currBestGAParams = st.currGAParams;
    if ~st.makePlots
        plotIRComparison(st.tarFeats,st.currBestGAFeats,st);
        drawnow;
    end
end

st.fit = [st.fit fitVal];
if isempty(st.fitMin)
    st.fitMin = fitVal;
else
    st.fitMin = [st.fitMin min(min(st.fitMin),fitVal)];
end

if st.makePlots
    dirname = sprintf('%s/ProgressPNGs',st.dirName);
    if ~exist(dirname,'dir')
        mkdir(dirname);
        figure('Position', [0, 0, 1200, 801]);
    end
%     plotIRComparison(st.tarFeats,st.currBestGAFeats,st);
%     drawnow;
    if ~strcmp(st.fitMethod,'ls') && ~strcmp(st.fitMethod,'mfcc')
        nRows = 3;
    else
        nRows = 2;
    end
    figure(st.progFig);
    clf(st.progFig);
    set(st.progFig,'visible','off')
    nSamps = round(st.fs*st.tarFeats.RT60);
    
    subplot(nRows,2,1);
    plot(st.tarFeats.IRTime(1:nSamps),st.tarFeats.IR(1:nSamps));
    xlim([0 st.tarFeats.RT60]); box on;
    xlabel('Time (s)'); ylabel('Amplitude'); title('Target IR');
    
    subplot(nRows,2,3)
    nSampsSynth = min(nSamps,length(st.currBestGAFeats.IRTime));
    plot(st.currBestGAFeats.IRTime(1:nSampsSynth),st.currBestGAFeats.IR(1:nSampsSynth));
    xlim([0 st.tarFeats.RT60]); box on;
    xlabel('Time (s)'); ylabel('Amplitude'); title('GA Best IR');
    
    subplot(nRows,2,2)
    nSampsSynthCurr = min(nSamps,length(st.currGAFeats.IRTime));
    plot(st.currGAFeats.IRTime(1:nSampsSynthCurr),st.currGAFeats.IR(1:nSampsSynthCurr));
    xlim([0 st.tarFeats.RT60]); box on;
    xlabel('Time (s)'); ylabel('Amplitude'); title('GA Current IR');
    
    subplot(nRows,2,4)
    plot(st.fitMin)
    xlim([0 length(st.fitMin)]); box on;
    title('Best Fitness');xlabel('Individual'); ylabel('Fitness');
    
    if nRows == 3
        subplot(nRows,2,5:6)
        if strcmp(st.fitMethod,'env')
            hold off;
            plot(st.tarFeats.EnvTime, st.tarFeats.env);
            hold on;
            plot(st.currBestGAFeats.EnvTime, st.currBestGAFeats.env,'r');
            axis tight; 
            xlim([0 st.tarFeats.RT60]);
            legend('Target','Synthetic'); grid on;
            xlabel('Time (s)'); ylabel('Magnitude'); title('Signal Envelopes')
        elseif strcmp(st.fitMethod,'edc')
            hold off;
            plot(st.tarFeats.IRTime, st.tarFeats.EDC);
            hold on;
            plot(st.currBestGAFeats.IRTime, st.currBestGAFeats.EDC,'r');
            axis tight; 
            xlim([0 st.tarFeats.RT60]);
            legend('Target','Synthetic'); grid on;
            xlabel('Time (s)'); ylabel('Magnitude'); title('Energy Decay Curves')
        elseif strcmp(st.fitMethod,'edr')
            ind = find(st.tarFeats.RT60 < st.tarFeats.FrameTimes,1);
%             len = min(min(size(st.tarFeats.EDR,2),size(st.currBestGAFeats.EDR,2)),ind);
%             dif = abs(st.tarFeats.EDR(:,1:len) - st.currBestGAFeats.EDR(:,1:len));
                        
            len = min(size(st.currBestGAFeats.EDR,2),size(st.tarFeats.EDR,2));
            len = min(len,ind);
            normTstEDR = diag(1./max(st.currBestGAFeats.EDR,[],2))*st.currBestGAFeats.EDR(:,1:len);
            normTarEDR = diag(1./max(st.tarFeats.EDR,[],2))*st.tarFeats.EDR(:,1:len);
            dif = abs(normTstEDR - normTarEDR);
            
            surf(st.currBestGAFeats.FrameTimes(1:len),st.currBestGAFeats.LinFreqs, dif);
            set(gca,'YScale','log')
            view(0,90); axis tight; shading interp;
            xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('Energy Decay Relief Difference')
            caxis([0 1])

        end
    end
    
    saveSameSize(gcf,'format','png','file', sprintf('%s/%04d.png',dirname, length(st.fit)));
% saveas(gcf,sprintf('%s/%04d.png',dirname, length(st.fit)));
% export_fig(sprintf('%s/%04d.png',dirname, length(st.fit)),'-transparent');
end


