function [y, status, stdout] = fdnReverbFast(m, bqCoeffs, tcBQCoeffs,tcFIR, fs, A, b, c, d,earlyPath,inPath,maxLen, blockSize,verbose)

if nargin<14
    verbose = 0;
end
binPath = '~/bin/fdnreverb';
outPath = '~/Desktop/fdnout.wav';
dim = length(m);
cmd = sprintf('%s -dim %d -fs %d -d %0.10f -bs %d', binPath, dim, fs, d, blockSize);
if verbose == 1
    cmd = sprintf('%s -v', cmd);
end
cmd = sprintf('%s -b %0.10f', cmd, b(1));
for i = 2:dim
    cmd = sprintf('%s %0.10f', cmd, b(i));
end

cmd = sprintf('%s -c %0.10f', cmd, c(1));
for i = 2:dim
    cmd = sprintf('%s %0.10f', cmd, c(i));
end

cmd = sprintf('%s -del %0.3f', cmd, m(1));
for i = 2:dim
    cmd = sprintf('%s %0.3f', cmd, m(i));
end

if ~isempty(bqCoeffs)
    cmd = sprintf('%s -BQ', cmd);
    for r = 1:dim
        for c = 1:size(bqCoeffs,2)
            cmd = sprintf('%s %0.14f', cmd, bqCoeffs(r,c));
        end
    end
end
if ~isempty(tcBQCoeffs)
    cmd = sprintf('%s -TBQ %0.10f', cmd, tcBQCoeffs(1));
    for i = 2:length(tcBQCoeffs)
        cmd = sprintf('%s %0.10f', cmd, tcBQCoeffs(i));
    end
end

if ~isempty(tcFIR)
    cmd = sprintf('%s -TFIR %0.10f', cmd, tcFIR(1));
    for i = 2:length(tcFIR)
        cmd = sprintf('%s %0.10f', cmd, tcFIR(i));
    end
end

cmd = sprintf('%s -A', cmd);
for r = 1:dim
    for c = 1:dim
        cmd = sprintf('%s %0.15f', cmd, A(r,c));
    end
end

if ~isempty(earlyPath)
    cmd = sprintf('%s -early "%s"',cmd, earlyPath);
end
if ~isempty(inPath)
    cmd = sprintf('%s -in "%s"',cmd, inPath);
end

cmd = sprintf('%s -out %s', cmd, outPath);
if ~isempty(maxLen)
    cmd = sprintf('%s -ms %d', cmd, maxLen);
end
% cmd
[status, stdout] = system(cmd);
y = audioread(outPath);
