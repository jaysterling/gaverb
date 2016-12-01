function d = definition(x,fs,len_ms)

xs = x.^2;
switchoverSamp = round(fs*len_ms/1000);
if switchoverSamp > length(x)
    d = 0;
    return;
end
num = sum(xs(1:switchoverSamp));
denom = sum(xs(1:length(xs)));
d = num/denom;