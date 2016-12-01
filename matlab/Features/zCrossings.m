function zc = zCrossings(x)

c = 0;
zc = zeros(1,length(x));
for i = 2:length(x)
    if x(i-1) <= 0 && x(i) > 0
        c = c + 1;
    end
    if x(i-1) >= 0 && x(i) < 0
        c = c + 1;
    end
    zc(i) = c;
end
