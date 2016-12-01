close all;
fName = 'Samp_3 Rooms 10 Large Wooden Room  M-to-S.wav';

[x,fs] = audioread(fName);
x = x(:,1);
ord = 8;
m = rand(ord,1);
minM = 500;
maxM = 8000;
m = round(m.*(maxM-minM) + minM);
filtOrd = 10;
filtB = zeros(ord,filtOrd+1);
filtA = zeros(size(filtB));

for i = 1:ord
    [filtB(i,:),filtA(i,:)] = designFDNFiltToIR(x,fs,m(i),filtOrd);
end
H2 = (1/sqrt(2))*[1 1; -1 1];
H4 = (1/sqrt(2))*[H2 H2; -H2 H2];
H8 = (1/sqrt(2))*[H4 H4; -H4 H4];
% A = eye(ord);
A = H8;
b = [1; 1; 1; 1; 1; 1; 1; 1]; 
c = [1 -1 1 -1 1 -1 1 -1];
d = 0.5;

y = fdnReverb(m,filtB,filtA,[],[],[],fs,A,b,c,d);

%% look at how well our curve matches the original

curve = rtcurve(y,fs,-60,0);
plot(curve)
hold on
tarcurve = rtcurve(x,fs,-60,0);
plot(tarcurve,'r')
axis tight; grid on;

%% test it out!
[drums,fsd] = audioread('DryDrums.wav');
drums = drums(:,1);
if fsd ~= fs
    drums = resample(drums,fs,fsd);
end

testDrumsHad = conv(drums,y);
tarDrums = conv(drums,x);
