function y = zcPerFrame(x, fs, frame_ms)

frameSamps = round(fs*frame_ms/1000);

zc = zCrossings(x);
y = zeros(ceil(length(zc)/frameSamps),1);

for i = 1:length(y)
    startInd = 1 + (i-1)*frameSamps;
    endInd = i*frameSamps;
    if endInd > length(zc)
        endInd = length(zc);
    end
    y(i) = zc(endInd) - zc(startInd);
end
