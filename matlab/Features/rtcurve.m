function [rt,F] = rtcurve(x,fs,dB,doAsMel)

[e,F,T,frameLen,stride] = edr(x,fs,doAsMel);
rt = zeros(size(e,1),1);
for i = 1:size(e,1)
    f = find(e(i,:) < e(i,1)+dB,1);
    if ~isempty(f)
        rt(i) = (frameLen/2 + (f-1)*stride)/fs;
    else
        f = find(e(i,:) < e(i,1)+dB/2,1);
        if ~isempty(f)
            rt(i) = 2*(frameLen/2 + (f-1)*stride)/fs;
        else
            f = find(e(i,:) < e(i,1)+dB/4,1);
            if ~isempty(f)
                rt(i) = 4*(frameLen/2 + (f-1)*stride)/fs;
            else
                rt(i) = 0;
            end
        end
    end
end