function y = rms(x, win_ms, fs, ovLap)

s = x.*x;
win_samples = fs*win_ms/1000;
stride = win_samples*(1.0 - ovLap);

numFrames = ceil(length(s)/stride);

m = zeros(1,numFrames);
for i = 1:numFrames
    startInd = (i-1)*stride + 1;
    stopInd = (i-1)*stride + win_samples;
    if( stopInd > length(s))
        stopInd = length(s);
    end
    m(i) = mean(s(startInd:stopInd));
end

y = sqrt(m);