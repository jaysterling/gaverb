function y = rectify(x)

y = zeros(size(x,1), size(x,2));
for i = 1:size(x,1)
   for k = 1:size(x,2)
      if x(i,k) < 0.0
          y(i,k) = x(i,k)*-1.0;
      else
          y(i,k) = x(i,k);
      end
   end
end