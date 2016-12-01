function [b,a] = designFDNFiltToIR(x,fs,m,ord)

[t60f,F] = rtcurve(x,fs,-60,0);
[b,a] = designFDNFiltToRT60Curve(t60f,fs,F,m,ord);