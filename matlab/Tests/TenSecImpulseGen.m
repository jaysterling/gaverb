fs = 44100;
x = zeros(10*fs,1);
x(1) = 1.0;
wavwrite(x,fs,16, '10secondImpulse');