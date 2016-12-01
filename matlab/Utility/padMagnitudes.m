function [Fnew,Mnew] = padMagnitudes(fs,F,M)

if size(F,1) == 1
    F = F';
end
if size(M,1) == 1
    M = M';
end

Fnew = F;
Mnew = M;
if Fnew(1) ~= 0
    Fnew = [0; F];
    Mnew = [Mnew(1); Mnew];
end
if Fnew(end) ~= fs/2
    Fnew = [Fnew; fs/2];
    Mnew = [Mnew; Mnew(end)];
end