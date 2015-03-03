function mel = melspectrum (W,s,Frame_length, winShift)

% Returns mel spectral coefficients in
% matrix MEL.M(coefficientIndex,frameIndex).

% Signal energy 
% is copied from SPEC.e
% ('computeSpectrum') to vector MEL.e(frameIndex).
%
% parameters:
% W: matrix(channelIndex,FFTIndex) of mel filter coefficients 
% winShift: window shift [number of samples]
% s: vector of time samples

% local variables
[nofChannels,maxFFTIdx] = size(W);
fftLength = maxFFTIdx * 2;


SPEC = computeSpectrum(s,Frame_length,fftLength,winShift);

% mel filter to spectra
mel.m = W * SPEC.X;

%energy vector
mel.e = SPEC.e ;