close all; 

[x,fs] = wavread('22 Vocal Plate');
% [x,fs] = wavread('12 Small Booth');
% [x,fs] = wavread('14 Bright Room');
% x = x(1:20e3,1);

x = x(:,1);
alpha_att = 0.09;
alpha_dec = 0.001;
y = audioEnv(x,alpha_att, alpha_dec);
logx = 20*log10(abs(x));
logenv = 20*log10(y);
T = linspace(0,length(x)/fs,length(x));
plot(T,logx);
hold on;
plot(T,logenv,'r');
ylim([-80 0])
axis tight;
grid on;