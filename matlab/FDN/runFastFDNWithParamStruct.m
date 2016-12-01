function y = runFastFDNWithParamStruct(p)

y = fdnReverbFast(p.m, p.delBQ, p.toneBQ,p.toneFIR, p.fs, p.A, p.b, p.c, p.d,p.earlyIRPath,[], ...
    p.fs*10, 4096, false);