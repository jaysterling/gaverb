close all

load('similarityTestFields')

filenames = dir('Documents/SimilarityTestOutput/*.txt');

maxSimilarity = 5;
prefixLen = 6;  % 'Drums_'

resArray = struct([]);
for i = 1:length(filenames)
    resArray = [resArray readSimilarityTestResult(filenames(i).name)];
end
numClips = length(resArray(1).files);
simMat = zeros(numClips,numClips,length(resArray));

for i = 1:length(resArray)
    scores = resArray(i).results;
    for r = 1:size(scores,1)
        simMat(scores(r,1),scores(r,2),i) = scores(r,3);
    end
end
avgSimMat = mean(simMat,3);
triAvgSimMat = (avgSimMat + avgSimMat')/2;

surf(avgSimMat)
view(0,90)
colorbar
camlight left

numPairs = numClips*(numClips-1)/2;

simVec = [];
for i = 1:numClips
    for j = i+1:numClips
        simVec = [simVec; triAvgSimMat(i,j)];
    end
end
difVec = maxSimilarity - simVec;
filesArray = struct([]);
for i = 1:numClips
    for j = i+1:numClips
        entry = struct('clip1',resArray(1).files(i),'clip2',resArray(1).files(j));
        filesArray = [filesArray entry];
    end
end

clipDifMap = zeros(numPairs,length(fieldsToMax));
% now go over every combination, compute diffs for each maximized variable
cnt = 1;
for i = 1:numClips
    for j = i+1:numClips
        
        % find the first and second clips in the stats
        for c = 1:length(finalStats)
            fname1 = resArray(1).files{i};
            fname1 = fname1(prefixLen+1:end);
            fname2 = resArray(1).files{j};
            fname2 = fname2(prefixLen+1:end);
            if strcmp(fname1,finalStats(c).filename)
                s1 = finalStats(c);
            elseif strcmp(fname2,finalStats(c).filename)
                s2 = finalStats(c);
            end
        end
        % now get the difs for each maximized variable for the pair
        for m = 1:length(fieldsToMax)
            clipDifMap(cnt,m) = abs(s1.(fieldsToMax{m}) - s2.(fieldsToMax{m}));
        end
        cnt = cnt + 1;
    end
end

lsWeights = clipDifMap\difVec;
save('PerceptualWeights','lsWeights');

yp = clipDifMap*lsWeights;
wDif = difVec - yp;

