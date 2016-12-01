function fVal = getFitnessValue(xTst,xTar,fs)

global st;

if strcmp(st.fitMethod, 'ls')
    load('similarityTestFields');
    load('PerceptualWeights');
    difVec = zeros(1,length(fieldsToMax));
    for i = 1:length(fieldsToMax)
        field = fieldsToMax{i};
        if strcmp(field,'EDT')
            difVec(i) = abs(st.currGAFeats.EDT - st.tarFeats.(fieldsToMax{i}));
        elseif strcmp(field,'C50')
            difVec(i) = abs(st.currGAFeats.C50 - st.tarFeats.(fieldsToMax{i}));
        elseif strcmp(field,'D50')
            difVec(i) = abs(st.currGAFeats.D50 - st.tarFeats.(fieldsToMax{i}));
        elseif strcmp(field,'TS')
            difVec(i) = abs(st.currGAFeats.TS  - st.tarFeats.(fieldsToMax{i}));
        elseif strcmp(field,'InitCentroid')
            difVec(i) = abs(st.currGAFeats.InitCentroid  - st.tarFeats.(fieldsToMax{i})); 
        elseif strcmp(field,'RT20')
            difVec(i) = abs(st.currGAFeats.RT20 - st.tarFeats.(fieldsToMax{i}));
        end  
    end
    fVal = difVec*lsWeights;
elseif strcmp(st.fitMethod,'edr')
%     [eTst,F,T,frameLen,stride,logP,linP,linF] = edr(xTst,st.fs,1);
%     minLen = min(size(eTst,2),size(st.tarFeats.EDR,2));
%     theDif = abs(eTst(:,1:minLen) - st.tarFeats.EDR(:,1:minLen));
%     fVal = sum(sum(theDif))/(size(theDif,1)*size(theDif,2));
    if st.fitWithdB == true
        error('EDR in dB comparison not implemented');
    else
        minLen = min(size(st.currGAFeats.EDR,2),size(st.tarFeats.EDR,2));
        normTstEDR = diag(1./max(st.currGAFeats.EDR,[],2))*st.currGAFeats.EDR(:,1:minLen);
        normTarEDR = diag(1./max(st.tarFeats.EDR,[],2))*st.tarFeats.EDR(:,1:minLen);
        difMat = abs(normTstEDR - normTarEDR);
                fVal = sum(sum(difMat))/numel(difMat);
    end
elseif strcmp(st.fitMethod,'edc')
    if st.fitWithdB == true
        tstEDC = edc_db(xTst,st.minComparedB);
        iTar = find(st.tarFeats.EDC < st.minComparedB,1);
        tarEDC = st.tarFeats.EDC(1:iTar);
        minLen = min(length(tstEDC),length(tarEDC));
        fVal = sum(abs(tstEDC(1:minLen) - st.tarFeats.EDC(1:minLen)))/minLen;
    else
        tstEDC = st.currGAFeats.EDC;
        tarEDC = st.tarFeats.EDC;
        minLen = min(length(tstEDC),length(tarEDC));
        
        if st.fitWithDecExp
            difVec = abs(tstEDC(1:minLen) - tarEDC(1:minLen));
            tau = -minLen/log(st.expWeightAtEnd);
            w = exp((-1/tau)*(1:minLen));
            fVal = (w*difVec)/minLen;
        else
            fVal = sum(abs(tstEDC(1:minLen) - tarEDC(1:minLen)))/minLen;
        end
    end
elseif strcmp(st.fitMethod,'mfcc')
    minLen = min(size(st.currGAFeats.MFCC,2), size(st.tarFeats.MFCC,2));
%     minT = st.tarFeats.IRTime(find(st.tarFeats.EDCdB < st.minComparedB,1));
%     minLen = find(st.tarFeats.FrameTimes > minT,1);
    fVal = 0;
    for i = 1:minLen
        fVal = fVal + norm(st.currGAFeats.MFCC(:,i) - st.tarFeats.MFCC(:,i));
    end
    fVal = fVal/minLen
elseif strcmp(st.fitMethod,'env')
    if st.fitWithdB == true
        maxLen = max(length(st.currGAFeats.envdB),length(st.tarFeats.envdB));
        tstEnv = st.currGAFeats.envdB;
        tarEnv = st.tarFeats.envdB;
        if maxLen > length(tstEnv)
            tstEnv = [st.currGAFeats.envdB; st.currGAFeats.envdB(end)*ones(maxLen-length(st.currGAFeats.envdB),1)];
        else
            tarEnv = [st.tarFeats.envdB; st.tarFeats.envdB(end)*ones(maxLen-length(st.tarFeats.envdB),1)];
        end
    %     plot(tarEnv)
    %     hold on;
    %     plot(tstEnv,'r')
%         plotIRComparison(st.tarFeats,feats,st)
        fVal = sum(abs(tstEnv - tarEnv))
    else
        maxLen = max(length(st.currGAFeats.env),length(st.tarFeats.env));
        tstEnv = st.currGAFeats.env;
        tarEnv = st.tarFeats.env;
        if maxLen > length(tstEnv)
            tstEnv = [st.currGAFeats.env; zeros(maxLen-length(st.currGAFeats.env),1)];
        else
            tarEnv = [st.tarFeats.env; zeros(maxLen-length(st.tarFeats.env),1)];
        end
        if strcmp(st.fitBeginLoc,'early')
            tstEnv = tstEnv(find(st.currGAFeats.EnvTime > (st.earlyIRLen_samps/st.fs),1)-1:end);
            tarEnv = tarEnv(find(st.tarFeats.EnvTime > (st.earlyIRLen_samps/st.fs),1)-1:end);
        elseif strcmp(st.fitBeginLoc,'minM')
            m = st.currGAParams.m;
            minM = min(m);
            tstEnv = tstEnv(find(st.currGAFeats.EnvTime > minM/st.fs,1)-1:end);
            tarEnv = tarEnv(find(st.tarFeats.EnvTime > minM/st.fs,1)-1:end);
        end
        len = length(tstEnv);
        if st.fitWithDecExp
            difVec = abs(tstEnv - tarEnv);
            tau = -len/log(st.expWeightAtEnd);
            w = exp((-1/tau)*(1:len));
            v = w.*difVec';
        else
            v = abs(tstEnv - tarEnv);
        end
        if strcmp(st.fitNormType,'two')
            fVal = sum(v)
        elseif strcmp(st.fitNormType,'inf')
            fVal = max(v)
        end
%         plotIRComparison(st.tarFeats,feats,st)
%         plot(tarEnv)
%         hold on;
%         plot(tstEnv,'r')
    end
end
