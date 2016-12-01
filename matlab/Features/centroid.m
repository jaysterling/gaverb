
function C = centroid(X,F)
C = zeros(1,size(X,2));
for i = 1:size(X,2)
    C(i) = F'*(X(:,i).^2)/sum(X(:,i).^2);
end
