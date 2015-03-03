function [Feat, OutPars, OutFloats]  = cp_feat(DoWhat, X, SpecFile,...
              InitPars, InitFloats,CPFeatType,FreqWarpMethd,TimeWarpMethd,FrmSelMeth)
%function [Feat, OutPars, OutFloats]  = cp_feat(DoWhat, X, SpecFile,
%InitPars, InitFloats)
%
% Inputs:
%   DoWhat        -- command in string array format ('init', 'proc', 'cont', 'free')
%   X             -- a column matrix contains input speech samples
%   SpecFile      -- name of feature computation specifications file
%   InitPars      -- a column matrix contains integer parameters needed for feature computation
%   InitPars(1)   -- Segment length
%   InitPars(2)   -- Sampling frequency
%   InitFloats    -- a column matrix contains floating point parameters needed for feature computation
%   InitFloats(1) -- Prefilter center
%   CPFeatType    --  'DCTC1'  for DCTC calc, then DCS
%                     'DCTC2'  for 2-D basis vector calculations
%   FreqWarpMethd --  Type of Frequency Warping--  Bilinear or Mel
%   TimeWarpmethd --  Type of Time Warping--  Kaiser, or Gaussian, or Sigmoid
%
% Outputs:
%   Feat           -- output features which are stored in rowwise 
%                     (number of columns in Feat = number of frames (blocks))
%   OutPars        -- a column matrix contains integer output parameters
%   OutPars(1)     -- Segment length
%   OutPars(2)     -- Sampling frequency
%   OutPars(3)     -- Number of blocks
%   OutPars(4)     -- Number of features
%   OutPars(5)     -- Frame_jump, need for HTK file format
%   OutPars(6)     -- Block_jump, need for HTK file format
%   OutFloats      -- a column matrix contains floating point output parameters
%   OutFloats(1)   -- Segment time
%   OutFloats(2)   -- Segment energy
%   OutFloats(3)   -- Prefilter center
%
%
% Subroutine used: comp_bvf.m (gs1.m), comp_bvt.m (gs1.m), 
%

% Version         : 0.02
% Programmer      : Montri K.
% Creation date   : 11/09/99
% Revision date   : 12/07/99
%                 : 02/21/00 Montri  3/26/00  (SAZ)
%                            Now, reading specification file is done here
%                            CP_Pars and Use_term were removed from input argument list
%                            SpecFile was added to input argument
%                            Add Frame_jump and Block_jump to OutPars 
%                            This is for HTK file format
%                 : 4/9/00   now does envelope smoothing over frequency and time
%                            using  matrix functions
%                 : 04-18-00 Add ADD_FRAMES_FLAG to cp_fea13.ini to indicate if we
%                            want to add extra frames to frame based features before
%                            block processing in fixed block length mode or not.
%                            Note that adding some extra frames at both ends of an
%                            utterance yields better synchronization between featurs
%                            and time labels. This improves recognition performance
%                            in continuous speech recognition.
%                 : 07-19-03 Penny 
%                            Add frame level log energy calculations.
%                 : 5-29-05  Use_term is now used for case of fixed block length
%                            to select only specified features (SAZ)
%                 :   2008   lots of changes made for DCTC2 processing (SAZ)
%                 : 3-6-09   Fix up code for downselecting features used by use_term
%                            This part only works for DCTC1 processing
%                 : 4-26-09  Fix up code for determining if waveform is too short
%                            for one block
%                 : 5-20-11  J. Wu: Major change includes 1) No interpolation on either time
%                 or frequency 2) support DCTC2 3) support NON-symmetric
%                 window and Exponential window 4) support LOGenergy 5)
%                 Look into NLWALP.m for new feature and its detail
%                                          


% add static variable names here
persistent Use_term bvF bvT
persistent BvF BvT delta1 delta warp_t2 warp_t2_fff
persistent Kaiser_window 
persistent Spectral_floor Bias_value

% the following are variables used to store feature computation specifications
persistent Sample_rate Segment_length Buffer_length FFT_length 
persistent KaiserWnd_beta Num_DCTC Num_DCS Frame_length Frame_length2 Frame_jump
persistent Frames_max Block_length_beg Block_length_max Block_jump
persistent Block_sizes Blocks_max Low_freq High_freq Freq_min Freq_max
persistent Freq_total Prefilter_center Spectral_range 
persistent Freq_kernel_min Freq_kernel_max Time_kernel_before Time_kernel_type
persistent Time_warp_fact DCTC_warp_fact BVF_norm_flag BVT_norm_flag Num_features
persistent Add_frames_flag EnergyFloor_logE ENERGYFLOOR_LogE Log_Energy_Flag CP_PITCH
persistent Block_length
persistent DCTC_warp_fact1 DCTC_warp_fact2 Time_warp_fact1 Time_warp_fact2

persistent ip_lpc
persistent a_sigmoid b_sigmoid
persistent vary_frm_len plot_spec
persistent fullDelta uni_frame_lengths frame_lengths

epsilon = .0001;   %  lower limit to avoid log(0);
                       %  Not used at present

% Flags for control processes

%vary_frm_len = 1;     These values now put in cp_fea13.ini file  and
%plot_spec = 0;        passed to  this routine at initialization

%   Insure that the Num_DCS is an odd number if CPFeatType is 'DCTC2')

%   Conversions of FreqWarpMethd  and TimeWarpMeth

        Fwarp = 'B';
        Twarp = 'S';

        if FreqWarpMethd(1:3) == 'BIL'
           Fwarp = 'B';
        end
        if FreqWarpMethd(1:3) == 'MEL'
           Fwarp = 'M';
        end

        
        if TimeWarpMethd(1:6) == 'EXPONE'
            Twarp = 'E';
        end
                
        if TimeWarpMethd(1:6) == 'KAISER'
           Twarp = 'K';
        end

        if TimeWarpMethd(1:6) == 'GAUSSI'
           Twarp = 'G';
        end

        if TimeWarpMethd(1:6) == 'SIGMOI'
           Twarp = 'S';
        end

        if TimeWarpMethd(1:6) == 'NONSYM'      %option to use Asymmetric Gaussian window
            Twarp = 'N';
        end

        

        
% variable for processing in realtime
persistent ix % index to input speech samples
switch upper(DoWhat)
case 'PROC' 

    if CP_PITCH
        Param(1)= Frame_jump*Block_jump*1000/Sample_rate;
        Param(2)= Frame_length*1000/Sample_rate;
        [FinPitch, numframes] = yaapt(X, Sample_rate, Param, 0);
    end
   
   DataLen = length(X);
   % find total number of frames
   if DataLen < Frame_length
		disp ([sprintf('cp_feat.m -> Error: DataLen < frame_length!')])
      Feat = [];
      return
   end
   
   NumFrm = 1 + fix((DataLen - Frame_length)/Frame_jump);
   Frame_feat = zeros(Num_DCTC, NumFrm);
   Seg_spectrum  = zeros(FFT_length/2, NumFrm);
   Seg_spectrum1 = zeros(FFT_length/2, NumFrm);

   % DC removal
   X = X-mean(X);
   
   % Compute static features
   for i = 1:NumFrm
      ix = (i-1) * Frame_jump + 1;
      Frame_data   = X(ix:ix+Frame_length-1);      % extract one frame of data
      Frame_dataW  = Frame_data .* Kaiser_window;  % apply window
      % Calculate Log Energy of current frame of data
      if Log_Energy_Flag
         LogEnergy_Frame_data(1,i) = sum(Frame_data.*Frame_data);
         if (LogEnergy_Frame_data(1,i) < EnergyFloor_logE)
             LogEnergy_Frame_data(1,i) = ENERGYFLOOR_LogE;
         else
             LogEnergy_Frame_data(1,i) = log(LogEnergy_Frame_data(1,i));
         end
      end
      
      if (ip_lpc >0)
         auto_smooth = 1;
      else
         auto_smooth = 0;
      end

      if (vary_frm_len==0)
      if (auto_smooth == 0)
         Frame_FFT = fft(Frame_dataW, FFT_length); % perform FFT
         Frame_FFTmag = (abs(Frame_FFT(1:FFT_length/2))).^2;
        else
          Frame_FFTmag = speca(Frame_dataW, Sample_rate, FFT_length,Bias_value);
        end

      else   % section of code for variable frame length
          % Expand the delta to a full frequency range (0~Fs) of delta
          % Frame_dataw is windowed frame data 
          init = 1;

          Frame_FFT  = specb(Frame_dataW, FFT_length, fullDelta,...
            Frame_length,Frame_length2,init,uni_frame_lengths,frame_lengths);
          Frame_FFTmag = (abs(Frame_FFT(1:FFT_length/2))).^2;
          
          %Frame_FFT2 = fft(Frame_dataW, FFT_length); % perform FFT
          %Frame_FFTmag2 = (abs(Frame_FFT2(1:FFT_length/2))).^2;
          %subplot(211);
         % hold off, plot(Frame_FFTmag,'r');
         % hold on, plot(Frame_FFTmag2,'b-');
          %subplot(212);
          % plot(Frame_FFTmag2-Frame_FFTmag,'b');
         % pause;
      end


      % compute spectrum magnitude over selected freq range
      % put limit to lower level of the spectrum
      PeakVal = max(Frame_FFTmag);
      FloorVal = PeakVal/Spectral_floor^2;

      if FloorVal < epsilon
          FloorVal = epsilon;
      end;

      [idx] = find(Frame_FFTmag < FloorVal);
      Frame_FFTmag(idx) = FloorVal;
      Frame_logmag = log(Frame_FFTmag ); % compute log spectrum
      Seg_spectrum(:,i) = Frame_logmag;
   end


   %%%% Plot Spectrogram %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   if plot_spec 
       [nrow, ncol] = size(Seg_spectrum);
       % x and y axes
       tt_spec = linspace(0, (ncol-1), ncol);
       ff_spec = linspace(0, Sample_rate/2, nrow);
       figure(10);
       imagesc(tt_spec, ff_spec, Seg_spectrum);
       xlabel('Time (Frame  No)');
       ylabel('Frequency (Hz)');
       title( ' Original Spectrum ');

       axis xy;
       pause
   end
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





%%%%%%


   lin_type = 2;

   % below is implementation of the sigmoid nonlinearity

%  This is the case for nonlinearity based on min and max of each frame
%  Type A??

    if (lin_type == 1)

      for i = 1:NumFrm,
        x = Seg_spectrum(:,i);
        y=  nonlin7(a_sigmoid,b_sigmoid,ratio_sigmoid,1, 100, x,500, 'local');
        Seg_spectrum(:,i) = y;  %This is new code


    end
    end

%  This is the case,  where nonlinearity is based on overall min and max


   if (lin_type == 2)
     Min_overall =  min(min(Seg_spectrum));
     Max_overall =  max(max(Seg_spectrum));
     for i = 1:NumFrm,
        x = Seg_spectrum(:,i);
        y=  nonlin7(a_sigmoid,b_sigmoid,ratio_sigmoid, x,Min_overall,Max_overall,500, 'global');

        Seg_spectrum(:,i) = y;  %This is new code
     end
   end


%%%%%%%%%




   %%%% Plot Spectrogram %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   if plot_spec 
       [nrow, ncol] = size(Seg_spectrum);
       % x and y axes
       tt_spec = linspace(0, (ncol-1), ncol);
       ff_spec = linspace(0, Sample_rate/2, nrow);
       figure(11);
       imagesc(tt_spec, ff_spec, Seg_spectrum);
       xlabel('Time (Frame  No)');
       ylabel('Frequency (Hz)');
       title( ' Spectrum after nonlinear amplitude scaling');
       axis xy;
       pause
   end
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

          
   % In this section, code does peak envelope smoothing over frequency

       N_freq = Freq_max - Freq_min + 1;
   if (Freq_kernel_max > 0)
       delta_F = Sample_rate/ FFT_length;
       Seg_spectrum1 = envelopm(Seg_spectrum, Freq_kernel_min,Freq_kernel_max,...
        delta_F, Freq_min,Freq_max);
   else
       Seg_spectrum1 = Seg_spectrum(Freq_min:Freq_max,:);
   end;
   

%   if ( CPFeatType == 'DCTC1' )


%      Seg_spectrum = interp1(Seg_spectrum1, delta1);
%      Seg_spectrum1 = Seg_spectrum;


      Seg_spectrum = Seg_spectrum1;

%    For unexplained reasons, interp1 does not work for this application
%    with linear interpolation--  appears to be endpoint problem
%    with linear method,  features are NaN

%    end

%    For DCTC2 processing, the non-uniform frequency sampling is
%    done along with non-uniform time sampling using interp2

%    for i = 1:fix(NumFrm/10):NumFrm
%      x = 1:N_freq;
%      y = Seg_spectrum1(:,i);
%      xi = delta1;
%      yi = Seg_spectrum(:,i);

%      plot(x,y,'g',xi,yi,'b')
%      pause
%    end


   % Peak smoothing over time
   if (Time_kernel_before > 0)
       for i = 1:NumFrm
           width = min(i,Time_kernel_before+1);
           start_index = i-width+1;
           if (Time_kernel_type == 0)             % peak smoothing
               Seg_spectrum(:,i) = max(Seg_spectrum1(:,start_index:i)',[],1)';
           else                                  % average smoothing
               Seg_spectrum(:,i) = mean(Seg_spectrum1(:,start_index:i)',1)';
           end
       end
   end



      % Add extra frames to account for block length only if
      %  entire sentence is to be processed

      % how many extra frames need to be added

      NumExtraFrm = 0;
      if (FrmSelMeth == 0)

          NumExtraFrm = fix(Block_length_beg /2);
              First_vect = Seg_spectrum(:,1);
              Last_vect  = Seg_spectrum(:, size(Seg_spectrum, 2));
          Seg_spectrum = [repmat(First_vect, 1, NumExtraFrm) Seg_spectrum...
             repmat(Last_vect, 1, NumExtraFrm+Block_jump-1)];

       end;

%      Try adding frames at beginning and end to mirror image about
%      beginning and end points
%      The following method for adding frames was tested on July 4, 2008
%      Was not quite as effective as the more simple method above


%             NumExtraFrm = fix(Block_length_beg /2);
%             [m,n] = size(Seg_spectrum);
%             First_part = zeros(m, NumExtraFrm);
%             NumExtraFrmEnd = NumExtraFrm+Block_jump-1;
%             Last_part = zeros(m, NumExtraFrmEnd);

%             for  i =1:NumExtraFrm
%                First_part(:,NumExtraFrm+1-i) = Seg_spectrum(:,i+1);
%             end

%             for  i =1:NumExtraFrmEnd
%                Last_part(:,i) = Seg_spectrum(:,n-i);
%             end

%             Seg_spectrum = [First_part Seg_spectrum Last_part];

          % determine # of blocks to process


            if (FrmSelMeth == 0)
              NumBlk = fix(1 + (NumFrm-1) / Block_jump);
            else

               NumBlk = fix(1 + (NumFrm - Block_length_beg) / Block_jump);

            end

            
            
            
   if ((CPFeatType == 'DCTC1' ) | (CPFeatType == 'DCTC3' ))

       Frame_feat = bvF' * Seg_spectrum; 
       
   if CP_PITCH
       P                 =  size(Frame_feat, 2);
       Q                 =  length(FinPitch);
       XX = (1:Q)/Q;
       XI = (1:P)/P;
       Frame_feat1 =  interp1(XX,FinPitch,XI,'linear');
       Frame_feat(1,1:end) = Frame_feat1(1:end);
   end

%  Should end up  at this point with pitch as a single feature,  one feature
%  per frame


   %%  End computation of Static  Coefficients %%
   
   %% Begin block processing code (Computation of dynamic features) %%
   % first check if we have enough frames for at least once block??

   NumFrm_padded = length(Seg_spectrum);
   if NumFrm_padded < Block_length_beg
       warning('cp_feat.m -> Too few frames to form one block!');
       Feat = [];
       return
   end
      
      
   % fixed block size
   if (Block_length_beg == Block_length_max)
       if Block_length_beg == 1 & Block_jump == 1 & Num_DCS == 1    % get only the DCTC's
           Feat = Frame_feat;
       else
       

      %% The following code computes the dynamic terms %%%%

      
      % initialize output feature matrix

      Feat = zeros(Num_features, NumBlk);


%      Now compute features for all DCTC and all DCS initially
%      select terms actually used later

          Num_features1  = Num_DCTC*Num_DCS;
          Feat1 = zeros(Num_features1, NumBlk);
          Feat  = zeros(Num_features, NumBlk);

             iFrame = 1;

         for iBlk = 1:NumBlk

%     This version written to have more matrix operations
%     to improve speed.  Inner do loop over NumDCTC no longer needed
%     tested for functional equivalency to ver51
%

      Feat_blk  =  Frame_feat(:, iFrame:iFrame+Block_length_beg-1);

            
      %Feat_blk1 =  (interp1(Feat_blk', warp_t2,'linear'))';
        
      Feat_blk1 = Feat_blk;

%      x = 1:Block_length_beg;
%      y = Feat_blk;
%      xi = warp_t2;
%      yi = Feat_blk1;

%      plot(x,y,'g',xi,yi,'b')
%      pause


           if ( CPFeatType == 'DCTC1' )
                if Num_DCTC == 1
                    Feat_blk1 = Feat_blk1.';
                end                  
                temp =  (Feat_blk1(:,:) * bvT(:, :, 1));        
                temp1 = reshape(temp.',1,Num_features1);           
                Feat1(:, iBlk) = temp1;
           end;

           if ( CPFeatType == 'DCTC3' )

              temp1 = [];
              for i_DCTC = 1:Num_DCTC
                temp =  (Feat_blk1(i_DCTC,:) * bvT(:, :,1))';  % use different
                                        %  dcs set for each dctc
                temp1 = cat(1,temp1,temp);
              end;

                Feat1(:, iBlk) = temp1';
           end;

                   iFrame = iFrame + Block_jump;
         end


%      else % not all terms are used


       if (Num_features1 == Num_features)  %  all terms used
            Feat = Feat1;

       else % Not all terms are used

          % Now we  must select the terms actually  needed,  and copy from Feat1
          %  to Feat
          sum_term = 0;
          iFeat = 1;
          for ii = 1:Num_features1
              sum_term = sum_term+Use_term(ii);
              if (sum_term == iFeat)
                  Feat(iFeat,:) = Feat1(ii,:);
                  iFeat = iFeat+1;
              end
          end
       end     %   end of loop for which the block size is constant

      end     %   end of loop for computing DCS terms


   else % block size ramps up and down


       if NumFrm < Block_length_max % avoid going beyond data
           Block_length_max = NumFrm;
           disp ([sprintf('  cp_feat.m -> Warning: Block_length_max adjused to NumFrm!')])
       end
       
       % TODO: must check if number of frames < Block_length_max????
       NumBlk1 = 1 + fix((NumFrm-Block_length_max) / Block_jump); % NumBlk with fixed block size
       
       % NumBlk2 is gauranteed to be integer because validation was made in rd_spec.m
       NumBlk2 = fix((Block_length_max-Block_length_beg)/Block_jump); % # of blocks at ramping up or down region
       
       % prepare output matrix
       Feat = zeros(Num_features, NumBlk1+NumBlk2+NumBlk2);
       
       % if all terms are used, do it in a faster way
       if ( (Num_features == length(Use_term)) | (Num_features-1 == length(Use_term) & Log_Energy_Flag) )  
           iFrame = 1;
           iBlk = 1;
           iBvt = 1;
           BlkSize = Block_length_beg;
           % ramping up
           for i = 1:NumBlk2
               for iFeat = 1:Num_DCTC
                   ii = (iFeat-1) * Num_DCS;
                   Feat(ii+1:ii+Num_DCS, iBlk) = ...
                       (Frame_feat(iFeat, iFrame:iFrame+Block_length-1) * bvT(1:Block_length, :, iBvt))';
               end
               BlkSize = BlkSize + Block_jump;
               iBlk = iBlk + 1;
               iBvt = iBvt + 1;
           end
           
           % fixed block size
           for i = 1:NumBlk1
               for iFeat = 1:Num_DCTC
                   ii = (iFeat-1) * Num_DCS;
                   Feat(ii+1:ii+Num_DCS, iBlk) = ...
                       (Frame_feat(iFeat, iFrame:iFrame+BlkSize-1) * bvT(1:BlkSize, :, iBvt))';
               end
               iFrame = iFrame + Block_jump;
               iBlk = iBlk + 1;
           end
           
           % ramping down

           for i = 1:NumBlk2
               iBvt = iBvt - 1;
               BlkSize = BlkSize - Block_jump;
               for iFeat = 1:Num_DCTC
                   ii = (iFeat-1) * Num_DCS;
                   Feat(ii+1:ii+Num_DCS, iBlk) = ...
                       (Frame_feat(iFeat, iFrame:iFrame+BlkSize-1) * bvT(1:nBlkSize, :, iBvt))';
               end
               iFrame = iFrame + Block_jump;
               iBlk = iBlk + 1;
           end
           
       else 
           % not all terms are used
       end %   end of ramping up  and down case


   end % end of PROC loop

%    Insert code here to replace very last feature by Log energy, if selected

     if Log_Energy_Flag

%      Interpolate  Log energy values to be the same length as feature matrix

      X = (1:NumFrm)/NumFrm;
      Y = LogEnergy_Frame_data;
      Y = (Y - mean(Y))/std(Y);  %  Normalize the energy
      XI = (1:NumBlk)/NumBlk;
%      Log_Energy_Interp =  lininterp1f(X,Y,XI,'linear');


       if (length(Y) > 1)

         Log_Energy_Interp =  interp1(X,Y,XI,'linear');
       else

         Log_Energy_Interp =  Y;
       end

 
       %%Pitch = resample(FinPitch, P, Q);
       Feat(Num_features,:) = Log_Energy_Interp; 
      end  %  end of Log_Energy_Flag
      
      
   end  %   end of DCTC1 processing

   if (CPFeatType  == 'DCTC2')

  % Calculate feature matrix
  Feat = zeros(Num_features, NumBlk);
  DCS  = zeros(Num_DCS,N_freq);

  
  Block_length = Block_length_beg;

%  figure(3)
%  mesh(BvT(:,:,1));
%  pause

%  figure(4)
%  mesh(warp_t2_fff);
%  pause



  for iBlk = 1 : NumBlk
      pointer = (iBlk-1)*Block_jump + 1;
      Block_Spec = Seg_spectrum(:, pointer : pointer+Block_length-1);

%     figure(1)
%     mesh (Block_Spec);
%     pause

%     The following does interpolation of Block_Spec over both
%     frequency and time
%     Over frequency, interpolation is done according to frequency
%      warping function  (YYI)
%     Over time, interpolation is done using frequency-dependent
%     time warping  (XXI)

%      There should be a way to do this interpolation
%      using interp1,  and using only XXI over time
%      Frequency interpolation is already done for entire spectrogram


%       Block_Spec1 = interp2(Block_Spec,XXI,YYI,'linear');  


%     XX = [1:size(XXI,2)];
%  for n = 1:N_freq
%       Block_Spec1(n,:) = lininterp1f(XX,Block_Spec(n,:),XXI(n,:),[]);
%  end


%      try this using a series of 1 dimensinal interpolations
%      Appears to give  same result as using interp2-- but speed is slower
%       by about a factor of two than using interp2

%        for n = 1:N_freq
%         Block_Spec1(n,:) = interp1(Block_Spec(n,:),XXI(n,:), 'linear') ;
%        end;




%     figure(2)
%     mesh(Block_Spec1)
%     pause;


      %% compute DCS(j, f) for 1 block
      for n = 1 : Num_DCS
          DCS(n,:) = sum(Block_Spec(:, :) .* BvT(:, :, n), 2);
      end
      %% compute Feat(i,j) for 1 block

      DCTC = DCS * BvF;
      Feat(:,iBlk) = reshape(DCTC, Num_DCTC*Num_DCS, 1);

  end

%    Insert code here to replace very last feature by Log energy, if selected


     if Log_Energy_Flag
%      Interpolate  Log energy values to be the same length as feature matrix

      X = (1:NumFrm)/NumFrm;
      Y = LogEnergy_Frame_data;
      Y = (Y - mean(Y))/std(Y);  %  Normalize the energy
      XI = (1:NumBlk)/NumBlk;
      Log_Energy_Interp =  interp1(X,Y,XI, 'linear');
      Feat(Num_features,:) = Log_Energy_Interp;
     end  %  end of Log_Energy_Flag

     end;   %  end of DCTC_TYPE = 'DCTC2'  loop



   
 case 'CONT' % for realtime mode or processing with short segments
             % TODO: add code here
  
  case 'INIT' % initialization mode


  [CP_Pars, Use_term, LogEnergy] = rd_spec(SpecFile, InitPars, InitFloats);
  
  % store specifications
  Sample_rate       = CP_Pars(1);
  Segment_length    = CP_Pars(2);
  Buffer_length     = CP_Pars(3);
  FFT_length        = CP_Pars(4);
  KaiserWnd_beta    = CP_Pars(5);
  Num_DCTC          = CP_Pars(6);
  Num_DCS           = CP_Pars(7);
  Frame_length      = CP_Pars(8);
  Frame_jump        = CP_Pars(9);
  Frames_max        = CP_Pars(10);
  Block_length_beg  = CP_Pars(11);
  Block_length_max  = CP_Pars(12);
  Block_jump        = CP_Pars(13);
  Block_sizes       = CP_Pars(14);
  Blocks_max        = CP_Pars(15);
  Low_freq          = CP_Pars(16);
  High_freq         = CP_Pars(17);
  Freq_min          = CP_Pars(18);
  Freq_max          = CP_Pars(19);
  Freq_total        = CP_Pars(20);
  Prefilter_center  = CP_Pars(21);
  Spectral_range    = CP_Pars(22);
  Freq_kernel_min   = CP_Pars(23);
  Freq_kernel_max   = CP_Pars(24);
  Time_kernel_before       = CP_Pars(25);
  Time_kernel_before_type  = CP_Pars(26);
  Time_warp_fact    = CP_Pars(27);
  DCTC_warp_fact    = CP_Pars(28);
  BVF_norm_flag     = CP_Pars(29);
  BVT_norm_flag     = CP_Pars(30);
  Num_features      = CP_Pars(31);
  Add_frames_flag   = CP_Pars(32);
  bias              = CP_Pars(33);
  ip_lpc            = CP_Pars(35);


%  For control of sigmoid for nonlinear amplitude scaling
   a_sigmoid        = CP_Pars(37);
   b_sigmoid        = CP_Pars(38);   % called spare1  and spare2 in setup

   if (a_sigmoid < .1)
       a_sigmoid = .1;
   end;


  %% Warping parameters
  Time_warp_fact2   = CP_Pars(39);
  Frame_length2     = CP_Pars(40);
  Frame_length3     = CP_Pars(41);
  Freq_bound1       = CP_Pars(42);
  Freq_bound2       = CP_Pars(43);
  En_norm_flag      = CP_Pars(44);
  DCTC_warp_fact1   = CP_Pars(45);
  DCTC_warp_fact2   = CP_Pars(46);
  Time_warp_fact1   = CP_Pars(47);
  vary_frm_len      = CP_Pars(48);
  plot_spec         = CP_Pars(49);
  Block_length_end  = CP_Pars(50);
  shf               = CP_Pars(51);
  CP_PITCH          = CP_Pars(52);
  
  Log_Energy_Flag   = LogEnergy(1);
  EnergyFloor_logE  = LogEnergy(2);
  ENERGYFLOOR_LogE  = LogEnergy(3);

  % these 2 variables used to limit spectral range
  Spectral_floor = 10^(Spectral_range/20);
  if Spectral_floor > 200 
      Bias_value = 1;        % ie, range greater than 47db
  else
      Bias_value = 100;
  end

  
  % now perform initialization using the information obtained from above

  Kaiser_window = comp_kaiser(Frame_length, KaiserWnd_beta);
  

%   Compute basis vectors over frequency
%   Note these are the same for either DCTC1 or DCTC2 processing



%figure(1);
%plot(bvF(:,1:3));title('Test Graph to show the first 3 Basis Vectors');
%legend('BV0','BV1','BV2');
%pause

    N_freq = Freq_max-Freq_min + 1;

    parms = [N_freq,DCTC_warp_fact, DCTC_warp_fact1, DCTC_warp_fact2];

    [bvF,f,g,h] = genbv(Num_DCTC,Fwarp, parms, BVF_norm_flag);

    delta = g/g(1);
    delta1 = 1 + N_freq*h;

%    figure(1)
%    plot(delta)
%    title('delta')
%    pause

%    figure(2)
%    plot(delta1)
%    title('delta1')
%    pause


%figure(1)
%plot(f)
%pause

%figure(2)
%plot(g)
%pause

%figure(3);

%plot(bvF(:,1:3));title('Test Graph to show the first 3 Basis Vectors over F');
%legend('BV0','BV1','BV2');

%pause


 if ( vary_frm_len == 1)

    init = 0;

          fullDelta(1:Freq_min-1) = delta(1);
          fullDelta(Freq_min:Freq_max) = delta;
          fullDelta(Freq_max+1:FFT_length) = delta(end);


    [Frame_FFT,uni_frame_lengths,frame_lengths]  = specb([], FFT_length, fullDelta,...
    Frame_length,Frame_length2,init,[],[]);

 end;


%figure(3);
%plot(bvT(:,1:3));title('Test Graph to show the first 3 Basis Vectors');
%legend('BV0','BV1','BV2');
%pause



  if (CPFeatType == 'DCTC1')   % compute  basis vectors over time


%   Twarp should be either 'K'  or 'G'  or 'S" as of Nov 30, 2008
%   For 'K'  Time_warp_fact should be from 0 to 25
%   for 'G', Time_warp_fact shoud be .01 to 10

    N_frames = Block_length_beg;
   if (N_frames > 1)
     
    % Shifting factor 'shf' needed by the last 
    parms= [N_frames,Time_warp_fact, Time_warp_fact1, Time_warp_fact2, shf]; 
    
    [bvT,f,g,h] = genbv(Num_DCS,Twarp, parms, BVT_norm_flag);

   end;
   
   
%  Do not need basis vectors over time if only 1  frame per block
%  Note that above really  assumes there is only 1 block length
%   that is, that Block_length_beg = Block_len_max;

  end   %  end of basis vectors over time section for DCTC1




  %% Compute basis vectors for DCTC2 processing

  if (CPFeatType == 'DCTC2')

  Block_length = Block_length_beg;
  N_freq = Freq_max - Freq_min + 1;


%   Be sure that Block_length is an odd number

   if ( (Block_length/2 - fix(Block_length/2)) == 0)
      Block_length = Block_length-1;
      Block_length_beg = Block_length_beg-1;
      warning('cp_feat.m -> Block length reduced by 1 frame!');
   end;


%    Note basis vectors over frequency already computed

     BvF = bvF;   %??   BvF needed for DCTC2--  why two versions of this?

 BvT_ff = zeros(Block_length,Num_DCS);
 BvT    = zeros(N_freq,Block_length, Num_DCS);

 
% YYI = zeros(N_freq,Block_length);
% XXI = zeros(N_freq,Block_length);
% for i = 1:Block_length
% for j = 1:N_freq
%     YYI(j,i) = j;
% end
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%  Use Block_length_max and Block_length_beg and fixed time warping factor
%  to control time resolution over frequency,    applied on to BVT
if (Block_length_beg < Block_length_end)
    Block_length_end = Block_length_beg;
end

Block_df = (Block_length_beg-Block_length_end)/2./N_freq;

  for f = 1:N_freq
      
       Block_per = fix(Block_df*f);   
    
       parms= [Block_length - Block_per*2, Time_warp_fact, Time_warp_fact1,Time_warp_fact2,shf];
           
       [BvT_ff,ff,g,h] = genbv(Num_DCS, Twarp, parms, BVT_norm_flag);

       z_blk = zeros(Block_per,Num_DCS);

       BvT_ff = [z_blk; BvT_ff; z_blk];
      
       BvT(f,:,:) = BvT_ff(:,:);
    end;

    
    
  %figure(3)
  %mesh(BvT(:,:,1))
  %pause
end    %   end of basis vectors for DCTC2 method



  %% Compute basis vectors over time for DCTC3 processing

  if (CPFeatType == 'DCTC3')


%    Note basis vectors over frequency already computed

     BvF = bvF;   %??   BvF needed for DCTC2--  why two versions of this?

  Block_length = Block_length_beg;


%   Be sure that Block_length is  odd number

   if ( (Block_length/2 - fix(Block_length/2)) == 0)
      Block_length = Block_length-1;
      Block_length_beg = Block_length_beg-1;
      Block_length_max = Block_length_beg;

      warning('cp_feat.m -> Block length reduced by 1 frame!');
   end;


%     compute basis vectors over time,  one set for each DCTC

%     assume that we have time_warp(i), desired time warp for each dctc
%     also have N_DCS(i)   Num of DCS desired for each DCTC


%    *******************************************************

%      For initial tests
      for i = 1:Num_DCTC
         N_DCS(i) = Num_DCS;
         Time_warp(i) = Time_warp_fact;
      end;


%     Second attempt at varying DCS warping factor

        N_freq = Freq_max-Freq_min + 1;

        parms = [N_freq,DCTC_warp_fact1 DCTC_warp_fact1, DCTC_warp_fact2,shf];

    [bvFF,f,g,h] = genbv(Num_DCTC,Fwarp, parms, BVF_norm_flag);



      N_freq1 = length(g);

      spacing = (1:Num_DCTC)*(N_freq1/Num_DCTC);

      warp_time = interp1(g,spacing);
      warp_time= warp_time/ (max(warp_time));
      warp_time = 1./warp_time;

       for i = 1:Num_DCTC
         Time_warp(i) = Time_warp_fact*warp_time(i);
      end;


%     ******************************************************


%     Section above  between ****  should be replaced

%     Should come up  with a way to create a family of warping curves
%     One curve for each DCTC
%     Curves for higher ordered DCTCs  should be more peaky
%     and potentially  not centered in interval


%    we compute Num_DCS basis vector for each DCTC

     for i_DCTC = 1:Num_DCTC

     warp_tf = Time_warp(i_DCTC);
      
     parms= [Block_length,warp_tf, Time_warp_fact1, Time_warp_fact2, shf];

     [BvT_ff,ff,g,h] = genbv(Num_DCS,Twarp, parms, BVT_norm_flag);

      warp_t2= 1 + (Block_length-1)*h;


      bvT(:,:,i_DCTC) = BvT_ff(:,:);


    end;



end    %   end of basis vectors for DCTC3 method



  % format return arrays
  OutPars(1) = Segment_length;
  OutPars(2) = Sample_rate;
  OutPars(3) = Blocks_max;
  OutPars(4) = Num_features;
  OutPars(5) = Frame_jump;  % need for HTK file
  OutPars(6) = Block_jump;  % need for HTK file
  
  OutFloats(1) = Segment_length*1000/Sample_rate;
  OutFloats(2) = 0; % segment_energy is 0 for now
  OutFloats(3) = Prefilter_center;
  
  Feat = [];
  
 case 'FREE' % termination mode, may not need for Matlab
             % TODO: add termination code here
  Feat      = [];
  OutPars   = [];
  OutFloats = [];
  
 otherwise
  error('Unknown cp_feat command: %s!', DoWhat);
  return;
end % end switch DoWhat
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              