function ts = centerTime(x,fs)
ts = ((1:length(x))*(x.^2))/(sum(x.^2)*fs);
