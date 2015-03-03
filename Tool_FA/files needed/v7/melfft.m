function [mel1,energy] = melfft(x,fs,nofChannels,nsamples,Frame_length,Low_freq,High_freq, N)
%parameters
if nargin<2
    fs = 16000;
end
if nargin<3
    nofChannels = 26;
end
if nargin<4
    nsamples = 32;
end

if nargin<6
    Low_freq=60;
end

if nargin<7
    High_freq=7200;
end

if (nargin<8)||(N<Frame_length)
   fftbase = log(Frame_length)/log(2);
   N = 2^fix(fftbase+1); % fft length
end
%-----------------------------------------
% N = 512; %FFT Window length
% nofChannels = 64; %number of mel channels
% nsamples = 32; %window shift
%-----------------------------------------
[W1 melcenters]= melFilterMatrix(fs, N, nofChannels, Low_freq, High_freq);
%%  triangular filterbank
% figure(1)
% plot(linspace(0, (fs/2),N/2),W1');
% title('mel filterbank');
% xlabel('frequencies');
% ylabel('amplitude');
%% mel spectrum calculation
[mel] = melspectrum (W1,x,Frame_length, nsamples);
% figure(2)
% [nrow ncol] = size(mel.m);
mel1 =(mel.m);
energy=mel.e;
% imagesc(20*log10(mel));
% title('mel spectrogrma');
% xlabel('time(frames)');
% ylabel('number of channels');
% axis xy;