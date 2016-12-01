
function [xOut, state] = runGA()
global st

numVars = NumGAVars(st);

% Setup lower + upper bounds for each set of variables
lb = [];
ub = [];
intCon = [];
for i = 1:length(st.paramsToGA)
    st.paramsToGA{i}.gaInds = length(lb)+1:length(lb)+st.paramsToGA{i}.np;
    lb = [lb st.paramsToGA{i}.lb*ones(1,st.paramsToGA{i}.np)];
    ub = [ub st.paramsToGA{i}.ub*ones(1,st.paramsToGA{i}.np)];  
    if st.paramsToGA{i}.intCon
        intCon = [intCon st.paramsToGA{i}.gaInds];
    end
end

% createHandle = @InitialConditions;
% options = gaoptimset('FitnessLimit',threshToStop,'TimeLimit',30*60);
options = gaoptimset('TimeLimit',60*st.maxGARuntime_mins,'FitnessLimit',0);
if st.plotProgress
    options.PlotFcns = @plotGAProgress;
end
options.OutputFcns = @gaPerGenFunc;
if st.shortRun
    options.PopulationSize = 8;
    options.EliteCount = 1;
    options.TimeLimit = 30;
end

% if there are previous results, seed it with those
% if exist(sprintf('matlab/Workspaces/GAState_%s.mat', st.fileToMatchBase),'file')
%     load(sprintf('matlab/Workspaces/GAState_%s', st.fileToMatchBase));
%     initPop = zeros(1,numVars);
%     if state.N == st.N
%         for i = 1:length(state.paramsToGA)
%             for s = 1:length(st.paramsToGA)
%                 if strcmp(state.paramsToGA{i}.name,st.paramsToGA{s}.name)
%                     initPop(st.paramsToGA{s}.gaInds) = state.currBestGAParams.(state.paramsToGA{i}.name);
%                 end
%             end
%         end
%         options.InitialPopulation = initPop;
%     end
% end

if st.convEarlyIR
    st.earlyIRPath = sprintf('%s/EarlyIR.wav',st.dirName);
    [st.earlyIR,~] = splitToEarlyLate(st.tarFeats.IR, st.fs, 1000*(40 + st.earlyIRLen_samps)/st.fs);
    st.earlyIR = st.earlyIR(1:st.earlyIRLen_samps);
    audiowrite(st.earlyIRPath,st.earlyIR,st.fs,'BitsPerSample',32);
    
%     dif = max(abs(st.earlyIR - st.tarFeats.IR(1:st.earlyIRLen_samps)))
end

st.gaOptions = options;

% Run the GA
[vars,fval] = ga(@rirFit,numVars, [],[],[],[],...
    lb,ub,[],intCon,options);

% Take the output and make the final IR
xOut = doFDNReverbWithGAOutput(vars);
state = vars;

function nVars = NumGAVars(params)
nVars = 0;
for i = 1:length(params.paramsToGA)
    nVars = nVars + params.paramsToGA{i}.np;
end
    
