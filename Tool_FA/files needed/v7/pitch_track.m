function[Pitch_final, numframes, frmspace] = pitch_track (Data, Fs, VU, ExtrPrm, fig, Method)

% pitch_track Fundamental Frequency (Pitch) tracking
%
% [Pitch, numframes, frmspace] = pitch_track Data, Fs, VU, ExtrPrm, fig, Method)
%   , the function is to check input parameters and invoke a number of associated routines 
%   for the YAAPT pitch tracking.
%
% INPUTS: 
%   Data:       Input speech raw data
%   Fs:         Sampling rate of the input data
%   VU:         Whether to use voiced/unvoiced decision with 1 for True and 0 for 
%               False.The default is 1.
%   ExtrPrm:    Extra parameters in a struct type for performance control.
%               See available parameters defined in yaapt.m 
%               e.g., 
%               ExtrPrm.f0_min = 60;         % Change minimum search F0 to 60Hz 
%               ExtrmPrm.fft_length = 8192;  % Change FFT length to 8192
%   fig:        Whether to plot pitch tracks, spectrum, engergy, etc. The parameter
%               is 1 for True and 0 for False. The default is 0.   
%
%   Method:  alllows three options   1 for YAAPT,  2 for   YIN, 3 for PRAAT
% OUTPUTS:
%   Pitch:      Final pitch track in Hz. Unvoiced frames are assigned to 0s.
%   numframes:    Total number of calculated frames, or the length of
%               output pitch track
%   frmspace:    Frame rate of output pitch track in ms

%  Creation Date:  June 2000
%  Revision date:  Jan 2, 2002 , Jan 13, 2002 Feb 19, 2002, Mar 3, 2002
%                  June 11, 2002, Jun 30, 2006, July 27, 2007
%                  May 20, 2012: Add the VU parameter for whether to use
%                  voiced/unvoiced decision. 
%  Authors:        Hongbing Hu, Stephen A.Zahorian

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     This file is a part of the YAAPT program, designed for a fundamental 
%   frequency tracking algorithm that is extermely robust for both high quality 
%   and telephone speech.  
%     The YAAPT program was created by the Speech Communication Laboratory of
%   the state university of New York at Binghamton. The program is available 
%   at http://www.ws.binghamton.edu/zahorian as free software. Further 
%   information about the program can be found at "A spectral/temporal 
%   method for robust fundamental frequency tracking," J.Acosut.Soc.Am. 123(6), 
%   June 2008.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%-- PARAMETERS ----------------------------------------------------------------
% Preliminary input arguments check
if nargin<2
    error('No enough input arguments');
end

% Default values for the tracking with voiced/unvoiced decision
Prm = struct(...
    'frame_length',   30, ... % Length of each analysis frame (ms)
    'frame_space',    10, ... % Spacing between analysis frame (ms)
    'f0_min',         60, ... % Minimum F0 searched (Hz)
    'f0_max',        400, ... % Maximum F0 searached (Hz)
    'fft_length',   8192, ... % FFT length
    'bp_forder',     150, ... % Order of bandpass filter
    'bp_low',         50, ... % Low frequency of filter passband (Hz)
    'bp_high',      1500, ... % High frequency of filter passband (Hz)
    'nlfer_thresh1',0.75, ... % NLFER boundary for voiced/unvoiced decisions
    'nlfer_thresh2', 0.1, ... % Threshold for NLFER definitely unvocied
    'shc_numharms',    3, ... % Number of harmonics in SHC calculation
    'shc_window',     40, ... % SHC window length (Hz)
    'shc_maxpeaks',    4, ... % Maximum number of SHC peaks to be found
    'shc_pwidth',     50, ... % Window width in SHC peak picking (Hz)
    'shc_thresh1',   5.0, ... % Threshold 1 for SHC peak picking
    'shc_thresh2',  1.25, ... % Threshold 2 for SHC peak picking
    'f0_double',     150, ... % F0 doubling decision threshold (Hz)
    'f0_half',       150, ... % F0 halving decision threshold (Hz)
    'dp5_k1',         11, ... % Weight used in dynaimc program
    'dec_factor',      1, ... % Factor for signal resampling
    'nccf_thresh1', 0.25, ... % Threshold for considering a peak in NCCF
    'nccf_thresh2',  0.9, ... % Threshold for terminating serach in NCCF
    'nccf_maxcands',   3, ... % Maximum number of candidates found
    'nccf_pwidth',     5, ... % Window width in NCCF peak picking
    'merit_boost',  0.20, ... % Boost merit
    'merit_pivot',  0.99, ... % Merit assigned to unvoiced candidates in
                          ... % defintely unvoiced frames
    'merit_extra',   0.4, ... % Merit assigned to extra candidates
                          ... % in reducing F0 doubling/halving errors
    'median_value',    7, ... % Order of medial filter
    'dp_w1',        0.15, ... % DP weight factor for V-V transitions
    'dp_w2',         0.5, ... % DP weight factor for V-UV or UV-V transitions
    'dp_w3',         0.1, ... % DP weight factor of UV-UV transitions
    'dp_w4',         0.9, ... % Weight factor for local costs
    'end', -1);




  
  


    switch (Method )
     case 'YAAPT'       % YAAPT
      % YAAPT Pitch tracking routine
 %     message('PT:det', 'Use YAAPT');
      [Pitch_final, numframes, frmspace] = yaapt(Data, Fs, VU);
                                               
     case  'YIN'      %  YIN
      % Pitch tracking with YIN algorithm
      % set the same parameters with ptch_tls, but cann't
      % guranttee these parameters are the best for yin  
 %     message('PT:det', 'Use YIN');
      P.sr = Fs;
      P.minf0 = Prm.f0_min; 
      P.maxf0 = Prm.f0_max; 
      P.hop   = Prm.frame_space*(Fs/1000); 
      P.wsize   = Prm.frame_length*(Fs/1000); 
      %P.wsize   = Prm.frame_length/2*(Fs/1000); 
%      addpath('./YIN/');
      [Pitch_final, numframes, R] = yin(Data, Fs, P);
      frmspace = Prm.frame_space;
     case   'PRAAT'   % 'PRAAT':
      
      % Praat pitch tracker
      % Option: Save noise added speech
 %     message('PT:det', 'Use PRAAT');
      tmpin = '.tmpin.wav';
      tmpout = '.tmpout.pitch';
      
      Data1 =  .99*Data/(max(abs(Data)));    %  Needed to prevent overload/clipping
      wavwrite(Data1, Fs, tmpin);

      % For tracking with U/V decisions, use the following settings in pitch.praat
	% # Autocorrealtion Method, Optimized for Intonation 
	% # Best setting for all voiced tracking 
	% To Pitch (ac)...  0.01 60 10 no  0.00 0.00 0.01 0.35 0.14 400
      % For tracking with all frames voiced, use the following settings in pitch.praat
	% # CrossCorrealtion Method, Optimized for Voice Analysis 
	% # Best setting for voiced/unvoiced tracking 
	% #To Pitch (cc)...  0.01 75 10 no  0.03 0.45 0.01 0.35 0.14 600
      system(sprintf('praatcon pitch.praat %s %s', tmpin, tmpout));
      [Pitch_final, numframes] = readPraat(tmpout);
      system(sprintf('del %s %s', tmpin, tmpout));
      frmspace = Prm.frame_space;
     otherwise
      error('Unknown specified tracking algorithm: %s', Method);
    end
   