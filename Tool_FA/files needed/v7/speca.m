function [Frame_FFTmag] = speca(Frame_dataW,Sample_rate,FFT_length,Bias_value)

% speca computes spectrum of a single frame,   using either autocorrelation
% or cross correlation smoothing

% INputs
% Frame_dataW---  > is the acoustic speech signal samples

% Sample_rate = input sample rate in Hz;   Note sampling rate effectively

% Outputs
% LogEnergy_Frame_data = 
% Frame_FFT_mag  =  Magnitude spectrum from 1 to FFT_length/2

eps = .01;


% to compute auto-correlation
auto_corr=XCORR(Frame_dataW,length(Frame_dataW));

% to compute normalized-cross correlation
   N_smooth = 250;


lag_min0 = 1;
%N_range = round(length(Frame_dataW)/2); % the size of block to be used for nccf

N_range = length(Frame_dataW)-N_smooth;

lag_max0 = N_smooth;

% length(Frame_dataW)-N_range+1;

clip_ratio = 0.0; % center clipping ratio only signal
                  %above the clip ratio of max signal value used
win_flg = 0;

[phi] = crs_corr(Frame_dataW, length(Frame_dataW), lag_min0,lag_max0,N_range,clip_ratio,win_flg); % to compute normalized cross_corr.


%   we now have autocorrelation and normalized cross correlation

   auto_corr=auto_corr(round(length(auto_corr)/2):length(auto_corr));

%  determine the max of the various signals, so that autocorr  and cross
%  can be normalized to same range as original signal


   max_speech = max(Frame_dataW);
   max_auto   = max(auto_corr);
   max_cross  = max(phi);

   if (max_auto < eps)
      max_auto = eps;
   end;
   if (max_cross < eps)
      max_cross = eps;
   end;


%   Restore the  amplitudes

   auto_corr =  auto_corr *(max_speech/max_auto);
   phi       =  phi*(max_speech/max_cross);

   N_F_max = round (.40*(FFT_length/2));  % max spectral component for plotting
   f_max   = round (.40*Sample_rate/2);

   f_scale= [1:N_F_max];
   f_scale = f_scale *(f_max/N_F_max);



%   Create the arrays for partial autocorrelation

    auto_corr1 = zeros(1,FFT_length);
    auto_corr1(1:N_smooth)= auto_corr(1:N_smooth);

%     for i = 1:(N_smooth-1)
%       auto_corr1(FFT_length-N_smooth+1 + i) =...
%                     auto_corr(N_smooth +1 - i);
%     end;


    phi1 = zeros(1,FFT_length);
    phi1(1:N_smooth)= phi(1:N_smooth);

%     for i = 1:(N_smooth-1)
%       phi1(FFT_length-N_smooth+1 + i) =...
%                     phi(N_smooth +1 - i);
%     end;


   
   fft_speech_signal=fft(Frame_dataW,FFT_length); % spectrum based on the speech signal of length equal to frame_length defined in setup files.

%   mag_fft_speech = (abs(fft_speech_signal(1:FFT_length/2))).^2;
   mag_fft_speech = (abs(fft_speech_signal(1:FFT_length/2)));


   log_mag_fft_speech = 20.0*log(mag_fft_speech + Bias_value);

   fft_auto_signal=fft(auto_corr1,FFT_length); % spectrum based on auto_corr
   mag_fft_auto=abs(fft_auto_signal(1:FFT_length/2));
   log_mag_fft_auto = 20.0*log(mag_fft_auto + Bias_value);
   
   fft_cross_signal=fft(phi1,FFT_length); % spectrum based on cross-corr
   mag_fft_cross=abs(fft_cross_signal(1:FFT_length/2));


   log_mag_fft_cross = 20.0*log(mag_fft_cross + Bias_value);



   % plots of the spectrum computed from speech, auto-corr and cross-corr
%   figure(2);
%   plot(f_scale,log_mag_fft_speech(1:N_F_max));
%   axis([1 f_max 40 280]);
%   hold on;
%   plot(f_scale,log_mag_fft_auto(1:N_F_max),'r');
%   plot(f_scale,log_mag_fft_cross(1:N_F_max),'k');
%   hold off;
%   title('acoustic spectrum in blue, auto-correlation spec in red and cross-corr spec in black');
%   pause;


%   Frame_FFTmag = mag_fft_speech;
    Frame_FFTmag = mag_fft_cross';   % Why is transpose needed??


   return

