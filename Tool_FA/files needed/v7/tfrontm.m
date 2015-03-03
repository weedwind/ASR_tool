function tfrontm(CmdFile,Wave_List,Feat_List,Feat_folder)

% Setup some constants
DEFAULT_COMMAND_FILE = 'TFRONT.DAT'; % default name of command file which will be used if
MAX_SNR              = 200;          % if SNR >= MAX_SNR, do not add noise

DEFAULT_WaveList='lists\wavefile.lst';   % default wavefile list;
DEFAULT_FeatList='lists\featfile.lst';   % default feature file list;
DEFAULT_FeatFolder='data\Feat';          % default feature folder;

% Step 0 - Perform initializations
if nargin == 0
   CmdFile = DEFAULT_COMMAND_FILE;
   Wave_List=DEFAULT_WaveList;
   Feat_List=DEFAULT_FeatList;
   Feat_folder=DEFAULT_FeatFolder;
end

if nargin ==1
   Wave_List=DEFAULT_WaveList;
   Feat_List=DEFAULT_FeatList;
   Feat_folder=DEFAULT_FeatFolder;
end

if nargin==2
    Feat_List=DEFAULT_FeatList;
    Feat_folder=DEFAULT_FeatFolder;
end

if nargin==3
    Feat_folder=DEFAULT_FeatFolder;
end

iTok=1;
NumSenInGrp=1;


%  Step 1 - Read TFRONT.DAT



[SNR, FileType, FeatSpecFile, ParmType] = rd_tfront(CmdFile);

% Processing each sentence
InitFlag = 1;
PSample_rate = 0;

fin=fopen(Wave_List,'rt');
if fin==-1
    error(sprintf('Can not open wave file list %s',Wave_List));
end

iSen=0;  % sentence counter

fout=fopen(Feat_List,'wt');
if fout==-1
    error(sprintf('Can not open feature file list %s', Feat_List));
end

while ~feof(fin)
  % Get name of each speech file 
  line =strtok(fgetl(fin));
  if ~isempty(line)          % This is a wave file name
      SpeechFile=line;
      iSen=iSen+1;
      disp(sprintf('\n Processing file %s # %d', SpeechFile, iSen));
       
      % Read each speech file
      [DataA, Sample_rate, LenDataA] = rd_audio(SpeechFile);
      
      if (isempty(DataA) || (LenDataA==0))   
          error('TFRONTM -> No data read');
      end
      
      % If the file is RAW/NOHEAD, must set Fs in rd_audio()
      if ( Sample_rate == 0)
          warning('TFRONTM -> Must use sampling rate in cp_feat setup file');
      end
      
      % check if sampling rate has changed
      if (Sample_rate ~= PSample_rate)         
          PSample_rate = Sample_rate;
          InitFlag = 1;
          disp(sprintf('TFRONTM -> Sampling rate be changed to %d',PSample_rate));
      end
      
      if InitFlag         
          % Initialize feature computation routine with new sampling rate

          CP_InitPars      = [Sample_rate, LenDataA]; % use new sample rate

            [Dummy, CP_OutPars] = cp_feat('init', [], FeatSpecFile, CP_InitPars);
         
          
          Sample_rate      = CP_OutPars(1);
          Frame_jump       = CP_OutPars(2);
          Block_jump       = CP_OutPars(3);          
          FrmRate          = (Block_jump*Frame_jump)*1000/Sample_rate;

          InitFlag = 0;          % End initialization tfrontm.
      end
      
      % Add noise
      if SNR < MAX_SNR       
          % add noise if specified SNR is less than MAX_SNR dB
          DataA = AddNoise(DataA(1:LenDataA), SNR);
      end
            
      [Feat] = cp_feat('proc', DataA,[],[]);
     
      if isempty(Feat)
          warning('No features be calcuated for %s', SpeechFile); 
          continue;
      end
      
      if ~exist(Feat_folder,'dir')
          mkdir(Feat_folder);
      end
      % get output file path
      idx = strfind(SpeechFile, '\');
      if ~isempty(idx)
          fname = strtok(SpeechFile(idx(end)+1:end), '.');
      else
          fname=strtok(SpeechFile,'.');
      end
      outFile = fullfile(Feat_folder, [fname, '.mfc']);        % Output feature file path
       
      % Write feature into file
      wr_feat(outFile, FileType, Feat, iTok, NumSenInGrp, FrmRate, ParmType, SpeechFile);
      disp(sprintf(' Output file %s generated (%dx%d)', outFile, size(Feat)));
      
      % Generate output feature file list
      fprintf(fout, '%s\n', outFile);
  end
end
fclose(fin);
fclose(fout);

end
      
      
      

      
      
      
      
  
  
 


