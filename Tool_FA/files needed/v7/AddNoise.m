function Y = AddNoise(X, SNR)
%
% Add white noise to signal X, SNR specified how much noise needed to be added
%
% Inputs:
%         X  - input signal, must be a column matrix
%       SNR  - Signal-to-noise ration in dB of final signal
% Output:
%         Y  - signal after noise has been added
%
% Notes: 
%       This program is coded based on AddNoise.for
%
% Programmer : Montri K.
% Date       : 12/3/99
% Version    : 0.1
%

% step 0: check input arguments
epsilon = .001;  % To limit lower limit on signal power, in  case file is empty
                 % This will prevent numeric issues with variance calculation

if nargin < 2
   disp 'Usage: Y = AddNoise(X, SNR)'
   return
end

if size(X,2) ~= 1
   disp 'AddNoise -> Error: X must be a column matrix!'
   Y = [];
   return
end

% step 1: compute signal power

Signal_power = mean(X.^2) - mean(X)^2;
if Signal_power < epsilon
     Signal_power = epsilon;
end;
VarN         = Signal_power/(10^(SNR/10));
Noise_gain   = sqrt(VarN);

% step 2: generate noise
randn('state', 0);  % reset random number generator so that we will get the same outputs

Noise = randn(size(X,1), 5);                     % generate 5 sequences
Noise = Noise_gain * sum(Noise,2)/sqrt(5);       % sum them up and scale them properly

% step 3: add noise to signal
Y = X + Noise;

% step 4: checking (debugging)

%Noise_power = mean(Noise.^2) - mean(Noise)^2;
%NewSNR = 10*log10(Signal_power/Noise_power);

%Signal_power
%Noise_power
%NewSNR
%figure(1)
%specgram(X)
%figure(2)
%specgram(Y)
%soundsc(Y,16000)


