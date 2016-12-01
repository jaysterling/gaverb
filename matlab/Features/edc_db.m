function y_db = edc_db(h,min_db)
if nargin<2
    min_db = -100;
end
y = edc(h);
y_db = 10*log10(y/y(1));
ind = find(y_db < min_db,1);
if ~isempty(ind)
    y_db = y_db(1:ind);
end