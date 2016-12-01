function edr = edrFromPowSpec(spec)
edr = zeros(size(spec));
for i=1:size(spec,1)
    edr(i,:) = fliplr(cumsum(fliplr(spec(i,:))));
end