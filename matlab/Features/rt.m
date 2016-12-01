% function takes in a time series, x, the sampling freq, fs, and the
%  dB attenuation in query, ex. pass dB = 60 for RT60 time

function tx = rt(x,fs,dB)
e = edc_db(x,-140);
if round(dB) == -20 || round(dB) == -30
    firstToBe = e(1) -5;
    lastToBe = firstToBe + dB;
    sInd = find(e<firstToBe,1);
    eInd = find(e<lastToBe,1);
    if isempty(sInd) || isempty(eInd)
        samps = length(x);
    else
        samps = eInd - sInd;
    end
else
    dBToBe = e(1) + dB;
    ind = find(e<dBToBe,1);
    if isempty(ind)
        samps = length(x);
    else
        samps = ind;
    end
end

tx = samps/fs;
