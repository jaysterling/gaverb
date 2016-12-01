function f = getmirfield(obj,name)
ca = get(obj,name);
f = squeeze(squeeze(ca{1}{1}));