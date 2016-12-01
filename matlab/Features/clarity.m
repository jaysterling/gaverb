function c = clarity(x,fs,len_ms)

xs = x.^2;
switchoverSamp = round(fs*len_ms/1000);
if switchoverSamp > length(x)
    c = 0;
    return;
end
num = sum(xs(1:switchoverSamp));
denom = sum(xs(switchoverSamp+1:length(xs)));
c = 10*log10(num/denom);

