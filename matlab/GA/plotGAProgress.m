function state = plotGAProgress(options,state,~)

global st;

% plotIRComparison(st.tarFeats,st.currBestGAFeats, st)

tempEnv = st.currBestGAFeats.env;

if ~isempty(st.genvelopes)
    d = length(tempEnv - size(st.genvelopes,1));
    if(d > 0)
        st.genvelopes = [st.genvelopes; zeros(d,size(st.genvelopes,2))];
    elseif(d < 0)
        tempEnv = [tempEnv; zeros(d,1)];
    end
end

st.genvelopes = [st.genvelopes tempEnv];

st.generation = st.generation + gaoptimget(options,'PlotInterval');