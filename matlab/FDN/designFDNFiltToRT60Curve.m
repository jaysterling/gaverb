function [b,a] = designFDNFiltToRT60Curve(rt60f,fs,F,m,ord)
if F(1) ~= 0
    F = [0; F];
    rt60f = [rt60f(1); rt60f];
end
if F(end) ~= fs/2
    F = [F; fs/2];
    rt60f = [rt60f; rt60f(end)];
end
omega = F/(fs/2);

% make the RT60 values above maxF the same as the average below it - otherwise we
% have really noisy stuff going on up there
maxF = 16e3;
avgRange = 30;
maxFInd = find(F>maxF,1)-1;
if ~isempty(maxFInd) && length(rt60f) > 128 % dummie check, don't do this on mel/bark stuff
    rt60f(maxFInd:end) = mean(rt60f(maxFInd-avgRange-1:maxFInd-1));
end
Habs = 10.^((-3*m/fs)./rt60f);
% semilogx(F,20*log10(Habs))
% axis tight; grid on;
[b,a] = yulewalk(ord,omega,Habs);