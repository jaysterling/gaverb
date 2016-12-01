% Take in a spectrogram in dB, trim the time ending to the first frame
% where all bins are below the minDB, then fill all individ bins below that
% to = minDB

function fixed = TrimFillNorm(B_db, minDB)

offset = max(max(B_db));
B_db = B_db - offset;

Imin = find(max(B_db) > minDB,1,'last');

[nBins,nFrames] = size(B_db);
for i=1:nFrames
  I = find(B_db(:,i) < minDB);
  if (I)
    B_db(I,i) = minDB;
  end
end

if ~isempty(Imin)
    fixed = B_db(:,1:Imin);
else
    fixed = B_db;
end