
function y = fdnReverb(delays, filtB,filtA,tcB,tcA,tcFIR,fs, m, b, c, d,input )

maxProcSamps = 4*fs;

%% initial checks

if size(m,1) ~= size(m,2)
    error('Coeff matrix must be square');
end
dim = length(m);

if ~isvector(delays)
    error('Delay lengths must be a vector');
end
if length(delays) ~= dim
    error('Delay lengths must match dims with coeff matrix');
end
if ~isvector(b)
    error('B vector must be a vector');
end
if length(b) ~= dim
    error('B vector width must match dim of coeff matrix');
end
if ~isvector(c)
    error('C vector must be a vector');
end
if length(c) ~= dim
    error('C vector width must match dim of coeff matrix');
end
if ~isempty(filtB) && ~isempty(filtA)
    if size(filtB) ~= size(filtA)
        error('Filter A and B must have same dims');
    end
    if size(filtB,1) ~= dim
        error('Filter A and Bs must have row count equal to the dim');
    end
end
if ~isscalar(d)
    error('D must be a scalar');
end

%% rms stuff
alpha = 0.01;
maxRMS = 0;
rms_z1 = 0;

%% bq coeff calc

if ~isempty(filtB)
    xz = zeros(dim,size(filtB,2)-1);
    yz = zeros(size(xz));
    filtA(:,1) = [];
end
if ~isempty(tcB)
    tcxz = zeros(1,size(tcB,2)-1);
    tcyz = zeros(size(tcxz));
    tcA(:,1) = [];
end

%% process loop

dLine = zeros(dim,ceil(max(delays)) + 2);
delays = delays + 1;
matIn = zeros(dim,1);   % input to the matrix multiply, post EQ 
y = zeros(maxProcSamps,1);

if nargin < 12 || isempty(input)
    x = zeros(maxProcSamps,1);
    x(1) = 1;
else
    x = zeros(max(maxProcSamps,length(input)),1);
    x(1:length(input),1) = input;
end

for s = 1:maxProcSamps
    
    if ~isempty(filtB)
        % process the delay line outputs through their LP filters
        for n = 1:dim
            frac = delays(n) - floor(delays(n));
            dOut = dLine(n,floor(delays(n)))*(1-frac) + frac*dLine(n,floor(delays(n))+1);
            xIn = [dOut xz(n,:)];
            matIn(n) = filtB(n,:)*xIn' - filtA(n,:)*yz(n,:)';
            xz(n,:) = [xIn(1) xz(n,1:end-1)];
            yz(n,:) = [matIn(n) yz(n,1:end-1)];
        end
    else
        for n = 1:dim
            matIn(n) = dLine(n,delays(n));
        end
    end
    
    % append the new output value
    tcIn = c*matIn;
    if ~isempty(tcB)
        tcxIn = [tcIn tcxz];
        tcOut = tcB*tcxIn' - tcA*tcyz';
        y(s) = tcOut;
        tcxz = [tcIn tcxz(1:end-1)];
        tcyz = [tcOut tcyz(1:end-1)];
    else
        y(s) = tcIn;
    end
    
    % calc the rms to know when to bail
%     rms = alpha*abs(y(s)) + (1-alpha)*rms_z1;
%     maxRMS = max(rms,maxRMS);
%     if rms < rms_z1 && rms < 0.0001*maxRMS && s >= 4096
%         y = y(1:s);
%         break;
%     end
%     rms_z1 = rms;
    
    % now matrix multiply and get teh delay line inputs
    dIn = x(s)*b + m*matIn;
    
    % shift all dLine elements one to the right and fill in new vals on
    % left
    dLine = circshift(dLine,[0 1]);
    dLine(:,1) = dIn;
end

if ~isempty(tcFIR)
    y = filter(tcFIR,1,y);
end
y = y + d*x;


