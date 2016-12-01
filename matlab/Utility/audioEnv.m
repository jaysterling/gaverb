function y=audioEnv(x,alpha_att,alpha_dec)

xabs = abs(x);
% xabs = xabs.^2;
y = zeros(size(x));
y(1) = alpha_att*xabs(1);
for i = 2:length(x)
    if xabs(i) > y(i-1)
        y(i) = alpha_att*xabs(i) + (1-alpha_att)*y(i-1);
    else
        y(i) = alpha_dec*xabs(i) + (1-alpha_dec)*y(i-1);
    end
end