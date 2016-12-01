function [b,a] = designToneCorrectionFiltToRT60Curve(rt60f,fs,F,ord)

if F(1) ~= 0
    F = [0; F];
    rt60f = [rt60f(1); rt60f];
end
if F(end) ~= fs/2
    F = [F; fs/2];
    rt60f = [rt60f; rt60f(end)];
end

omega = F/(fs/2);
Habs = min(rt60f) * (1./rt60f);
[b,a] = yulewalk(ord,omega,Habs);
% semilogx((fs/2)*omega,20*log10(Habs))
% hold on
% [H,W] = freqz(b,a,512);
% semilogx((fs/(2*pi))*W,20*log10(abs(H)),'r')
% semilogx(F,rt60f,'k')
% axis tight; grid on;