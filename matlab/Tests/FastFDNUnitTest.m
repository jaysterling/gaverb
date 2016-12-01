
close all

[x,fs] = audioread('12 Small Booth.wav');
x = x(:,1)*0.95;
[xEarly,xLate] = splitToEarlyLate(x,fs,80);

N = 4;
fs = 44100;
dBThreshToPass = -90;
filtOrd = 6;
tcFiltOrd = 10;
tcFIROrd = 4094;
fdnVerbose = true;

A = (1/N)*hadamard(N);
m = [2015 3501 3211 2976 1987 7609 3401 44103];
m = m(1:N);
filtB = zeros(N,filtOrd+1);
filtA = zeros(N,filtOrd+1);

for i = 1:N
    [filtB(i,:), filtA(i,:)] = designFDNFiltToIR(x,fs,m(i),filtOrd);
end

b = ones(N,1); 
cb = [1; -1];
c = repmat(cb,N/2,1)';
d = 0.5;

% design the filters given the delay lengths
bqCoeffs = zeros(N,5*ceil(filtOrd/2));
for i = 1:N
    sos = tf2sos(filtB(i,:),filtA(i,:));
    for s = 1:size(sos,1)
        bqCoeffs(i,1+5*(s-1):5*s) = sos(s,[1 2 3 5 6]);
    end
end

%% first, just make sure that no matter the block size we run at, output is the same

[xF, stat, stdout] = fdnReverbFast(m, [],[],[], fs, A, b, c, d,[],[],fs*40,64,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

[xFL, stat, stdout] = fdnReverbFast(m, [],[],[], fs, A, b, c, d,[],[],fs*40,2048,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

minLen = min(length(xF),length(xFL));
dif = abs(xF(1:minLen)-xFL(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Changing Blocksize - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Changing Blocksize - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xF);
    hold on
    plot(xFL,'r')
    axis tight; grid on;
    return;
end

%% first test with no filters, no early reflections
[xF, stat, stdout] = fdnReverbFast(m, [],[],[], fs, A, b, c, d,[],[],fs*40,4096,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

xM = fdnReverb(m, [],[],[],[],[], fs, A, b, c, d);
minLen = min(length(xF),length(xM));
dif = abs(xF(1:minLen)-xM(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Early: NO LP: NO - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Early: NO LP: NO - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xM);
    hold on
    plot(xF,'r')
    axis tight; grid on;
    legend('CLI','Matlab')
    return;
end


%% Now do it with early, no filters


earlyIRPath = '/Users/jcoggin/Desktop/earlyIR.wav';
audiowrite(earlyIRPath,xEarly,fs,'BitsPerSample',32);
xE = audioread(earlyIRPath);
maxDBDif = 20*log10(max(abs(xEarly - xE)));
if maxDBDif > dBThreshToPass
    fprintf('Original and saved early IRs dont match, dif by %0.1f dB\n', maxDBDif);
    return;
end

xM = fdnReverb(m, [],[],[],[],[], fs, A, b, c, d,xEarly);
[xF, stat, stdout] = fdnReverbFast(m, [],[],[], fs, A, b, c, d,earlyIRPath,[],fs*40,4096,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

minLen = min(length(xF),length(xM));
dif = abs(xF(1:minLen)-xM(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Early: YES LP: NO - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Early: YES LP: NO - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xM);
    hold on
    plot(xF,'r')
    plot(xEarly,'g')
    axis tight; grid on;
    return;
end

%% Now with everything

xM = fdnReverb(m, filtB, filtA,[],[],[], fs, A, b, c, d,xEarly);
[xF, stat, stdout] = fdnReverbFast(m, bqCoeffs,[],[], fs, A, b, c, d,earlyIRPath,[],fs*40,4096,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

minLen = min(length(xF),length(xM));
dif = abs(xF(1:minLen)-xM(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Early: YES LP: YES - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Early: YES LP: YES - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xM);
    hold on
    plot(xF,'r')
    axis tight; grid on;
    return;
end

%% And with tone correction BQ

[t60f,F] = rtcurve(x,fs,-60,0);
[tcB,tcA] = designToneCorrectionFiltToRT60Curve(t60f,fs,F,tcFiltOrd);
sos = tf2sos(tcB,tcA);
bqToneCoeffs = zeros(1,5*ceil(tcFiltOrd/2));
for s = 1:size(sos,1)
    bqToneCoeffs(1,1+5*(s-1):5*s) = sos(s,[1 2 3 5 6]);
end

xM = fdnReverb(m, filtB, filtA,tcB,tcA,[], fs, A, b, c, d,xEarly);
[xF, stat, stdout] = fdnReverbFast(m, bqCoeffs,bqToneCoeffs,[], fs, A, b, c, d,earlyIRPath,[],fs*40,4096,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

minLen = min(length(xF),length(xM));
dif = abs(xF(1:minLen)-xM(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Early: YES LP: YES TCBQ: YES - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Early: YES LP: YES TCBQ: YES - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xM);
    hold on
    plot(xF,'r')
    axis tight; grid on;
    return;
end

%% And with tone correction FIR

omega = [0 0.4 1];
M = [1.0 0.5 0.2];
tcB = fir2(tcFIROrd,omega,M);

xM = fdnReverb(m, filtB, filtA,[],[],tcB, fs, A, b, c, d,xEarly);
[xF, stat, stdout] = fdnReverbFast(m, bqCoeffs,[],tcB, fs, A, b, c, d,earlyIRPath,[],fs*40,4096,fdnVerbose);
if stat ~= 0
   error('fdnreverb invocation failed'); 
end
disp(stdout);

minLen = min(length(xF),length(xM));
dif = abs(xF(1:minLen)-xM(1:minLen));
maxDBDif = 20*log10(max(dif));
if maxDBDif < dBThreshToPass
    fprintf('Early: YES LP: YES TCFIR: YES - PASS (%0.1f dB)\n', maxDBDif);
else
    fprintf('Early: YES LP: YES TCFIR: YES - FAIL (%0.1f dB)\n', maxDBDif);
    plot(xM);
    hold on
    plot(xF,'r')
    axis tight; grid on;
    return;
end

display('PASS!!!');