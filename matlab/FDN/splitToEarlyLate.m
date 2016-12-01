function [x_early, x_late] = splitToEarlyLate(x,fs,t_ms)

% for now, we do a simple cut at 80 ms
lastSamp = round(fs*t_ms/1000);
x_early = x(1:lastSamp,:);
x_late = x(lastSamp+1:length(x),:);