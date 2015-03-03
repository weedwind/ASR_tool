function [Feat, OutPars]  = cp_feat(DoWhat, X, SpecFile,InitPars)


% Inputs
%   DoWhat        -- command in string array format ('init', 'proc', 'cont', 'free')
%   X             -- a column matrix contains input speech samples
%   SpecFile      -- name of feature computation specifications file
%   InitPars      -- a column matrix contains integer parameters needed for feature computation
%   InitPars(1)   -- Sampling rate
%   InitPars(2)   -- Segment length

% Outputs:
%   Feat           -- output features which are stored in rowwise
%                     (number of columns in Feat = number of frames (blocks))
%   OutPars        -- a column matrix contains integer output parameters
%   OutPars(1)     -- Sampling rate
%   OutPars(2)     -- Frame space ( in samples )
%   OutPars(3)     -- Block jump ( in frames )




% add static variable names here
persistent Use_term bvF bvT
persistent Kaiser_window
persistent Spectral_floor

% the following are variables used to store feature computation specifications
persistent Sample_rate FFT_length
persistent KaiserWnd_beta Num_DCTC Num_DCS Frame_length Frame_jump
persistent Block_length Block_jump
persistent Low_freq_limit High_freq_limit Freq_min Freq_max Freq_total
persistent Prefilt_Center_Freq Spectral_range
persistent BVF_norm_flag BVT_norm_flag 
persistent Num_features
persistent EnergyFloor_logE ENERGYFLOOR_LogE Log_Energy_Flag Log_Expand_Flag
persistent Static_Warp_factor Time_warp_fact
persistent plot_spec 
persistent Numb_filters Width_gammatone
persistent Tracker_type Pitch_Normalization All_part_voice_yappt
persistent Delta_window_length Accelator_window_length Delta3_window_length
persistent Pitch_Flag
persistent Amplitude_scaling
persistent DCTC_type Static_warp_type
persistent Dyn_Type Time_warp_type

epsilon = .0001;   %  lower limit to avoid log(0);


% variable for processing in realtime
persistent ix % index to input speech samples
switch upper(DoWhat)
    case 'PROC'
        
         % First do pre-emphasize
        if Prefilt_Center_Freq > 0 % no filtering if center freq = 0
            X = PreFilt('proc', X, length(X));
        end   % End pre-emphasis
         
        if Pitch_Flag
            [FinPitch, numframes,frmrate] = pitch_track(X, Sample_rate, All_part_voice_yappt,[],0,Tracker_type);     % Compute pitch
            % Normalize pitch
            if strcmp(Pitch_Normalization, 'MEAN')
                FinPitch=FinPitch-mean(FinPitch);
            else
                if strcmp(Pitch_Normalization, 'VARIANCE')
                    FinPitch=FinPitch./std(FinPitch);
                else
                    if strcmp(Pitch_Normalization, 'BOTH')
                        FinPitch=(FinPitch-mean(FinPitch))./std(FinPitch);
                    end
                end
            end   
        end
        
        DataLen = length(X);
        % find total number of frames
        if DataLen < Frame_length
            disp ([sprintf('cp_feat.m -> Error: DataLen < frame_length!')])
            Feat = [];
            return
        end
        
        
        
        % DC removal
        X = X-mean(X);
        
                
        NumFrm = 1 + fix((DataLen - Frame_length)/Frame_jump);
        Seg_spectrum  = zeros(FFT_length/2+1, NumFrm);
        
        
        %----------------------------------------- Begin compute sepctrum-------------------------------------------------------------
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
            
            
            Frame_FFT = fft(Frame_dataW, FFT_length); % perform FFT
            Frame_FFTmag = (abs(Frame_FFT(1:FFT_length/2+1))).^2; % from 0 to Fs/2+1
            
            % compute spectrum magnitude over selected freq range
            % put limit to lower level of the spectrum
            PeakVal = max(Frame_FFTmag);
            FloorVal = PeakVal/Spectral_floor^2;
            
            if FloorVal < epsilon
                FloorVal = epsilon;
            end
            [idx] = find(Frame_FFTmag < FloorVal);
            Frame_FFTmag(idx) = FloorVal;
            
            if isempty(Amplitude_scaling)      % Amplitude scaling
                Frame_logmag = log(Frame_FFTmag );      % Take log
            else
                Frame_logmag = (Frame_FFTmag) .^ (Amplitude_scaling);  %Take power
            end
            Seg_spectrum(:,i)=Frame_logmag;
        end
        
        %%%% Plot Spectrogram %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if plot_spec
            [nrow, ncol] = size(Seg_spectrum);
            % x and y axes
            tt_spec = linspace(0, (ncol-1), ncol);
            ff_spec = linspace(0, Sample_rate/2, nrow);
            figure(1);
            imagesc(tt_spec, ff_spec, Seg_spectrum);
            xlabel('Time (Frame  No)');
            ylabel('Frequency (Hz)');
            title( ' Spectrogram after nonlinear amplitude scaling ');
            
            axis xy;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %----------------------------------------- End compute sepctrum-------------------------------------------------------------
        
        
        % Add extra frames to account for block length
        
        % how many extra frames need to be added
        
        NumExtraFrm = fix(Block_length /2);
        First_vect = Seg_spectrum(:,1);
        Last_vect  = Seg_spectrum(:, size(Seg_spectrum, 2));
        num_column_ini=size(Seg_spectrum,2);               % Original number of frames
        Seg_spectrum = [repmat(First_vect, 1, NumExtraFrm) Seg_spectrum...
            repmat(Last_vect, 1, NumExtraFrm+Block_jump-1)];
        
        
        
        % ------------------------------------------------- Compute Static Features -----------------------------------------------
        
        Frame_feat = bvF * Seg_spectrum;                      % Frame_feat has been expanded already
        
        if Pitch_Flag                                            % Add pitch row
            Q         =  length(FinPitch);
            P         =  num_column_ini;                          % P is the original number of frames before expansion
            XX = (0:Q-1)/(Q-1);
            XI = (0:P-1)/(P-1);
            Frame_feat1 =  interp1(XX,FinPitch,XI,'linear');
            
            
            %At this point, pitch track has been interpolated to be same
            %length as number of computed spectral frames
            
            %Now we need to  extend the beginning and end of the pitch
            %to account for end effects with the block processing
            
            First_vect = Frame_feat1(1);
            Last_vect  = Frame_feat1(P);
            Frame_feat1  = [repmat(First_vect, 1, NumExtraFrm) Frame_feat1...
                repmat(Last_vect, 1, NumExtraFrm+Block_jump-1)];
            Frame_feat=[Frame_feat;Frame_feat1];                   % Put pitch feature after basic DCTC
        end
        
        
        if Log_Energy_Flag                                          % Add log energy row
            
            Y = LogEnergy_Frame_data;
            Y = (Y - mean(Y))/std(Y);            % Normalize energy
            if Log_Expand_Flag
                P = num_column_ini;
                First_vect = Y(1);
                Last_vect  = Y(P);
                Y  = [repmat(First_vect, 1, NumExtraFrm) Y...
                    repmat(Last_vect, 1, NumExtraFrm+Block_jump-1)];
                Frame_feat=[Frame_feat;Y];                            % Put log energy after basic DCTC and pitch (if there is )
            end
        end
        
        % ----------------------------------------- End of Static Feature Computation  ---------------------------------------------------------------
        
        
        % ----------------------------------------- Next, Begin computing dynamic features------------------------------------------------------------
        
        %  First, determine # of blocks to process
        
        NumBlk = fix(1 + (NumFrm-1) / Block_jump);
        
        NumFrm_padded = length(Seg_spectrum);
        if NumFrm_padded < Block_length
            warning('cp_feat.m -> Too few frames to form one block!');
            Feat = [];
            return
        end
        
        % fixed block size  no longer has option for variable block length
       
            if (Block_length == 1 && Block_jump == 1 && Num_DCS == 1)    % get only the DCTC's
                Feat = Frame_feat;
                if Log_Energy_Flag       % Process Log energy
                    if Log_Expand_Flag==0  % to replace the last feature by log energy
                        if Pitch_Flag        % to protect pitch from being replaced
                            Feat=[Feat;Y]; % to append log energy after pitch instead of replacing pitch
                            warning(sprintf('You only have 1 pitch-related feature, log energy will be appended in the final feature matrix'));
                        else
                            Feat(end,:)=Y;  % otherwise, replace the last DCTC feature
                        end
                    end
                end                         % End processing log energy for this case
                
            else
                % first check valid number of features
                if (Num_features==0)
                    warning(sprintf('Wrong format of Use_term, can not turn off all features'));
                    return;
                end
                Feat = zeros(Num_features, NumBlk);     % Initialize feature matrix
                Num_features1  = (Num_DCTC+Pitch_Flag+Log_Energy_Flag*Log_Expand_Flag)*Num_DCS;      % Get all DCS terms first
                Feat1 = zeros(Num_features1, NumBlk);
                
                iFrame = 1;
                for iBlk = 1:NumBlk
                    Feat_blk  =  Frame_feat(:, iFrame:iFrame+Block_length-1);
                    temp =  Feat_blk(:,:) * bvT(:, :, 1);
                    temp1 = reshape(temp.',1,Num_features1);
                    Feat1(:, iBlk) = temp1;
                    iFrame = iFrame + Block_jump;
                end
                
                
                
                if (Num_features1 == Num_features)  %  all terms used
                    Feat = Feat1;
                    
                else                               % Not all terms are used
                    sum_term = 0;                        % Now we  must select the terms actually needed, and copy from Feat1  to Feat
                    iFeat = 1;
                    for ii = 1:Num_features1
                        sum_term = sum_term+Use_term(ii);
                        if (sum_term == iFeat)
                            Feat(iFeat,:) = Feat1(ii,:);
                            iFeat = iFeat+1;
                        end
                    end
                end
                
                if Log_Energy_Flag                % Process Log Energy for this case
                    if Log_Expand_Flag==0         % to replace the last feature by log energy
                        XX = (1:NumFrm)/NumFrm;
                        XI = (1:NumBlk)/NumBlk;
                        Y =  interp1(XX,Y,XI,'linear');    % Interpolate to have the same length as NumBlk
                        if Pitch_Flag               % to protect pitch feature from being replaced if there is only one such feature
                            if (sum(Use_term(Num_DCTC*Num_DCS+1:end))==1)
                                Feat=[Feat;Y];     % do not replace the only pitch feature
                                warning(sprintf('You only have 1 pitch-related feature, log energy will be appended in the final feature matrix'));
                            else
                                Feat(end,:)=Y;     % otherwise, replace the last feature with log energy
                            end
                        else
                            Feat(end,:)=Y;
                        end
                    end
                end                  % End processing log energy for this case
                
            end
            
       
        
        % ---------------------------------------- End of dynamic feature computation -----------------------------------------------------------------
        
        
        
        
        
        
        
        
    case 'CONT' % for realtime mode or processing with short segments
        % TODO: add code here
        
    case 'INIT' % initialization mode
        
        
        [CP_Pars, Use_term, LogEnergy, CP_Pars_char] = rd_spec(SpecFile, InitPars);
        
        % store specifications
        Sample_rate       = CP_Pars(1);
        FFT_length        = CP_Pars(2);
        KaiserWnd_beta    = CP_Pars(3);
        Num_DCTC          = CP_Pars(4);
        Num_DCS           = CP_Pars(5);
        Frame_length      = CP_Pars(6);
        Frame_jump        = CP_Pars(7);
        Block_length      = CP_Pars(8);
        Block_jump        = CP_Pars(9);
        Low_freq_limit    = CP_Pars(10);
        High_freq_limit   = CP_Pars(11);
        Freq_min          = CP_Pars(12);
        Freq_max          = CP_Pars(13);
        Freq_total        = CP_Pars(14);
        Prefilt_Center_Freq  = CP_Pars(15);
        Spectral_range    = CP_Pars(16);
        Time_warp_fact    = CP_Pars(17);
        Static_Warp_factor= CP_Pars(18);
        BVF_norm_flag     = CP_Pars(19);
        BVT_norm_flag     = CP_Pars(20);
        Num_features      = CP_Pars(21);
        All_part_voice_yappt= CP_Pars(22);
        plot_spec         = CP_Pars(23);
        shift_deg_NonSym  = CP_Pars(24);
        Pitch_Flag        = CP_Pars(25);
        Numb_filters      = CP_Pars(26);
        Width_gammatone   = CP_Pars(27);   
        Delta_window_length = CP_Pars(28);
        Accelator_window_length = CP_Pars(29);
        Delta3_window_length    = CP_Pars(30);
        
        
        %% Character values of parameters
        Amplitude_scaling = str2num(CP_Pars_char{1});
        DCTC_type         = CP_Pars_char{2};
        Static_warp_type  = CP_Pars_char{3};
        Dyn_Type          = CP_Pars_char{4};
        Time_warp_type    = CP_Pars_char{5};
        Tracker_type      = CP_Pars_char{6};
        Pitch_Normalization = CP_Pars_char{7};
        
        Log_Energy_Flag   = LogEnergy(1);
        EnergyFloor_logE  = LogEnergy(2);
        ENERGYFLOOR_LogE  = LogEnergy(3);
        Log_Expand_Flag   = LogEnergy(4);
        
        
        if strcmp(Static_warp_type(1:3),'BIL')
            Fwarp = 'B';
        end
        if strcmp(Static_warp_type(1:3),'MEL')
            Fwarp = 'M';
        end
        if strcmp(Static_warp_type(1:3), 'NON')
            Fwarp = 'N';
        end

        if strcmp(Time_warp_type(1:6), 'EXPONE')
            Twarp = 'E';
        end

        if strcmp(Time_warp_type(1:6), 'KAISER')
            Twarp = 'K';
        end

        if strcmp(Time_warp_type(1:6), 'GAUSSI')
            Twarp = 'G';
        end

        if strcmp(Time_warp_type(1:6), 'SIGMOI')
            Twarp = 'S';
        end

        if strcmp(Time_warp_type(1:6), 'NONSYM')      %option to use Asymmetric Gaussian window
            Twarp = 'N1';
        end
        
        
        if (All_part_voice_yappt <0) 
            All_part_voice_yappt = 0;  
        end
        
        if (All_part_voice_yappt >1)
            All_part_voice_yappt = 1;
        end
        
        % Initialize pre-filtering routine
        
        if Prefilt_Center_Freq > 0        % no filtering if center freq = 0
            PreFilt('init', Prefilt_Center_Freq, Sample_rate);
        end
        
        
        % this variables used to limit spectral range
        Spectral_floor = 10^(Spectral_range/20);
        
        
        
        % now perform initialization using the information obtained from above
        
        Kaiser_window = comp_kaiser(Frame_length, KaiserWnd_beta);
        
        
         % Compute filterbank weights
        [W,C]=genfw(DCTC_type,Sample_rate,FFT_length,Numb_filters,Low_freq_limit,High_freq_limit,Freq_min, Freq_max,Width_gammatone );
        
        
        %  Compute basis vectors over frequency
        
        %  At this point, filterbank weights have not been considered
        parms = [Freq_total,Static_Warp_factor, Static_Warp_factor, Static_Warp_factor];
        
        [bvF,f,g,h] = genbv(Num_DCTC,Fwarp, parms, BVF_norm_flag);
        
        % Now, combine with filterbank weights
        bvF=(bvF')*W;              % Each row is a combined basis vector;
        
        
        
        if (strcmp(Dyn_Type,'DCS'))   % compute  basis vectors over time
            
            if (Block_length > 1)
                
                % Shifting factor 'shift_deg_NonSym' needed by the last
                parms= [Block_length,Time_warp_fact, Time_warp_fact, Time_warp_fact, shift_deg_NonSym];
                
                [bvT,f,g,h] = genbv(Num_DCS,Twarp, parms, BVT_norm_flag);
            else
                bvT=[];
                
            end
                        
        end   %  end of basis vectors over time section for DCS
        
        
        % Compute basis vectors over time for delta method
        
        if strcmp(Dyn_Type,'DELTA')
            % Next, form basis vectors
            
            IP=Num_DCS-1;    % IP is the number of basis vector needed
            
            if IP==1      % one basis vector
                parms=[Delta_window_length];
            end
            
            if IP==2      % two basis vector
                parms=[Delta_window_length,Accelator_window_length];
            end
            
            if IP==3      % three basis vector
                parms=[Delta_window_length,Accelator_window_length,Delta3_window_length];
            end
            
            
            if IP~=0
                parms=[Block_length,parms];
                [bvT,f,g,h] = genbv(IP,'d', parms, 0);
            else
                bvT=[];
            end
            
        end      % end DELTA
        
        
        
        % format return arrays
        
        OutPars(1) = Sample_rate;
        OutPars(2) = Frame_jump;  % need for HTK file
        OutPars(3) = Block_jump;  % need for HTK file
        Feat = [];
        
    case 'FREE' % termination mode, may not need for Matlab
        % TODO: add termination code here
        Feat      = [];
        OutPars   = [];
        
    otherwise
        error('Unknown cp_feat command: %s!', DoWhat);
        return;
end % end switch DoWhat
                                                                   