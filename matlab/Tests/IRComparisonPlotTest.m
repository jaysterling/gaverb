close all;

fs = 44100;
mindB = -90;
f1 = 'Samp_3 Rooms 10 Large Wooden Room  M-to-S.wav';
% f2 = 'gaOutputIR.wav';
f2 = 'IMR1_Five Columns.wav';
feats1 = extractMIRFeatures(f1,mindB,fs);
feats2 = extractMIRFeatures(f2,mindB,fs);

plotIRComparison(feats1,feats2)