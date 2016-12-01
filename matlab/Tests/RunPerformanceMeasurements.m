close all; clear all;

targetFile = 'R1 Nuclear Reactor Hall.wav';
[targetIR,fs] = audioread(targetFile);
targetIR = targetIR(:,1);

poss_bs = [64 128 256 512 1024];
poss_IRLen_s = [1 2 3 4 6 10];
poss_N = [8 16];

earlyIRPath = sprintf('%s/Sounds/perfTestEarlyIR.wav',pwd);
inPath = sprintf('%s/anechoic/VocalHarmony.wav',pwd);
outPath = sprintf('%s/Sounds/perfTestOut.wav',pwd);
decayIIROrd = 6;
toneFIROrd = 4094;
earlyIRLen = 4096;

results = [];

omega = [0 0.4 1];
M = [1.0 0.5 0.2];
tcB = fir2(toneFIROrd,omega,M);
        
for bs = poss_bs
    for IRLen_s = poss_IRLen_s
        ir = targetIR(1:fs*IRLen_s);
        audiowrite(earlyIRPath,ir,fs);
        cmd = sprintf('~/bin/fdnreverb -fs %d -bs %d -early %s -in %s -out %s',fs,bs,earlyIRPath,inPath,outPath);
        fprintf('Running Convolution for %d second IR\n',IRLen_s);
        [status,output] = system(cmd);
        if status ~= 0
            error('Processing failed')
        end
        f = strfind(output,' ');
        CPU = str2double(output(f(end)+1:end));
        memSize = 3*(length(ir));
        perf = struct('Method','conv','BlockSize',bs,'IRLen_s',IRLen_s,'N',0,'Memory',memSize,'CPULoad',CPU);
        results = [results perf];
    end
    
    earlyIR = targetIR(1:earlyIRLen);
    audiowrite(earlyIRPath,earlyIR,fs);
    
    for N = poss_N
        b = ones(N,1);
        c = 0.3*b;
        d = 1.0;
        A = (1/sqrt(N))*hadamard(N);
        m = 500 + round(5000*rand(N,1));
        verbose = 0;
        
        for i = 1:N
            [filtb,filta] = designFDNFiltToIR(targetIR,fs,m(i),decayIIROrd);
            sos = tf2sos(filtb,filta);
            for s = 1:size(sos,1)
                bqCoeffs(i,1+5*(s-1):5*s) = sos(s,[1 2 3 5 6]);
            end
        end
        
        fprintf('Running FDN N=%d\n',N);
        [~,status,output] = fdnReverbFast(m,bqCoeffs,[],tcB,fs,A,b,c,d,earlyIRPath,inPath,[],bs,verbose);
        if status ~= 0
            error('Processing failed')
        end
        f = strfind(output,' ');
        CPU = str2double(output(f(end)+1:end));
        memSize = 3*((2^(nextpow2(toneFIROrd))) + earlyIRLen) + 4*(3*N + ceil((decayIIROrd/2))*5*N);
        perf = struct('Method','FDN','BlockSize',bs,'N',N,'IRLen_s',0,'Memory',memSize,'CPULoad',CPU);
        results = [results perf];
    end
end

%%
save('matlab/Workspaces/PerformanceTestResults','results');

%%
clear all;
load('matlab/Workspaces/PerformanceTestResults');

%% generate CPU performance graph

irls = [6 3 1];
FDNs = [16 8];

ccIR = 1.0*autumn(length(irls));
ccFDN = 1.0*winter(length(FDNs)+1);
for irl = irls
    a = find([results.IRLen_s] == irl);
    s = results(a);
    semilogx([s.BlockSize], [s.CPULoad],'-o','DisplayName',sprintf('%ds Conv', irl),...
        'color',ccIR(find(irls==irl,1),:),'LineWidth',2,'MarkerEdgeColor',0.4*ones(1,3));
    hold on
end

for sz = FDNs
    a = find([results.N] == sz);
    s = results(a);
    semilogx([s.BlockSize], [s.CPULoad],'-o','DisplayName',sprintf('N=%d FDN', sz),...
        'color',ccFDN(find(FDNs==sz,1),:),'LineWidth',2,'MarkerEdgeColor',0.4*ones(1,3));
    hold on
end
axis tight; grid on;
title('Reverb CPU Performance'); xlabel('Buffer Size (samples)'); ylabel('CPU Load (%)');
legend('show');
saveas(gcf,sprintf('%s/Documents/Latex/5_evaluation/figures/PerformanceGraph.png',pwd));


%% generate memory usage plot

bar((1/1e6)*[results(7:8).Memory results(1:6).Memory])
title('Memory Cost for FDN and Convolution Reverbs');
ylabel('Memory (MB)');
set(gca,'XtickLabel',{'N=8 FDN','N=16 FDN','1s IR','2s IR','3s IR','4s IR','6s IR','10s IR'})
saveas(gcf,sprintf('%s/Documents/Latex/5_evaluation/figures/MemoryGraph.png',pwd));
