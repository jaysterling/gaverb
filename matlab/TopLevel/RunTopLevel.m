close all; clearvars
clearvars -global st

% the almighty state referenced in serveral main algorithm files
global st;

st.fs = 44100;                          % operating sample rate
st.fileToMatch = 'SampleRIR.wav';       % file we're going to be approximating, if not batch below
st.runBatch = false;                    % overwrites the above by running the GA on the whole folder RIRs/ToMatch
st.minComparedB = -100;                 % minimum value we'll compute features to and compare to
st.N = 16;                              % size of the feedback matrix (N x N)
st.filtOrd = 6;                         % order of the IIR filters to design to match RT60 curve
st.tcFiltOrd = 4094;                    % order of the tone correction filter to design
st.maxProcLen_s = 12;                   % max for FDN processing
st.maxGARuntime_mins = 45;              % max time to run the GA
st.verboseFDN = false;                  % print debug info in the command line ap`p
st.convEarlyIR = true;                  % use the early reflections from the IR directly
st.earlyIRLen_samps = 4096;             % length to truncate the early IR to
st.designFiltsFromMel = true;           % IIR filter design uses LS to |H(m)|, group into mel bins first?
st.plotProgress = false;                % plot IR comparisons along the way?
st.tryStereo = true;                    % try a stereo reverb by just negating all the c coeffs for one side
st.toneCorrMindB = -50;
st.makePlots = false;                   % creates various plots along the way as we optimize
st.shortRun = true;
st.videoFrameRate = 80;

% tone correction method
% 'none' = none
% 'jot' = Jot's method (inverted T60 curve)
% 'emp' = empirical. Run w/o correction, look at spectral dif, design filt, run again
st.toneCorrectionMethod = 'emp';
st.toneCorrectionAvgLen_s = 0.5;        % length of the IR we avergage the energy over to get our spectral difference - begins at end of early IR

% possible fitness functions:
% 'ls' = least squares fit to the simmilarity test data
% 'edr' = average absolute error in dif of edr plots
% 'edc' = same as above, but just edc
% 'mfcc' = average euclidean distance of mfcc frames
% 'env' = average dif between signal envelopes

% these settings don't actually matter - but add structs with these fields into fitMeths
st.fitMethod = 'env';                   % string identifier of fitness function method
st.fitWithdB = false;                   % fit using a dB value of the feature (usually not a good idea)
st.fitWithDecExp = false;               % apply a decreasing exponential to the dif vs. time (i.e. difs early on matter more)
st.expWeightAtEnd = 0.01;               % the value of the exponential at the end of the signal (1 at beginning, this determines relative weighting)

% Criteria for the minimization performed
% 'two' = minimize the two norm (average dif)
% 'inf' = minimize infinity norm (max dif)
st.fitNormType = 'inf';

fitMeth_EnvInf = struct('fitMethod','env','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','inf');
fitMeth_EnvTwo = struct('fitMethod','env','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','two');
fitMeth_EnvTwoExp = struct('fitMethod','env','fitWithdB',false,...
    'fitWithDecExp',true,'expWeightAtEnd',0.001,'fitNormType','two');
fitMeth_Ls = struct('fitMethod','ls','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','two');
fitMeth_mfcc = struct('fitMethod','mfcc','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','two');
fitMeth_edr = struct('fitMethod','edr','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','two');
fitMeth_edc = struct('fitMethod','edc','fitWithdB',false,...
    'fitWithDecExp',false,'expWeightAtEnd',0.0,'fitNormType','two');
fitMeths = [fitMeth_EnvInf fitMeth_EnvTwoExp fitMeth_EnvTwo fitMeth_edr fitMeth_edc ...
     fitMeth_Ls fitMeth_mfcc];

% location where we begin looking at fitness
% 'start' = at the start
% 'minM' = at the minimum delay sample
% 'early' = after the early reflection ends
st.fitBeginLoc = 'minM';

% set the maximum delay line length and then the spread ratio (which
% affects lower bound)
minMLen_s = 0.001;  
maxMLen_s = 0.25;

% GA Params: lb = lower bound, ub = upper bound, np = num params of this
% type, gaInds will be these params' inds in the GA list, intCon = constrain
% to ints
bcLim = 10^(0/20);
gap_A = struct('name','A','lb',-1,'ub',1,'np',st.N*st.N,'gaInds',[],'intCon',false);
gap_b = struct('name','b','lb',-bcLim,'ub',bcLim,'np',st.N,'gaInds',[],'intCon',false);
gap_c = struct('name','c','lb',-bcLim,'ub',bcLim,'np',st.N,'gaInds',[],'intCon',false);
gap_d = struct('name','d','lb',0,'ub',1,'np',1,'gaInds',[],'intCon',false);
gap_m = struct('name','m','lb',round(minMLen_s*st.fs),...
    'ub',round(maxMLen_s*st.fs),...
    'np',st.N,'gaInds',[],'intCon',true);

% the param structs put into the field below determine what actually gets
% optimized by the GA, if they don't go in here, default values (defined in
% doFDNReverb....) will be used
st.paramsToGA = {gap_c, gap_m};

% if feedback matrix is not optimized, the possible defaults are
% 'had' = hadamard
% 'eye' = identity
st.defaultA = 'had';

% third octave band filters
BandsPerOctave = 3;
N = 8;           % Filter Order
F0 = 1000;       % Center Frequency (Hz)
f = fdesign.octave(BandsPerOctave,'Class 1','N,F0',N,F0,st.fs);
f.FilterOrder = 8;
F0 = validfrequencies(f);
Nfc = length(F0);
for i=1:Nfc,
    f.F0 = F0(i);
    Hd3(i) = design(f,'butter');
end
st.thirdOctFilts = Hd3(1:end-1);
st.thirdOctFreqs = F0(1:end-1);

if st.runBatch
    filenames = dir('Sounds/BatchInput/*.wav');
else
    filenames = struct('name',st.fileToMatch);
end

%% Create plots of the target IR features, not necessary for normal operation
if st.makePlots
    for i = 1:length(filenames)

        st.fileToMatch = filenames(i).name;
        st.fileToMatchBase = st.fileToMatch(1:end-4);
        st.fileToMatchNoSpaces = st.fileToMatchBase;
        st.fileToMatchNoSpaces(ismember(st.fileToMatchNoSpaces,' ,.:;!')) = [];
        
        st.tarFeats = extractMIRFeatures(st.fileToMatch,st.minComparedB,st.fs);
        
%         figure
%         surf(st.tarFeats.FrameTimes,st.tarFeats.LinFreqs,st.tarFeats.EDRdB);
%         shading interp; axis tight;
%         set(gca,'YScale','log')
%         xlabel('Time (s)'); ylabel('Frequency (Hz)'); zlabel('Power (dB)');
        
%         figure;
%         plot(st.tarFeats.IRTime,st.tarFeats.IR)
%         xlabel('Time (s)'); ylabel('Amplitude');
%         axis off;
%         set(gcf, 'color', 'none');
%         set(gca, 'color', 'none');
%         export_fig Documents/KeynoteImages/HallIRNaked.png



        figure('Position',[0 0 1000 1000])
        subplot(1,2,1)
        plot(st.tarFeats.IRTime,st.tarFeats.IR);
        title(sprintf('Impulse Response: %s (T_{60} = %0.1f s)',st.fileToMatchBase,st.tarFeats.RT60));xlabel('Time (s)');ylabel('Amplitude');
%         subplot(2,1,2)
%         surf(st.tarFeats.FrameTimes,st.tarFeats.BarkFreqs,st.tarFeats.EDRBarkdB);
%         set(gca,'YScale','log')
%         view(0,90); shading interp; axis tight; colorbar;
%         title('Energy Decay Relief');xlabel('Time (s)');ylabel('Frequency (Hz)');
        subplot(1,2,2)
        surf(st.tarFeats.FrameTimes,st.tarFeats.LinFreqs,st.tarFeats.STFTdB);
        set(gca,'YScale','log')
        view(0,90); shading interp; axis tight; colorbar;
        title('Short Time Fourier Transform');xlabel('Time (s)');ylabel('Frequency (Hz)');
        set(gcf, 'PaperUnits', 'inches');
        x_width=12.25 ;y_width=3.125;
        set(gcf, 'PaperPosition', [0 0 x_width y_width]); 
        zlim([-80 0]);
        saveas(gcf, sprintf('%s/Documents/Latex/5_evaluation/figures/TargetIRFeats_%s.png',pwd,st.fileToMatchNoSpaces));
        
        % make the IR/STFT plot
        figure('Position',[0 0 1000 1000])
        subplot(2,1,1)
        plot(st.tarFeats.IRTime,st.tarFeats.IR);

        title(sprintf('Target Impulse Response - %s', st.fileToMatchBase));
        xlabel('Time (s)');ylabel('Amplitude');
        axis tight;
        subplot(2,1,2)
        surf(st.tarFeats.FrameTimes,st.tarFeats.LinFreqs,st.tarFeats.STFTdB);
        set(gca,'YScale','log')
        view(0,90); shading interp; axis tight; colorbar;
        title('Short Time Fourier Transform');xlabel('Time (s)');ylabel('Frequency (Hz)');
        set(gcf, 'PaperUnits', 'inches');
        x_width=7.25 ;y_width=7.125;
        set(gcf, 'PaperPosition', [0 0 x_width y_width]); 
        zlim([-80 0]);
        saveas(gcf, sprintf('%s/Documents/Latex/4_proposed_system/figures/TargetIR_%s.png',pwd,st.fileToMatchNoSpaces));
    end
end

%% loop over all the files to optimize on and all the fitness methods to use, run the thing
for i = 1:length(filenames)
    
    for f = 1:length(fitMeths)
        
        close all;
        
        st.progFig = figure('Position', [0, 0, 1200, 801],'Visible', 'off');
        
        % setup the fitness method for this time
        st.fitMethod = fitMeths(f).fitMethod;
        st.fitWithdB = fitMeths(f).fitWithdB;
        st.fitWithDecExp = fitMeths(f).fitWithDecExp;
        st.expWeightAtEnd = fitMeths(f).expWeightAtEnd;
        st.fitNormType = fitMeths(f).fitNormType;
        
        % setup the target IR for this time, extract its features
        st.fileToMatch = filenames(i).name;
        dt = datestr(now,'mm-dd-yyyy-HH-MM');
        st.fileToMatchBase = sprintf('%s (%s|%s|%d)-%s',st.fileToMatch(1:end-4),st.fitMethod, st.fitNormType,st.fitWithDecExp, dt);
        st.fileToMatchNoSpaces = st.fileToMatchBase;
        st.fileToMatchNoSpaces(ismember(st.fileToMatchNoSpaces,' ,.:;!')) = [];
        st.tarFeats = extractMIRFeatures(st.fileToMatch,st.minComparedB,st.fs);
        
        % not to be messed with, must setup some empty matrices for later
        st.fit = [];
        st.fitMin = [];
        st.gaps = [];   % GA output params, will be a cell array of structs
        st.earlyIRPath = [];
        st.currGAFeats = [];    % the current ones
        st.empFirstPass = true; % used to signal when doing the first pass w/o TC when using empirical tone correction
        st.empFirstPassIR = [];
        st.empFeats = [];
        st.currBestGAFeats = [];    % the best ones
        st.genvelopes = [];
        st.generations = [];

        tCare = rt(st.tarFeats.IR,st.fs,st.toneCorrMindB);
        clip = st.tarFeats.IR(st.earlyIRLen_samps:round(tCare*st.fs));

        for v=1:length(st.thirdOctFilts)
            st.tarAvgPwrs(v) = mean(filter(st.thirdOctFilts(v),clip).^2);
        end

        st.dirName = sprintf('%s/Sounds/Outputs/%s',pwd, st.fileToMatchBase);

        if exist(st.dirName,'dir')
            rmdir(st.dirName,'s');
        end
        mkdir(st.dirName);
        audiowrite(sprintf('%s/TargetIR.wav',st.dirName),st.tarFeats.IR,st.fs);

        % Run it!
        [~,params] = runGA();

        if st.makePlots
            
            % make the IR/STFT plot
            figure('Position',[0 0 1000 1000])
            subplot(2,1,1)
            plot(st.currBestGAFeats.IRTime,st.currBestGAFeats.IR);
            if strcmp(st.fitMethod,'env')
                method = 'Envelope';
            elseif strcmp(st.fitMethod,'mfcc')
                method = 'MFCC';
            elseif strcmp(st.fitMethod,'ls')
                method = 'Reverb Perception Modeling';
            elseif strcmp(st.fitMethod,'edr')
                method = 'EDR';
            elseif strcmp(st.fitMethod,'edc')
                method = 'EDC';
            else
                method = st.fitMethod;
            end
                    
            title(sprintf('Best Fit IR - %s Fitness Function',method));
            xlabel('Time (s)');ylabel('Amplitude');
            axis tight;
            subplot(2,1,2)
            surf(st.currBestGAFeats.FrameTimes,st.currBestGAFeats.LinFreqs,st.currBestGAFeats.STFTdB);
            set(gca,'YScale','log')
            view(0,90); shading interp; axis tight; colorbar;
            title('Short Time Fourier Transform');xlabel('Time (s)');ylabel('Frequency (Hz)');
            set(gcf, 'PaperUnits', 'inches');
            x_width=7.25 ;y_width=7.125;
            set(gcf, 'PaperPosition', [0 0 x_width y_width]); 
            zlim([-80 0]);
            saveas(gcf, sprintf('%s/Documents/Latex/4_proposed_system/figures/BestFitIR_%s.png',pwd,st.fileToMatchNoSpaces));
            
            % make the evolution of fitness plot
            h = figure('Position',[0 0 800 400]);
            gensToPlot = [1 round(0.5*max(st.generations)) max(st.generations)];
            cc = ['m' 'b' 'r'];
            subplot(2,2,1:2)
            plot(st.tarFeats.IRTime, st.tarFeats.env,'DisplayName','Target','color','k');
            hold on;
            t = (1/st.fs)*(1:size(st.genvelopes,1));
            for g = 1:length(gensToPlot)
                plot(t,st.genvelopes(:,gensToPlot(g)),'color',cc(g),'DisplayName',sprintf('Gen %d', gensToPlot(g)));
                hold on;
            end
            legend('show','Location','NorthEast')
            title(sprintf('GA Fitness Progress - %s',st.fileToMatchBase)); xlabel('Time (s)'); ylabel('Magnitude');
            axis tight;

            % make the T60 comparison plot
            subplot(2,2,3)
            semilogx(st.tarFeats.BarkFreqs, st.tarFeats.RT60Bark);
            hold on
            semilogx(st.currBestGAFeats.BarkFreqs, st.currBestGAFeats.RT60Bark,'r');
            xlim([20 20000])
            axis tight; grid on;
            legend('Target','Synthetic','location','SouthWest');
            xlabel('Frequency (Hz)'); ylabel('T_{60} (s)'); title('T_{60} Fitness')

            % make the Spectral comparison plot
            subplot(2,2,4)
            t60 = rt(st.tarFeats.IR,st.fs,st.toneCorrMindB);
            sInd = find(st.tarFeats.FrameTimes > st.earlyIRLen_samps/st.fs,1);
            eInd = find(st.tarFeats.FrameTimes > t60,1)-1;

            clip = st.tarFeats.STFT(:,sInd:eInd);
            feat1AvgPwr = 10*log10(mean(clip.^2,2));

            t602 = rt(st.currBestGAFeats.IR,st.fs,st.toneCorrMindB);
            sInd = find(st.currBestGAFeats.FrameTimes > st.earlyIRLen_samps/st.fs,1);
            eInd = find(st.currBestGAFeats.FrameTimes > t602,1)-1;
            clip = st.currBestGAFeats.STFT(:,sInd:eInd);
            feat2AvgPwr = 10*log10(mean(clip.^2,2));
            semilogx(st.tarFeats.LinFreqs, feat1AvgPwr);
            hold on;
            semilogx(st.currBestGAFeats.LinFreqs, feat2AvgPwr,'r');
            axis tight; grid on;
            legend('Target','Synthetic','location','SouthWest')
            xlabel('Frequency (Hz)'); ylabel('Power (dB)'); title('Spectral Envelope Fitness')

            set(gcf, 'PaperUnits', 'inches');
            x_width=10.25 ;y_width=8.125;
            set(gcf, 'PaperPosition', [0 0 x_width y_width]); 
            saveas(h, sprintf('%s/Documents/Latex/5_evaluation/figures/EnvProgress_%s.png',pwd,st.fileToMatchNoSpaces));
            
            % create the movie from the pngs
            system(sprintf('~/bin/ffmpeg -framerate %d -i "%s/ProgressPNGs/%04d.png" -c:v libx264 -r 30 -pix_fmt yuv420p "%s/Progress.mp4"',st.videoFrameRate, st.dirName,st.dirName));
        end
        
        %%
        % save the current best
        outFname = sprintf('%s/GABestIR.wav', st.dirName);
        st.currBestGAFeats.IR = 0.99*st.currBestGAFeats.IR/max(abs(st.currBestGAFeats.IR));
        audiowrite(outFname,st.currBestGAFeats.IR,st.fs);
        state = st;
        save(sprintf('%s/GAState', st.dirName),'state');
        %% Inspect it, convolve with drums

    %     outFname = 'Sounds/Outputs/gaOutputIR.wav';
    %     IR_Out = audioread(outFname);

        %%
    %     inspectIR(st.tarFeats.IR,st.fs,'Target');

        %%
    %     inspectIR(st.currBestGAFeats.IR,st.fs,'Estimate');

        %%
        [drums,sr] = audioread('DryDrums.wav');
        drums = drums(:,1);
        if sr ~= st.fs
            drums = resample(drums,st.fs,sr);
        end

        drums = drums(:,1);
        tarDrums = conv(drums,st.tarFeats.IR);
        estimDrums = conv(drums,st.currBestGAFeats.IR);

        %%
        estimDrums = 0.99*estimDrums/max(abs(estimDrums));
    %     soundsc(estimDrums,st.fs);
        audiowrite(sprintf('%s/GADrums.wav', st.dirName), estimDrums,st.fs);

        %%
        tarDrums = 0.99*tarDrums/max(abs(tarDrums));
    %     soundsc(tarDrums,st.fs );
        audiowrite(sprintf('%s/TargetDrums.wav', st.dirName),tarDrums,st.fs);

        %%
        if st.tryStereo
            params = st.currBestGAParams;
            rL = runFastFDNWithParamStruct(params);
            params.c = -1*params.c;
            rR = runFastFDNWithParamStruct(params);
            minLen = min(length(rL),length(rR));
            yS = [rL(1:minLen) rR(1:minLen)];
            yS = 0.99*yS/max(max(abs(yS)));
            audiowrite(sprintf('%s/GABestIRStereo.wav', st.dirName), yS,st.fs);
            dS = [conv(yS(:,1),drums) conv(yS(:,2),drums)];
            dS = dS/max(max(abs(dS)));
            audiowrite(sprintf('%s/GADrumsStereo.wav', st.dirName), dS,st.fs);
        end
        %% look at the dif in STFT
        minLen = min(size(st.tarFeats.STFT,2),size(st.currBestGAFeats.STFT,2));

        stftDif = st.tarFeats.STFTdB(:,1:minLen) - st.currBestGAFeats.STFTdB(:,1:minLen);
        % stftdB = 10*log10(abs(stftDif));
        figure
        surf(stftDif)
        shading interp
        colorbar
        view(0,90)
        axis tight
    end
    
end
