function [W1, melcenters] = melFilterMatrix(fs, N, nofChannels, Low_freq, High_freq, Freq_min, Freq_max)
% --------------------------------------------
% melFilterMatrix(fs, N, nofChannels):
% compute mel filter coefficients
% 
% returns: Matrix (channelIndex, FFTIndex) 
% of mel filter coefficients.
% 
% parameters:
% N: FFT length

%compute resolution 
df = fs/N; %frequency resolution
Nmax = N/2+1; %Nyquist frequency index
if High_freq>fs/2
    High_freq=fs/2;
    warning(sprintf('High frequency too high, forced to Fs/2=%f',fs/2));
end

        
melmax = freq2mel(High_freq); %maximum mel frequency


melmin = freq2mel(Low_freq); %minimum mel frequency

%mel frequency increment 
melinc = (melmax-melmin) / (nofChannels + 1); 

%vector of center frequencies on mel scale
melcenters = (1:nofChannels) .* melinc+melmin;

%vector of center frequencies [Hz]
fcenters = mel2freq(melcenters);

%quantize into FFT indices
indexcenter = round(fcenters ./df)+1;


indexstart = [Freq_min , indexcenter(1:nofChannels-1)];
indexstop = [indexcenter(2:nofChannels),Freq_max];

%triangle-shaped filter coefficients
W = zeros(nofChannels,Nmax);
for c = 1:nofChannels
    %left ramp
    increment = 1.0/(indexcenter(c) - indexstart(c));
    for i = indexstart(c):indexcenter(c)
        W(c,i) = (i - indexstart(c))*increment;
    end 
    %right ramp
    decrement = 1.0/(indexstop(c) - indexcenter(c));
    for i = indexcenter(c):indexstop(c)
       W(c,i) = 1.0 - ((i - indexcenter(c))*decrement);
    end
end 

%normalize melfilter matrix
for j = 1:nofChannels
    W1(j,:) = W(j,:)/ sum(W(j,:)) ;
end