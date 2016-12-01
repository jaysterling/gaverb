function [state,options,optchanged] = gaPerGenFunc(options,state,flag)
optchanged = 0;
global st;

if false == strcmp(flag,'done')
    tempEnv = st.currBestGAFeats.env;

    if ~isempty(st.genvelopes)
        d = length(tempEnv) - size(st.genvelopes,1);
        if(d > 0)
            st.genvelopes = [st.genvelopes; zeros(d,size(st.genvelopes,2))];
        elseif(d < 0)
            tempEnv = [tempEnv; zeros(-1*d,1)];
        end
    end

    st.genvelopes = [st.genvelopes tempEnv];
    st.generations = [st.generations state.Generation+1]; % matlab calls first gen = 0. Let's use 1
end
    