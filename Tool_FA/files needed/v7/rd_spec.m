function [Params, Use_term, LogEnergy,Params_char] = rd_spec(FileName, InitPars )

% function [Params, Use_term] = rd_spec(FileName, InitPars, InitFloats)
%
%  Inputs:
%    FileName    = name of command file to read (default "CP_FEA13.INI")
%    InitPars(1) = Sample_rate -- sampling frequency of audio data in Hz
%                  0: use sampling rate specified in specification file
%                  n: set sampling rate to n, disregard what specified in spec. file
%    InitPars(2) = Segment_length -- length of each processing segment in sample
%    


% if no input argument, use default
if nargin ~= 2
   disp 'rd_spec.m -> Usage: [Params, Use_term, LogEnergy, Params_char] = rd_spec(FileName, InitPars)'
   Params = [];
   Use_term = [];
   LogEnergy= [];
   Params_char= [];
   return
end

fid = fopen(FileName,'rt'); % use text attribute to avoid EOF char
if (fid == -1)
   disp ([sprintf('rd_spec.m -> Error: cannot open setup file %s!\n', FileName)]);
   return;
end

% some constants
MAXDCTC       = 35;
MAXDCS        = 15;

% initialize with default values
Sample_rate         = InitPars(1);
Segment_length      = InitPars(2);
Prefilt_Center_Freq = 0;
Frame_length          = 25;
Frame_space         = 10;
FFT_length          = 512;
Kaiser_window_beta  = 6;
Numb_dctcs            = 10;
Static_Warp_factor = 0.45;
BVF_norm_flag       = 0;
Low_freq_limit            = 60;
High_freq_limit           = 7200;
Spectral_range      = 60;
Log_Energy_Flag     = 0;
Log_Expand_Flag     = 0;
ENERGYFLOOR_LogE    = -50;
All_part_voice_yappt= 0;

Block_length_beg = 3;
Block_jump       = 1;

Numb_dyn_terms        = 3;
Time_warp_factor = 10;
BVT_norm_flag   = 0;

plot_spec       = 0;
Pitch_Flag      =   0; 
Numb_filters    = 16;
Width_gammatone  = 1.0;
shift_deg_NonSym = 0.5;
Delta_window_length =      2;
Accelator_window_length =   2;
Delta3_window_length =      2;


Amplitude_scaling = 'LOG';
DCTC_type = 'FFT';
Static_warp_type = 'NONE';
Dyn_Type = 'DELTA';
Time_warp_type = 'KAISER';
Tracker_type ='NONE';
Pitch_Normalization='NONE';


% Start reading command file

% check file ID first
id  = strtok(upper(fgetl(fid)));
idname = strtok(upper(fgetl(fid)));

if ~strcmp(id,'ID') || ~strcmp(idname,'FEATURECOMPUTATION_SPECFILE[CP_FEA1300]')
   disp ([sprintf('rd_spec.m -> Error: invalid file ID\n')]);
   fclose(fid);
   return;
end

while feof(fid) ~= 1 
   s = upper(fgetl(fid));
   [varname, s] = strtok(s);
   if  (length(varname) > 1) && (~strcmp(varname(1:2),'//'))   
      % check for length > 1 instead of using isempty to avoid 
      % the Eof char in case of QEdit was used to edit the command file
     
      value = strtok(s);
      % now find what variable it is
      switch (varname)
         
      case 'SAMPLE_RATE:'
         if Sample_rate == 0   % special case
            Sample_rate = str2num(value);
         end
      case 'FRAME_LENGTH:'
         Frame_length          = str2num(value);
      case 'FRAME_SPACE:'
         Frame_space         = str2num(value);
      case 'FFT_LENGTH:'
         FFT_length          = str2num(value);
      case 'KAISER_WINDOW_BETA:'
         Kaiser_window_beta  = str2num(value);
      case 'PREFILT_CENTER_FREQ:'
            Prefilt_Center_Freq = str2num(value);
      case 'SPECTRAL_RANGE:'
         Spectral_range  = str2num(value);             
      case 'LOW_FREQ_LIMIT:'
         Low_freq_limit  = str2num(value);      
      case 'HIGH_FREQ_LIMIT:'
         High_freq_limit  = str2num(value);           
      case 'AMPLITUDE_SCALING:'
           Amplitude_scaling=value;   
      case 'DCTC_TYPE:'
         DCTC_type  = value;      
      case 'NUMB_FILTERS:'
         Numb_filters = str2num(value);      
      case 'PLOT_SPEC:'
         plot_spec = str2num(value);      
      case 'SHIFT_DEG_NONSYM:'
         shift_deg_NonSym  = str2num(value);      
      case 'LOG_ENERGY_FLAG:'
         Log_Energy_Flag  = str2num(value);      
      case 'LOG_EXPAND_FLAG:'
         Log_Expand_Flag  = str2num(value);      
      case 'WIDTH_GAMMATONE:'
         Width_gammatone  = str2num(value);      
      case 'NUMB_DCTCS:'
         Numb_dctcs  = str2num(value);      
      case 'STATIC_WARP_TYPE:'
         Static_warp_type  = value;      
      case 'STATIC_WARP_FACTOR:'
         Static_Warp_factor  = str2num(value);           
      case 'DYN_TYPE:'
         Dyn_Type  = value;      
      case 'NUMB_DYN_TERMS:'
         Numb_dyn_terms = str2num(value);      
      case 'TIME_WARP_TYPE:'
         Time_warp_type  = value;      
      case 'TIME_WARP_FACTOR:'
         Time_warp_factor  = str2num(value);      
      case 'BLOCK_LENGTH:'
         Block_length_beg = str2num(value);      
      case 'BLOCK_JUMP:'
         Block_jump  = str2num(value);      
      case 'BVF_NORM_FLAG:'
         BVF_norm_flag  = str2num(value);      
      case 'BVT_NORM_FLAG:'
         BVT_norm_flag  = str2num(value);      
      case 'DELTA_WINDOW_LENGTH:'
         Delta_window_length  = str2num(value);      
      case 'ACCELATOR_WINDOW_LENGTH:'
         Accelator_window_length  = str2num(value);      
      case 'DELTA3_WINDOW_LENGTH:'
         Delta3_window_length  = str2num(value);      
      case 'TRACKER_TYPE:'
         Tracker_type  = value;  
      case 'ALL_PART_VOICE_YAPPT:'
         All_part_voice_yappt  = str2num(value);         
      case 'PITCH_NORMALIZATION:'
         Pitch_Normalization  = value;           
      case 'USE_TERM:' % fixed format
         if isequal(value,'USER')
             use_term_flag = 1;          % Using the provided table
             Use_term_all_DCTC = ones(MAXDCTC, MAXDCS); % to store use terms for dctc from setup file
             Use_term_all_rest = ones(2,MAXDCS);        % to store use terms for pitch and log energy
             s = upper(fgetl(fid)); % skip space line
             s = upper(fgetl(fid)); % skip comment line
             i = 1;
             while (~feof(fid)) % read til end of file
                s = upper(fgetl(fid)); % read each line of use term
                [identifier, remain] = strtok(s); % get DCTCxx identifier and rest

                if isempty(identifier)
                    break;
                end

                if strcmp(upper(identifier(1:4)),'DCTC')
                    if ~isempty(remain)
                       idx = find(remain=='1' | remain=='0');  %look for 1 and 0   
                       for j=1:length(idx)
                           if (remain(idx(j)) == '1')
                              Use_term_all_DCTC(i,j) = 1.0;
                           else
                              Use_term_all_DCTC(i,j) = 0.0;
                           end
                       end
                       i = i + 1; % next row
                    end
                else
                    if (strcmp(upper(identifier),'PITCH'))
                        if ~isempty(remain)
                            idx = find(remain=='1' | remain=='0');  %look for 1 and 0
                            for j=1:length(idx)
                                if (remain(idx(j)) == '1')
                                    Use_term_all_rest(1,j) = 1.0;
                                else
                                    Use_term_all_rest(1,j) = 0.0;
                                end
                            end
                        end
                    else
                        if (strcmp(upper(identifier),'LOGENERGY'))
                            if ~isempty(remain)
                                idx=find(remain=='1' | remain=='0' );     % look for 1 and 0
                                for j=1:length(idx)
                                    if (remain(idx(j))=='1')
                                        Use_term_all_rest(2,j)=1.0;
                                    else
                                        Use_term_all_rest(2,j)=0.0;
                                    end
                                end
                            end
                        end
                    end
                end
             end
         else
             use_term_flag = 0;          % Don't use the provided table
             while ~feof(fid)            % Skip the rest of the file
                 rest=fgetl(fid);
             end
         end
      otherwise 
         warning('rd_spec.m -> Unknown variable name: %s', varname);
      end % end switch
   end
end



fclose(fid);
EnergyFloor_logE  = exp(ENERGYFLOOR_LogE);
if ~isequal(Tracker_type,'NONE')
    Pitch_Flag = 1;
else
    Pitch_Flag = 0;
end
% validate parameters
if Prefilt_Center_Freq>Sample_rate/2
    Prefilt_Center_Freq=Sample_rate/2;
    disp ([sprintf('rd_spec.m -> Warning: Pre-emphasis filter center frequency adjusted to %d\n',Sample_rate/2)]);
end

if Numb_dctcs > MAXDCTC
   Numb_dctcs = MAXDCTC;
   disp ([sprintf('rd_spec.m -> Warning: Numb_dctcs adjusted to MAXDCTC: %d\n',Numb_dctcs)]);
end

if Numb_dyn_terms > MAXDCS
   Numb_dyn_terms = MAXDCS;
   disp ([sprintf('rd_spec.m -> Warning: Numb_dyn_terms adjusted to MAXDCS: %d\n',Numb_dyn_terms)]);
end

if ~(isequal(DCTC_type,'FFT') || isequal(DCTC_type,'MEL') || isequal(DCTC_type,'GAMMA'))
    error(sprintf('Wrong DCTC_type value=%d, must be FFT, MEL or GAMMATONE',DCTC_type));
end


% validate parameters for delta method

if strcmp(upper(Dyn_Type),'DELTA')
    Numb_dyn_terms=4;          % In DELTA, Numb_dyn_terms means number of delta order used (including zero order)
    if (Delta_window_length==0)    % force all window length to 0 if delta_win=0
          Numb_dyn_terms=1;     % Only use zero order terms
          if (Accelator_window_length~=0)
              disp (sprintf('rd_spec.m -> Warning: acceleration window length forced to 0'));
              Accelator_window_length=0;
          end
          
          if (Delta3_window_length~=0)
              disp (sprintf('rd_spec.m -> Warning: third order window length forced to 0'));
              Delta3_window_length=0;
          end
      else
          if (Accelator_window_length==0)      % Use 0 and 1st order terms
              Numb_dyn_terms=2;
              if (Delta3_window_length~=0)
                  disp (sprintf('rd_spec.m -> Warning: third order window length forced to 0'));
                  Delta3_window_length=0;
              end
          else
              if (Delta3_window_length==0)   % Use 0, 1st, 2nd order terms
                  Numb_dyn_terms=3;
              end
          end
     end                          % End checking window length and Numb_dyn_terms
     
     % adjust block parameters
     
     Block_length_beg=2*(Delta_window_length+Accelator_window_length+Delta3_window_length)+1;
     Block_jump=1;
end
     
    

% now copy actual use terms

if use_term_flag == 0   % checks to see if we use table or not
    Num_features  = (Numb_dctcs+Pitch_Flag+Log_Energy_Flag*Log_Expand_Flag)*Numb_dyn_terms;
    Use_term=[];
else
    Use_term = zeros(Numb_dctcs*Numb_dyn_terms, 1);  % right now, only DCTC terms
    for i=1:Numb_dctcs         
       for j=1:Numb_dyn_terms
          Use_term((i-1)*Numb_dyn_terms + j) = Use_term_all_DCTC(i, j);
       end
    end
    Use_term_pitch=[];
    if Pitch_Flag             % this is pitch terms
       for j=1:Numb_dyn_terms
          Use_term_pitch(j)=Use_term_all_rest(1,j);
       end
       Use_term_pitch=Use_term_pitch';
    end
    Use_term_energy=[];
    if Log_Energy_Flag        % this is log energy terms
       if Log_Expand_Flag
          for j=1:Numb_dyn_terms
             Use_term_energy(j)=Use_term_all_rest(2,j);
          end
          Use_term_energy=Use_term_energy';
       end
    end
    Use_term=[Use_term;Use_term_pitch;Use_term_energy];   % put them together
    Num_features = sum(Use_term);     % this is the actual number of features to be used
end


    

fftbase = log(FFT_length)/log(2);
if abs(fftbase-fix(fftbase)) > 0.0001
   
   FFT_length = 2^fix(fftbase+1);
   disp ([sprintf('rd_spec.m -> Warning: FFT_length set to: %d\n',FFT_length)]);
end

% get frame length
Frame_length_cal = fix(Frame_length * Sample_rate / 1000);
% calculate buffer length. This is segment length + frame length
Buffer_length = Frame_length_cal + Segment_length;




% check if current FFT length is sufficient?
if Frame_length_cal > FFT_length
	fftbase = log(Frame_length_cal)/log(2);
   FFT_length = 2^fix(fftbase+1); % use next larger fft base
   disp ([sprintf('rd_spec.m -> Warning: FFT_length set to match Frame_length: %d\n',FFT_length)]);
end


% get the FFT index of the minmal frequency

Freq_min = round(FFT_length* Low_freq_limit/Sample_rate) + 1;

% get the FFT index of the maximal frequency

Freq_max = round(FFT_length* High_freq_limit/Sample_rate) + 1;

if (Freq_max > FFT_length/2+1)
    error('rd_spec.m -> Warning: High_freq is too big, please change setup file!');
end



Frame_jump = fix(Frame_space*Sample_rate/1000);
if Frame_jump <= 0
   Frame_jump = fix(Frame_length_cal/2); 
   disp ([sprintf('rd_spec.m -> Warning: Frame_jump set to half Frame_length: %d\n',Frame_jump)]);
end

% total number pf frequency samples to be used
if isequal(DCTC_type,'FFT')
    Freq_total = Freq_max - Freq_min + 1;
else
    Freq_total= Numb_filters;
end



Frames_max = fix((Buffer_length - (Frame_length_cal - Frame_jump))/Frame_jump);

if Frames_max <= 1
   disp ([sprintf('rd_spec.m -> Error: Segment length too short, Less than 1 frame in segment\n')]);
   Params = [];
   Use_term = [];
   return
end

if Block_length_beg < 1
   Block_length_beg = 1;
   disp ([sprintf('rd_spec.m -> Warning: Block_length_beg adjusted to 1\n')]);
end



if Block_length_beg > Frames_max - 1
   Block_length_beg = Frames_max - 1;
   disp ([sprintf('rd_spec.m -> Warning: Block_length_beg reduced to Frames_max-1\n')]);
end



if Numb_dyn_terms > Block_length_beg
   disp ([sprintf('rd_spec.m -> Error: Numb_dyn_terms > Block_length_beg\n')]);
   Params = [];
   Use_term = [];
   return
end

if Block_jump < 1
   Block_jump = 1;
   disp ([sprintf('rd_spec.m -> Warning: Block_jump set to 1 frame\n')]);
end


% This is for fixed block length only. Variable block length above is
% commented out
if Block_jump > Block_length_beg
   Block_jump = Block_length_beg;
   disp ([sprintf('rd_spec.m -> Warning: Block_jump set to Block_length_beg\n')]);
end

% compute number of block sizes
%Block_sizes = 1 + (Block_length_max - Block_length_beg) / Block_jump;
%if Block_sizes ~= fix(Block_sizes)
%   Block_length_max = Block_length_beg + (fix(Block_sizes)-1) * Block_jump;
%   Block_sizes = fix(Block_sizes);
%   disp ([sprintf('rd_spec.m -> Warning: Block_length_max reduced to: %d \n', Block_length_max)]);
%end

%if Block_sizes > MAXBLOCKSIZES
%   disp ([sprintf('rd_spec.m -> Error: Block_sizes > MAXBLOCKSIZES\n')]);
%   Params = [];
%   Use_term = [];
%   return
%end

%Blocks_max = Frames_max + Block_length_max - (Block_length_beg - Block_jump) / Block_jump;
%Blocks_max = fix(Blocks_max);

%Block_time_min = (Block_length_beg-1) * Frame_space + Frame_time;
%Block_time_max = (Block_length_max-1) * Frame_space + Frame_time;
%Block_space    = Block_jump * Frame_space;
% Changing aome characters to numbers





% Numerical values
Params      = zeros(33,1);
Params(1)   = Sample_rate;
Params(2)   = FFT_length;
Params(3)   = Kaiser_window_beta;
Params(4)   = Numb_dctcs;
Params(5)   = Numb_dyn_terms;
Params(6)   = Frame_length_cal;
Params(7)   = Frame_jump;
Params(8)   = Block_length_beg;
Params(9)  = Block_jump;       
Params(10)  = Low_freq_limit;         
Params(11)  = High_freq_limit;        
Params(12)  = Freq_min;          
Params(13)  = Freq_max;          
Params(14)  = Freq_total;        
Params(15)  = Prefilt_Center_Freq;  
Params(16)  = Spectral_range;    
Params(17)  = Time_warp_factor;    
Params(18)  = Static_Warp_factor;    
Params(19)  = BVF_norm_flag;     
Params(20)  = BVT_norm_flag;     
Params(21)  = Num_features;      
Params(22)  = All_part_voice_yappt;
Params(23)  = plot_spec;
Params(24)  = shift_deg_NonSym;
Params(25)  = Pitch_Flag;
Params(26)  = Numb_filters;
Params(27)  = Width_gammatone;
Params(28)  = Delta_window_length;
Params(29)  = Accelator_window_length;
Params(30)  = Delta3_window_length;


% Character parameters

Params_char{1} = strvcat(Amplitude_scaling);
Params_char{2} = strvcat(DCTC_type);
Params_char{3} = strvcat(Static_warp_type);
Params_char{4} = strvcat(Dyn_Type);
Params_char{5} = strvcat(Time_warp_type);
Params_char{6} = strvcat(Tracker_type);
Params_char{7} = strvcat(Pitch_Normalization);



% Log energy parameters

LogEnergy   = zeros(4,1);
LogEnergy(1)= Log_Energy_Flag;
LogEnergy(2)= EnergyFloor_logE;
LogEnergy(3)= ENERGYFLOOR_LogE;
LogEnergy(4)= Log_Expand_Flag;

% end
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 