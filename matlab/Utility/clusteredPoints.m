
% x is a dim x N matrix where N is the number of points and dim is the
% dimensionality of each point. This function returns the k-indices of the
% points (column of x) which minimizes the total distance between all
% points
function nears = clusteredPoints(x,k, minOrMax)

N = size(x,2);
% distance matrix, lower triangular
d = zeros(N);
for i = 2:N
    for j = 1:i-1
        d(i,j) = norm(x(:,i)-x(:,j));
    end
end

% make all the combinations of k points in 1:N
C = combnk(1:N,k);

% total distance column vector, one entry per combination
Dt = zeros(size(C,1),1);

if strcmp(minOrMax,'min')
    % over each combination
    for c = 1:size(C,1)
        % over each index in this combination
        for ind = 1:k-1
            xi = C(c,ind);
            % and now over every higher index in the comb
            for oind = ind+1:k
                xoi = C(c,oind);
                % d matrix is symetric but only lower triangle filled in
                if xi > xoi
                    Dt(c) = Dt(c) + d(xi,xoi);
                else
                    Dt(c) = Dt(c) + d(xoi,xi);
                end
            end
        end
    end
    [Y,I] = min(Dt);
elseif strcmp(minOrMax,'max')
    % over each combination
    for c = 1:size(C,1)
        % over each index in this combination
        for ind = 1:k-1
            xi = C(c,ind);
            % and now over every higher index in the comb
            for oind = ind+1:k
                xoi = C(c,oind);
                % d matrix is symetric but only lower triangle filled in
                if xi > xoi
                    Dt(c) = min(Dt(c),d(xi,xoi));
                else
                    Dt(c) = min(Dt(c),d(xoi,xi));
                end
            end
        end
    end
    [Y,I] = max(Dt);
else
    error('Must specify whether to minimize or maximize dist');
end
    
nears = C(I,:);
