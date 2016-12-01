%% calculate linear energy decay relief of an IR

function y = edc(h)

y = zeros(size(h));
hs = h.^2;
s = 0;
for i = 1:length(y)
    s = s + hs(length(y) - i + 1);
    y(length(y) - i + 1) = s;
end