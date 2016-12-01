
close all

[x,fs] = audioread('12 Small Booth.wav');
x = x(:,1);
[xEarly,xLate] = splitToEarlyLate(x,fs);
xEarly = xEarly*0.95;

earlyIRPath = '/Users/jcoggin/Desktop/earlyIR.wav';
audiowrite(earlyIRPath,xEarly,fs,'BitsPerSample',32);

size = 4;
fs = 44100;

% Stautner and Puckette
% m = [0 1 1 0; -1 0 0 -1; 1 0 0 -1; 0 1 -1 0];
% m = m/(sqrt(2));

% Hadamard
m = 0.45*[1 1 1 1; 1 -1 1 -1; 1 1 -1 -1; 1 -1 -1 1];

% orthonormal basis of random matrix
% m = orth(rand(size));

% m = zeros(size);
% m(1,:) = [0.2 0.4 0.3 0.1];
% for i = 2:size
%     m(i,:) = circshift(m(i-1,:),1,2);
% end
delays = [2015 3501 3211 2976];
Fc = [8000 1200 500 2000];
% Fc = [];
b = [1; 1; 1; 1]; 
c = [1 -1 1 -1];
d = 0.5;
fname = 'fdnOutput';
% xM = fdnReverb(delays, Fc, fs, m, b, c, d,xEarly);

outIR = fdnReverbFast(delays, Fc, fs, m, b, c, d,earlyIRPath,[],fs*40,4096);
inspectIR(x,fs);
