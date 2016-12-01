function inds = tightestSubset(x,k,minOrMax)
inds = 1:size(x,2);
remains = x;
while length(inds) > k
    if strcmp(minOrMax, 'min')
        nears = clusteredPoints(remains,length(inds)-1,minOrMax);
    elseif strcmp(minOrMax,'max')
        nears = largestSpread(remains,length(inds)-1);
    else
        error('Unknown minOrMax string');
    end
    remains = remains(:,nears);
    inds = inds(nears);
end