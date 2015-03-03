function [W, centers]=genfw(Spec_method,Sample_rate,FFT_length,Num_channels,Low_freq,High_freq, Freq_min, Freq_max, WIDTH )
if strcmp(upper(Spec_method),'MEL')        % this is the mel filterbank weights
    [W, centers]= melFilterMatrix(Sample_rate, FFT_length , Num_channels, Low_freq, High_freq, Freq_min, Freq_max);
else
    if strcmp(upper(Spec_method),'GAMMA')    % this is the gammatone filterbank weights
        [W,centers] = fft2gammatonemx(FFT_length, Sample_rate, Num_channels, WIDTH, Low_freq, High_freq, FFT_length/2+1);
    else
        if strcmp(upper(Spec_method),'FFT')   % this is the FFT weight, just a selection matrix
            W=eye(Freq_max-Freq_min+1);
            W_left=zeros(Freq_max-Freq_min+1,Freq_min-1);
            W_right=zeros(Freq_max-Freq_min+1,FFT_length/2+1-Freq_max);
            W=[W_left,W,W_right];
            centers=Sample_rate/FFT_length*[Freq_min-1:Freq_max-1];
        end
    end
end
end
        