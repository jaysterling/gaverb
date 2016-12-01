
function [y, fdnParams] = doFDNReverbWithGAOutput(vars)
global st;

% create empty variables for everything we need
A = []; b = []; c = []; d = []; m = [];
varInd = 1;
for i = 1:length(st.paramsToGA)
    field = st.paramsToGA{i};
    if strcmp(field.name,'A');
        A = reshape(vars(varInd:varInd+field.np-1),[st.N st.N])';
    elseif strcmp(field.name,'b');
        b = vars(varInd:varInd+field.np-1);
    elseif strcmp(field.name,'c');
        c = vars(varInd:varInd+field.np-1);
    elseif strcmp(field.name,'d');
        d = vars(varInd:varInd+field.np-1);
    elseif strcmp(field.name,'m');
        m = vars(varInd:varInd+field.np-1);
    else
        error('Unrecognized field "%s" in the GA params', field.name);
    end
    % increment our read position from the var list
    varInd = varInd + field.np;
end

% any variables that weren't GA'd need default values
if isempty(A)
    if strcmp(st.defaultA,'had')
        A = (1/sqrt(st.N))*hadamard(st.N);
    elseif strcmp(st.defaultA,'eye')
        A = eye(st.N);
    else
        error('Unknown default feeback matrix type');
    end
end
if isempty(b)
    b = ones(st.N,1);
end
if isempty(c)
    cb = [1; -1];
    c = repmat(cb,st.N/2,1);
end
if isempty(d)
    d = 1.0;
end
if isempty(m)
    error('You should def be using GA for the delay values')
end
gaps = struct('A',A,'b',b,'c',c,'d',d,'m',m);
st.gaps = [st.gaps gaps];

% design the filters given the delay lengths
bqCoeffs = zeros(st.N,5*ceil(st.filtOrd/2));

for i = 1:st.N
    if st.designFiltsFromMel
        [filtb,filta] = designFDNFiltToRT60Curve(st.tarFeats.RT60Bark,st.fs, ...
        st.tarFeats.BarkFreqs, m(i),st.filtOrd);
    else
        [filtb,filta] = designFDNFiltToRT60Curve(st.tarFeats.RT60Lin,st.fs, ...
        st.tarFeats.LinFreqs, m(i),st.filtOrd);
    end
    
%         [H,W] = freqz(filtb,filta,512);
%         plot((st.fs/(2*pi))*W,20*log10(H))
%         hold on
    sos = tf2sos(filtb,filta);
    for s = 1:size(sos,1)
        bqCoeffs(i,1+5*(s-1):5*s) = sos(s,[1 2 3 5 6]);
    end
end
bqToneCoeffs = [];    
tb = [];
ta = 1;
tbFIR = [];
if ~strcmp(st.toneCorrectionMethod,'none')

    if strcmp(st.toneCorrectionMethod,'jot')
        if st.designFiltsFromMel
            [tb,ta] = designToneCorrectionFiltToRT60Curve(st.tarFeats.RT60Bark,st.fs, ...
                st.tarFeats.BarkFreqs,st.tcFiltOrd);
        else
            [tb,ta] = designToneCorrectionFiltToRT60Curve(st.tarFeats.RT60Lin,st.fs, ...
                st.tarFeats.LinFreqs,st.tcFiltOrd);
        end
    elseif strcmp(st.toneCorrectionMethod,'emp') && ~st.empFirstPass
        
        t60 = rt(st.empFirstPassIR,st.fs,st.toneCorrMindB);
        clip = st.empFirstPassIR(min(st.empParams.m):round(t60*st.fs));

        for i=1:length(st.thirdOctFilts)
            empAvgPwrs(i) = mean(filter(st.thirdOctFilts(i),clip).^2);
        end
     
        targetLinCurve = sqrt(st.tarAvgPwrs./empAvgPwrs);
        [F,M] = padMagnitudes(st.fs,st.thirdOctFreqs,targetLinCurve);
        omega = F/(st.fs/2);
        
        tbFIR = fir2(st.tcFiltOrd,omega,M);
        
%         semilogx(st.thirdOctFreqs, 10*log10(st.tarAvgPwrs));
%         hold on;
%         targetdBCurve = 20*(log10(targetLinCurve));
%         semilogx(st.thirdOctFreqs, 10*log10(empAvgPwrs),'r');
%         semilogx(st.thirdOctFreqs, targetdBCurve,'k');
%         [H,W] = freqz(tbFIR,1,512);
%         semilogx((st.fs/(2*pi))*W, 20*log10(abs(H)),'m');
%         axis tight; grid on;
%         legend('Target','Current','Tar Correct','Filter','Location','SouthWest')
    end
    if ~isempty(tb)
        sos = tf2sos(tb,ta);
        bqToneCoeffs = zeros(1,5*ceil(st.tcFiltOrd/2));
        for s = 1:size(sos,1)
            bqToneCoeffs(1,1+5*(s-1):5*s) = sos(s,[1 2 3 5 6]);
        end
    end
end

y = fdnReverbFast(m,bqCoeffs,bqToneCoeffs,tbFIR,st.fs,A,b,c,d,st.earlyIRPath,[], ...
    st.fs*st.maxProcLen_s,4096, st.verboseFDN);

fdnParams = struct('A',A,'b',b,'c',c,'d',d,'m',m,'delFilts_b',filtb,'delFilts_a',filta,...
    'toneFilt_b',tb,'toneFilt_a',ta,'delBQ',bqCoeffs,'toneBQ',bqToneCoeffs, ...
    'toneFIR',tbFIR,'fs',st.fs,'earlyIRPath',st.earlyIRPath);
