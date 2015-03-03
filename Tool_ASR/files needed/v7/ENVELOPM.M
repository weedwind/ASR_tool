       function[Seg_spectrum1]  = envelopm(Seg_spectrum,Freq_kernel_min,Freq_kernel_max,delta_F, Freq_min, Freq_max)

%      This program forms a type of morphological filtering on a
%      vector/matrix of frequency components.   It approximately tracks the envelope
%      of the spectrum using either the original values, if that value is close
%      to the peak,  or a max value,  if the value is not close to a peak
%
%      Programmer:   S. A. Zahorian
%      Creation Date:   March 8, 2000
%      Revision Date:   March 26, 2000, April 10, 2000
%
%      This function should be used prior to log scaling of spectrum
%
%      Inputs
%      Seg_spectrum[,]    =   Matrix of of spectral amplitudes (on log scale)
%                             each column is another frame
%
%       Freq_kernel_min  =  Smoothing window width (Hz) at low end of frequency range
%       Freq_kernel_max  =  Smoothing window width (Hz) at high end of Frequency range
%       delta_F          =  Spacing in Hz between frequency samples
%       N_freq           =  Total number of frequency samples in Seg_spectrum
%
%       Outputs
%       Seg_spectrum1[,]  =  Peak-Smoothed spectrum (over frequency)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
       %  Initialization section--- This part could be done once
  %     slope = (Freq_kernel_max -Freq_kernel_min )/(N_freq);
  %     b     = Freq_kernel_min;
    
%        Freq_kernel_max = fix(Freq_kernel_max/delta_F);
%        Freq_kernel_min = fix(Freq_kernel_min/delta_F);
       N_freq = Freq_max - Freq_min;
       slope = (Freq_kernel_max -Freq_kernel_min )/(N_freq);
       
       
%      slope and b are now set such that when Freq_index = 1,
%      freq_width (in hz) = Freq_kernel_min
%      when Freq_index = N_freq, freq_width = Freq_kernal_max

%      Now slope, b are set up for indices

%       slope = slope/delta_F;
        b     = Freq_kernel_min - Freq_min*slope;
%       b     = Freq_kernel_min;

       % First copy over entire array, with log scaling
      [m,n] = size(Seg_spectrum);
       
      Seg_spectrum1 = zeros(N_freq+1,n);

      for j= Freq_min : Freq_max

            % morphological filtering over frequency
            Freq_width = fix (j*slope + b);
            
            if (Freq_width < 1)
               Freq_width = 1;
            end;
            
            
            Freq_start = fix(Freq_width/2);
            Freq_start1 = max(j-Freq_start+1, 1);
            Freq_end    = Freq_start1+Freq_width-1;

            Max_ampl = max(Seg_spectrum(Freq_start1:Freq_end,:),[],1);

%            /* now Max_ampl is the maximum value in the smoothing window */
%            /*  Use original values if they are close to max */

            delta = 1.0;                    %  threshold value on natural log scale

            temp_1 = Seg_spectrum(j,:);
            temp_2 = Max_ampl;
            temp_0 = max(temp_1, (temp_2-delta));
            
            % now Max_ampl is the maximum value in the smoothing window
            Seg_spectrum1(j-Freq_min+1,:) = temp_0;

           end;           
           Freq_max;
% plot(Seg_spectrum(:,3));
% hold on
% plot(Seg_spectrum1(:,3),'-r');
% pause
% hold off          
