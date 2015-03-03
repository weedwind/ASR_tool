function [Feat, OutPars, OutFloats]  = cp_feat2(DoWhat, Data, SpecFile, InitPars, InitFloats, Methd)
% CP_FEAT2 Calculates time-frequncy variable DCTC/DCS features
% function [BV] =  cr_vbvt(stWarp, edWarp, numFreqs, numVectors, omFlag);
% calcuates time/frequency variable DCTC/DCS features. Two main
% processes INIT and PROC are provided. The INIT generates basis
% vectors, and the PROC calcuate features using basis vectors.
%
% INPUTS:
%   DoWhat    : Command in string array format ('init', 'proc', 'free')
%   Data      : A column matrix contains input speech samples
%   SpecFile  : Name of feature computation specifications file
%   InitPars  : A column matrix contains integer parameters needed for feature computation
%   InitFloats: A column matrix contains floating point parameters needed for feature computation
%
% Outputs:
%   Feat      : Output features which are stored in rowwise 
%   OutPars   : A column matrix contains integer output parameters
%   OutFloats : A matrix contains floating point output parameters

%   Creation date:  02/20/2008
%   Revision dates: 06/02/2008
%   Programmer   :  Hongbing Hu, Jiang Wu, Stephen Zahorian

persistent BvF BvT Use_term
persistent Num_features Add_frames_flag
persistent Frame_length Frame_lengths Frame_diffs 
persistent Freq_min Freq_max Freq_ranges
persistent FFT_length Sample_rate KaiserWnd_beta Frame_jump 
persistent Block_length Block_jump Num_DCTC Num_DCS
persistent Spectral_floor Bias_value
persistent EnergyFloor_logE ENERGYFLOOR_LogE Log_Energy_Flag



% Main rountine
switch upper(DoWhat) 

 case 'PROC'                % Process feature using basis vectors
  Feat = [];
  DataLen = length(Data);

  if DataLen < Frame_length
      warning('cp_feat2 -> DataLen %d < frame_length %d!', DataLen, ...
              Frame_length);
      return
  end
  
  % Use longest length to calculate frame num, Frame_length is longest?
  numFrames = 1 + fix((DataLen - Frame_length)/Frame_jump);
  % first check if we have enough number of frames??
  if numFrames < Block_length
       warning('cp_feat2.m -> Too few frames to fit in one block!');
       return
  end
   
  % DC removal
  Data = Data-mean(Data);
  
  %% Use different window lengths to compute serveral spectra    
  for iFLen = 1:length(Frame_lengths)        
      % Kaiser window
      KWindow = kaiser(Frame_lengths(iFLen), KaiserWnd_beta);  
      for iFrm = 1 : numFrames
          pointer   = (iFrm-1) * Frame_jump + Frame_diffs(iFLen) + 1;     
          FrameData = Data(pointer : pointer+Frame_lengths(iFLen)-1).*KWindow;
          
      if Log_Energy_Flag
         LogEnergy_Frame_data(1,iFrm) = sum(FrameData.*FrameData);
         if (LogEnergy_Frame_data(1,iFrm) < EnergyFloor_logE)
             LogEnergy_Frame_data(1,iFrm) = ENERGYFLOOR_LogE;
         else                
             LogEnergy_Frame_data(1,iFrm) = log(LogEnergy_Frame_data(1,iFrm));
         end
      end


          %%Compute the spectrum magnitude of each frame
          Frame_mag = abs(fft(FrameData, FFT_length)).^2;
          Frame_mag = Frame_mag(1:FFT_length/2);

      PeakVal = max(Frame_mag);
      FloorVal = PeakVal/Spectral_floor^2;
      [idx] = find(Frame_mag < FloorVal);
      Frame_mag(idx) = FloorVal;

      Frame_mag = log(Frame_mag + Bias_value); % compute log spectrum


%          Frame_mag = log(abs(fft(FrameData, FFT_length)).^2);
          
          %% Original spectriParum Matrix
          MSpec(: , iFrm, iFLen) = Frame_mag(Freq_min:Freq_max);     
      end
  end
  
  % Hongbing: How to remove discontiunity
  Spec = zeros(Freq_max-Freq_min+1, numFrames);
  for iRng = 1:length(Freq_ranges)-1
      SRange = [Freq_ranges(iRng):Freq_ranges(iRng+1)]-Freq_min+1; 
      Spec(SRange,:) = MSpec(SRange,:,iRng);    
  end
  
  % Add extra frames for block length issue 
  if Add_frames_flag > 0  
      numExtra = fix(Block_length/2);
      FirstVect = Spec(:,1);
      LastVect  = Spec(:,end);
      Spec = [repmat(FirstVect,1,numExtra) Spec repmat(LastVect,1,numExtra)];
      % Determine # of blocks to process
      numBlocks = 1 + fix((numFrames + 2*numExtra - Block_length)/Block_jump);
  else
      % Determine # of blocks to process
      numBlocks = 1 + fix((numFrames - Block_length)/Block_jump);
  end
  % Calculate feature matrix
  Feat = zeros(Num_features, numBlocks);
  for iBlk = 1 : numBlocks 
      pointer = (iBlk-1)*Block_jump + 1;
      Block_Spec = Spec(:, pointer : pointer+Block_length-1);     
      %% compute DCS(j, f) for 1 block  
      for n = 1 : Num_DCS
          DCS(n,:) = sum(Block_Spec(:, :) .* BvT(:, :, n), 2);
      end
      %% compute Feat(i,j) for 1 block
      DCTC = DCS * BvF;
      Feat(:,iBlk) = reshape(DCTC, Num_DCTC*Num_DCS, 1);

%       for n = 1 : Num_DCTC
%          for k = 1 : Num_DCS
%              id = (n-1)*Num_DCS + k;
%              Feat(id, iBlk) = DCS(k, :) * BvF(:, n);
%          end
%       end
  end
  
 case 'INIT'        % Initialize basis vectors    
  % Get parameters from cp_feat13.ini   
  [CP_Pars, Use_term, LogEnergy] = rd_spec(SpecFile, InitPars, InitFloats);

  Sample_rate       = CP_Pars(1);
  Segment_length    = CP_Pars(2);

  FFT_length        = CP_Pars(4);
  KaiserWnd_beta    = CP_Pars(5);
  Num_DCTC          = CP_Pars(6);
  Num_DCS           = CP_Pars(7);
  Frame_length      = CP_Pars(8);
  Frame_jump        = CP_Pars(9);
  Block_length_min  = CP_Pars(11);
  Block_length_max  = CP_Pars(12);
  Block_jump        = CP_Pars(13);

  %Low_freq          = CP_Pars(16);
  %High_freq         = CP_Pars(17);
  Freq_min          = CP_Pars(18);
  Freq_max          = CP_Pars(19);
  Prefilter_center  = CP_Pars(21);
  Spectral_range    = CP_Pars(22);

  Time_warp_fact    = CP_Pars(27);
  DCTC_warp_fact    = CP_Pars(28);
  BVF_norm_flag     = CP_Pars(29);
  BVT_norm_flag     = CP_Pars(30);

  Num_features      = CP_Pars(31);
  Add_frames_flag   = CP_Pars(32);
  bias              = CP_Pars(33);

  %% Warping parameters
  Time_warp_fact2   = CP_Pars(39);
  Frame_length2     = CP_Pars(40);
  Frame_length3     = CP_Pars(41);
  Freq_bound1       = CP_Pars(42);
  Freq_bound2       = CP_Pars(43);
  En_norm_flag      = CP_Pars(44);

  Log_Energy_Flag   = LogEnergy(1);
  EnergyFloor_logE  = LogEnergy(2);
  ENERGYFLOOR_LogE  = LogEnergy(3);

  
  if (Block_length_max ~= Block_length_min) 
      warning(['Variable block length not supported, minimum block ' ...
                'length (%d) used.'], Block_length_min);
  end
  Block_length = Block_length_min;
  % Set frame lengths
  if (Frame_length2 ~= 0)
      Frame_lengths = [Frame_length, Frame_length2]; 
      if (Frame_length3 ~= 0)
          Frame_lengths = [Frame_length, Frame_length2, Frame_length3]; 
      end
  else
      Frame_lengths = Frame_length; 
  end
  Frame_diffs  =  (Frame_length-Frame_lengths)/2;

  % Set frequency ranges
  if (Freq_bound1 ~= 0)
      Freq_ranges =  [Freq_min, Freq_bound1, Freq_max];
      if (Freq_bound2 ~= 0)
          Freq_ranges = [Freq_min, Freq_bound1, Freq_bound2, Freq_max];
      end
  else
      Freq_ranges =  [Freq_min, Freq_max];
  end
  if (length(Freq_ranges) > (length(Frame_lengths)+1))
      error(['The num of freq ranges must be equal or less than the ' ...
             'num of frame lengths']);
  end
  %% Compute basis vectors
  
  switch Methd
      case 'BETA'
          [BvF,delta] = comp_bvf(DCTC_warp_fact, Freq_min, Freq_max,...
                         Num_DCTC, BVF_norm_flag);
          BvT = comp_vbvt(Time_warp_fact,Time_warp_fact2, Freq_min, ...
                Freq_max,Block_length, Num_DCS, BVT_norm_flag);
           % The following process to be moved into comp_vbvt 
           for iDCS = 1 : size(BvT, 3)
                dd(:, :, iDCS) = BvT(:, :, iDCS)';
           end
            BvT = dd;
            
      case 'DCSLEN'

          disp (' Computing basis vectors using DCSLEN method')

          [BvF,delta] = comp_bvf(DCTC_warp_fact, Freq_min, Freq_max,...
                         Num_DCTC, BVF_norm_flag);

%         Now compute lengths of DCS basis vector sets
%         longest set will be block length
%         Must be sure each length is at least as long as Num_DCS
%         and an odd number


          FI_length = length(delta);

          length_DCS =  round(Block_length * ones(1, FI_length) .* delta);

for f = 1 : FI_length
    if ( length_DCS(f) <= Num_DCS)
         length_DCS(f) = Num_DCS;
    end
    if rem(length_DCS(f), 2) == 0
        length_DCS(f) = length_DCS(f)+1;
    end

end

%  At this point, the basis vector lengths are computed to give longer
%  lengths at low frequency, and shorter lengths at higher frequency


for f = 1:FI_length

 BvT_f = comp_bvt(length_DCS(f), length_DCS(f), Block_jump,...
                        Num_DCS, Time_warp_fact, BVT_norm_flag);

 BvT_ff = zeros(Block_length,Num_DCS);
 zero_pad = (Block_length - length_DCS(f))/2;

 BvT_ff(zero_pad+1:zero_pad + length_DCS(f),:) = BvT_f(:,:);


%  Now transfer the basis vectors to the 3 D array
     BvT(f,:,:) = BvT_ff(:,:);

end

%     mesh(BvT(:,:,3));


%          [BvF, BvT] = cp_2dbv(Block_length, Freq_min, Freq_max,...
%           Num_DCS, Num_DCTC, DCTC_warp_fact, Time_warp_fact,...
%            Time_warp_fact2, BVF_norm_flag, BVT_norm_flag, En_norm_flag);


      otherwise
          error ('Basis Vector computation method must be either "BETA" or "DCSLEN"')
  end
  %mesh(BvT(:,:,1));
  %pause
  %mesh(BvT(:,:,2));
  %pause;
  % these 2 variables used to limit spectral range
  Spectral_floor = 10^(Spectral_range/20);
  if Spectral_floor > 200 
      Bias_value = 1;        % ie, range greater than 47db
  else
      Bias_value = 100;
  end



  OutPars(1) = Segment_length;
  OutPars(2) = Sample_rate;
  OutPars(3) = Block_length;
  OutPars(4) = Num_features;
  OutPars(5) = Frame_jump;       % need for HTK file
  OutPars(6) = Block_jump;       % need for HTK file
  
  OutFloats(1) = Segment_length*1000/Sample_rate;
  OutFloats(2) = 0;              % segment_energy is 0 for now
  OutFloats(3) = Prefilter_center;
  Feat = [];
case 'FREE' % termination mode, may not need for Matlab
   % TODO: add termination code here
   Feat      = [];
   OutPars   = [];
   OutFloats = [];
otherwise
   error('Unknown command %s!', DoWhat);
end % end switch DoWhat
