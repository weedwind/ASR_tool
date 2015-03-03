% Sample rate
Fs = 16000;
% Sin wave setting, one row [Freq, start time, end time] for one sin wave.
% both start and end time are in seconds
Sins = [500, 0, 1;
         1000, 1, 2;
        2000, 2, 3
        3000, 3, 4];

tones = zeros(1, max(Sins(:,3)*Fs)+1);

for n=1: size(Sins, 1)
    N = [0:(Sins(n,3)-Sins(n,2))*Fs];

    tone = sin(2*pi*Sins(n,1)*N/Fs);

    head = floor(Sins(n,2)*Fs)+1;
    tail = head+length(tone)-1;

    tones(head:tail) = tones(head:tail) + tone;
end

scl_fct = 1.2* max(tones);
tones= tones/scl_fct;


specgram(tones, [], Fs);
wavwrite(tones, Fs, 'Sins.wav');

