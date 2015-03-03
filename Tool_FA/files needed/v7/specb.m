function [Spec,uni_frame_lengths,frame_lengths]  = specb(Data, fft_length, delta,...
   frame_length, frame_length2,init,uni_frame_lengths,frame_lengths)

% SPECB Calculates spectrum with variable frame lengths
%
% INPUTS:
%   Data      : A data frame
%   fft_length: FFT length
%   delta     : A warping function over full frequency range for
%               variable frame lengths
%
% Outputs:
%   Spec      : Spectrum

%   Creation date:  07/19/2008
%   Revisin date:   12/09/2008  by SAZ
%   Programmer   :  Hongbing Hu



if (init == 0)    %  initialization phase


step_size =     10;

% Check some inputs
if (size(delta) ~= fft_length) 
    error('Delta is not full frequency range'); 
end

% Use the length of the input frame as the max frame length
frame_length_max = frame_length;
frame_length_min = frame_length2;



% Quantize frame lengths over full frequency range based on delta

frame_lengths = floor(frame_length_max * delta/step_size)*step_size;

%    Insure that frame_length is never less than frame_length_min
%    First check to see what minimum frame length is based on delta


if (min (frame_lengths) < frame_length_min)

%    rescale delta so that min delta is not "too" small

     delta_min = frame_length_min/(frame_length_max);
     bb = ((delta_min/(min(delta))) - 1)/(fft_length/2+1);
     for i = 1:(fft_length/2 + 1)
        delta(i) = delta(i)*(1 + bb*(i-1));
     end;

     delta = delta/(max(delta));

     delta(fft_length/2 +2:fft_length) = delta(fft_length/2 +1);

frame_lengths =floor( floor(frame_length_max * delta/step_size)*step_size);

end



% Get unique frame lengths 
uni_frame_lengths = unique(frame_lengths);


%uni_frame_lengths = uni_frame_lengths(fix(end/2));
%figure(1);
%hold on;

Spec = zeros(fft_length, 1);

end;   %  end of initialization phase

if (init == 1);    % processing phase

Spec = zeros(fft_length, 1);
frame_length_max = frame_length;


for n=1:length(uni_frame_lengths)

    % Start FFT from long frame length 
    frame_length = uni_frame_lengths(end-n+1);

    freq_comps = (frame_lengths == frame_length);
    %freq_comps = (frame_lengths ~= 0);
    
    % Create data frame based on new frame length
    head = floor((frame_length_max - frame_length)/2)+1;
    nData = Data(head:head+frame_length-1);
    
    if ~isempty(nData)
        % perform FFT
        tSpec = fft(nData, fft_length); 

    % Fill frequency components that have the same frame length  
        Spec(freq_comps) = tSpec(freq_comps);  
        %plot([1:length(Spec)], abs(Spec));
    
        % A simple plot for frequency component distribution over frame length
       % hold on, plot([0:fft_length-1].*freq_comps, frame_length, 'b-');
    end
end
end     %  end of initialization phase

%hold off;
%pause;


