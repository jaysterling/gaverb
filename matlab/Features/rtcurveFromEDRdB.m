function rtc = rtcurveFromEDRdB(e,T,dB)

rt = zeros(size(e,1),1);
for i = 1:size(rt,1)
    f = find(e(i,:) < e(i,1)+dB,1);
    if ~isempty(f)
        rt(i) = f;
    else
        f = find(e(i,:) < e(i,1)+dB/2,1);
        if ~isempty(f)
            rt(i) = 2*f;
        else
            f = find(e(i,:) < e(i,1)+dB/4,1);
            if ~isempty(f)
                rt(i) = 4*f;
            else
                rt(i) = 1;
            end
        end
    end
end
rtc = (rt-1)*(T(2)-T(1));