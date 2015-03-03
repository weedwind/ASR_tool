function SPEC = computeSpectrum (s,Frame_length,fftLength,winShift)

% compute spectrum from time signal

% Returns power spectrum (|X(f)|^2) in
% matrix SPEC.X(coefficientIndex,frameIndex) .

% The signal energy (sum of power spectrum coefficients)
% is returned in vector SPEC.e(frameIndex)

% local variables
nofSamples = size(s);
maxFFTIdx = fftLength/2;
% hamming window
win = hamming(Frame_length);

NumFrm = 1 + fix((nofSamples - Frame_length)/winShift);

k = 1;
for m = 1:winShift:1+winShift*(NumFrm-1)
    Frame_data=s(m:m+Frame_length-1);
    spec = fft( win.*Frame_data ,fftLength);
    %use only lower half of fft coefficients
    SPEC.X(:,k) = ( abs( spec(1:maxFFTIdx) ) ).^2;    
    %compute energy
    SPEC.e(k) = sum(Frame_data.*Frame_data);
    k = k+1;
    
end 