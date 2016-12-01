
% x is a dim x N matrix where N is the number of points and dim is the
% dimensionality of each point. This function returns the k-indices of the
% points (column of x) which minimizes the total distance between all
% points
function fars = largestSpread(x,k)

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

% over each combination
for c = 1:size(C,1)
    theSet = x(:,C(c,:));
    for d = 1:size(theSet,1)
        dif = max(theSet(d,:)) - min(theSet(d,:));
        Dt(c) = Dt(c) + dif;
    end
end

[~,I] = max(Dt);
fars = C(I,:);
