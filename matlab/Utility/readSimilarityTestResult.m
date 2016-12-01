function data = readSimilarityTestResult(filename)

fID = fopen(filename);
if fID == -1
    error('Could not open file');
end

userInfo =  textscan(fID,'Age %d Sex %s');
isMale = 0;
if strcmp(userInfo{2},'Male')
    isMale = 1;
end

resMat = [];
tLine = fgets(fID);
while ischar(tLine) && length(tLine)>1
    results = sscanf(tLine,'%d %d %d');
    resMat = [resMat; results'];
    tLine = fgets(fID);
end

tLine = fgets(fID);
wavNames = {};
while ischar(tLine) && length(tLine)>1
    wavLine = sscanf(tLine,'%d %s');
    wavNames{end+1} = char(tLine(4:end-2));
    tLine = fgets(fID);
end
data = struct('age',userInfo{1},'isMale',isMale,'results',resMat,'files',{wavNames});