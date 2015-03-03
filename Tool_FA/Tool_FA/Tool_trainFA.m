function [] =Tool_trainFA(CmdFile)
% This is the tool to train a initial set of HMM models for forced alignment step.
% Generally, the INPUTs are:
   % 1. Feature files extracted from the previous step
   % 2. Word level transcriptions. One transcription file for each 
   %    sentence, and one word in each rwo.
   % 3. A pronunciation dictionary. This dictionary needs be sorted in 
   %    alphabetical order and fully covers all the words in the training 
   %    transcriptions. This dictionary needs to have a "sp" after each entry.
   %    "sp" will be used as an interword short pause. In addition to all the
   %    words, you need to add these entries also in sorted order:
   %    SENT_Boundary sil
   %    SENT_END [] sil
   %    SENT_START [] sil
   %    where "sil" means a sentence boundary silence model.
% Generally, the OUTPUTs are:
   % 1. A set of initially trained monophone HMM models
   % 2. A list of these HMM models.
   % 3. A progress report. Default to progress_trainFA.log
% INPUTs of this function:
   % A setup file. Default to Tool_trainFA.dcf
% OUTPUTs of this function: None

% Global Variables
global aOptStr;              % This sets the trace level
global aClnFlg;              % This sets if the target hmm folder will be cleaned before use
aOptStr     = '-A -T 1 ';    % Default is to show the progress
aClnFlg     = 0;             % Default is to disable cleaning up
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_trainFA.dcf'; % This is the default setup file for this program.

%-- Global Initialization -------------------------------------------------------
if (nargin == 0)
    CmdFile = defCmdFile;
end

% Reads Test Config File 
CPS = ReadTCF(CmdFile);      % reads in the setup file

% Set runing options
if(upper(CPS.Trace_on)=='N')
   aOptStr = ' -A ';
end

% CleanUp: Clear target folder in each training step
if(upper(CPS.Clean_up)=='Y')
    aClnFlg = 1;
else
    aClnFlg = 0;
end
if ~exist(CPS.LogDir,'dir')
    mkdir(CPS.LogDir);
end
LogFile = fullfile(CPS.LogDir, 'progress_trainFA.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Start Training Module for FA (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Global Initialization -----------------------------------------------------------

% ------------ Next, begin transcription preparation ----------------------------------------
if (upper(CPS.Trans_prep)== 'Y')
    msg=sprintf('First, prepare transcriptions for training');
    UpdateLogFile(LogFile,msg);
    if (upper(CPS.Gen_Word_MLF)== 'Y')
        msg=sprintf('Convert word transcriptions to word MLF');
        UpdateLogFile(LogFile,msg);
        [rt, msg] = word2mlf(CPS.Word_trs_list, CPS.WordMLF, CPS.Conf_wrdmlf);
        if rt, UpdateLogFile(LogFile,msg);return; end
    else
        if (upper(CPS.Gen_Word_MLF)== 'N')
            msg=sprintf('No conversion from word transcription to word MLF');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose between Y and N');
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
    end
    if (upper(CPS.Gen_Phn_MLF)== 'Y')
        msg=sprintf('Convert word MLF to phone MLF');
        UpdateLogFile(LogFile,msg);
        [rt1,rt2,msg1,msg2]=word2phn(CPS.WordMLF, CPS.Dict, CPS.PhoneMLF_nosp, CPS.PhoneMLF_sp, CPS.PhoneList_nosp,...
                                     CPS.PhoneList_sp, CPS.Conf_wrd2phn_nosp, CPS.Conf_wrd2phn_sp);
        if rt1, UpdateLogFile(LogFile,msg1); return; end
        if rt2, UpdateLogFile(LogFile,msg2); return; end
    else
        if (upper(CPS.Gen_Phn_MLF)== 'N')
            msg=sprintf('No conversion from word MLF to phone MLF');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose between Y and N');
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
    end
else
    if (upper(CPS.Trans_prep)== 'N')
        msg=sprintf('No preparation of transcriptions for training');
        UpdateLogFile(LogFile,msg);
    else
        error('You must choose between Y and N');
    end
end
% ------------------ End transcription preparation ---------------------------------------------

% --------------------- Begin model training -----------------------------------------

if (upper(CPS.Train_on)== 'Y')
    msg=sprintf('Training enabled');
    UpdateLogFile(LogFile,msg);
    % dermine number of mixtures and number of training iteration (for HERest)
    % since user can specify sequence of mixtures so we need to decode
    % this from the setup file
    num_mix = decode_seq(CPS.numMixture);
    herestIter = decode_seq(CPS.Iteration);
    % Do some validation checking
    if isempty(num_mix) || isempty(herestIter) || (length(num_mix) ~= length(herestIter))
          msg = sprintf('  Wrong format of numMixture: and/or Iteration:,  Please correct your setup file: "%s"\n', CmdFile);
          HError(msg);
          UpdateLogFile(LogFile, msg);
          return
    end
    msg = sprintf('numMixture=%s, Iteration=%s',CPS.numMixture, CPS.Iteration);
    UpdateLogFile(LogFile, msg);
    
    if (upper(CPS.Init)== 'Y')                    % Flat start is enabled
        msg=sprintf('Start Initialization Using Global Mean and Variances');
        UpdateLogFile(LogFile,msg);
      % read one feature file to determine feature vector size
      % open list file and read the first entry
      fp = fopen(CPS.Feat_List, 'rt');
      if fp == -1
          msg = sprintf('  Cannot read %s', CPS.Feat_List);
          HError(msg);
          UpdateLogFile(LogFile, msg);
          return
      else
        feat_file = fgetl(fp);
        fclose(fp);
      end
      % read feature file
      [feat, frame_period, data_type, full_type_code, type_code_text] = readhtk(feat_file);
      % dimension of feature vector = number of columns
      num_var = size(feat, 2);
      msg = sprintf(' num_features=%d, numState=%s, numMixture=%s', ...
            num_var, CPS.numState, CPS.numMixture);
      UpdateLogFile(LogFile, msg);
      % generate HMM proto config file
      gen_hmm_pcf(num_var, str2num(CPS.numState), num_mix(1), type_code_text, CPS.Conf_proto);
      protoDir=CPS.SrcDir_init;
      tgtDir= CPS.TgtDir_init;
      [rt, msg] = HCompV(CPS.Conf_proto, CPS.hmmList_nosp, protoDir, tgtDir, CPS.Feat_List_ini, CPS.Conf_init);
      if rt, UpdateLogFile(LogFile, msg); return; end;
    else
       if (upper(CPS.Init)== 'N' )
          msg=sprintf('No model initialization');
          UpdateLogFile(LogFile,msg);
       else
           error('You must choose between Y and N for initialization');
       end
    end % End initialization
    
    if (upper(CPS.Embed_train)== 'Y')        % enable embedded training
        msg=sprintf('Start Embedded Training');
        UpdateLogFile(LogFile,msg);
        if ~exist(CPS.TgtDir_embd,'dir')
            mkdir(CPS.TgtDir_embd);
        end
        if aClnFlg
            if (~strcmp(CPS.SrcDir_embd,CPS.TgtDir_embd))
                delete(fullfile(CPS.TgtDir_embd,'*'));
            end
        end
        tgtDir=CPS.TgtDir_embd;
        if (~strcmp(CPS.SrcDir_embd,CPS.TgtDir_embd))
           copyfile(fullfile(CPS.SrcDir_embd,'hmmdefs'),fullfile(tgtDir,'hmmdefs'));
           copyfile(fullfile(CPS.SrcDir_embd,'macros'), fullfile(tgtDir,'macros'));
        end
        
        % check if "sp" model is already in hmmdefs
        found=0;
        fin=fopen(fullfile(tgtDir,'hmmdefs'),'rt');
        if (fin==-1)
            msg=sprintf('Can not open hmmdefs');
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
        str=sprintf('~h "sp"');
        while (~found && ~feof(fin))
            row=fgetl(fin);
            if strcmp(row,str)
                found=1;
            end
        end
        fclose(fin);
        if (found==1)                     % sp model already exists
            hmmList=CPS.hmmList_sp;       % hmm list forced to the one with sp
            monoMLF=CPS.monoMLF_sp;       % phone transcription forced to the one with sp
            CPS.fix_sil='n';              % Do not need to fix sil and sp again
            msg=sprintf('sp model already exist in hmmdefs');
            UpdateLogFile(LogFile,msg);
        else
            hmmList=CPS.hmmList_nosp;
            monoMLF=CPS.monoMLF_nosp;
            msg=sprintf('sp model has not been introduced');
            UpdateLogFile(LogFile,msg);
        end
            
        start_idx = 1;
        nIter = sprintf('%d', herestIter(start_idx));  % use first number of iterations
        msg=sprintf('Current number of mixtures= %d',num_mix(1));
        UpdateLogFile(LogFile,msg);
        
        % running HErest for the first round (num. iter. can be 0, nothing will happen)
        [rt, msg] = HERest(tgtDir, hmmList, CPS.Feat_List, monoMLF, ...
                           CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
          if rt, UpdateLogFile(LogFile, msg); return; end;
        start_idx = 2;
          
        % fix silence model and introduce sp model if needed
        if (upper(CPS.fix_sil)== 'Y')
            msg=sprintf('Now fix silence model and introduce sp model');
            UpdateLogFile(LogFile,msg);
            hmmList=CPS.hmmList_sp;                  % use sp hmmlist
            monoMLF=CPS.monoMLF_sp;                  % use sp MLF
            [rt,msg]=gen_sp(fullfile(tgtDir,'hmmdefs'));      % create sp model in hmmdefs
            if rt, UpdateLogFile(LogFile, [msg,'create sp model failed']); return; end;
            arg = sprintf('HHed %s -H %s\\macros -H %s\\hmmdefs %s %s', aOptStr, tgtDir, tgtDir,CPS.Conf_sil, hmmList);
            rt = system (arg);
            if rt
               msg = sprintf('  HHed (tie sil with sp) failed %d', rt);
               HError(msg);
               UpdateLogFile(LogFile, msg);
               return
            end
            nIter=CPS.fix_iter;
            % run HErest again a couple of iterations
            [rt, msg] = HERest(tgtDir, hmmList, CPS.Feat_List, monoMLF, ...
                           CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
            if rt, UpdateLogFile(LogFile, msg); return; end;
        else
            if (found== 1)                          % sp model already exist in previous step
               hmmList=CPS.hmmList_sp;              % hmm list forced to the one with sp
               monoMLF=CPS.monoMLF_sp;              % phone transcription forced to the one with sp
            end
            if (found== 0)                          % sp model never exists in previous steps
               hmmList=CPS.hmmList_nosp;
               monoMLF=CPS.monoMLF_nosp;
            end
        end
        
        % Next, splitting mixtures
       for i=start_idx:length(num_mix)
          nMix = num_mix(i);
          msg=sprintf('Current number of mixture= %d',nMix);
          UpdateLogFile(LogFile,msg);
          nIter =  sprintf('%d', herestIter(i));
          nState = str2num(CPS.numState);
          
          system(sprintf('echo MU %d {*.state[2-%d].mix}>split_mix.hed', nMix, nState+1));
          arg = sprintf('HHed %s -H %s\\macros -H %s\\hmmdefs split_mix.hed %s', aOptStr, tgtDir, tgtDir, hmmList);
          rt = system (arg);
          if rt
              msg = sprintf('  HHed (spliting mixture) failed %d', rt);
              HError(msg);
              UpdateLogFile(LogFile, msg);
              return
          end

          % running HErest 
          [rt, msg] = HERest(tgtDir, hmmList, CPS.Feat_List, monoMLF, CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
          if rt, UpdateLogFile(LogFile, msg); return; end;
      end % for splitting mixture
      if exist('split_mix.hed', 'file'), delete('split_mix.hed'); end;         
    else
        if (upper(CPS.Embed_train)== 'N')
            msg=sprintf('No Embedded Training');
            UpdateLogFile(LogFile,msg);
        else
            error('You must choose between Y and N for embedded training');
        end
    end     % End Embedded Training
    
    % Finally, make a folder to store final hmms
    if ( (upper(CPS.Init)=='Y') || (upper(CPS.Embed_train)== 'Y') )
        if ~exist(CPS.Final_hmmfolder,'dir')
            mkdir(CPS.Final_hmmfolder);
        else
            if aClnFlg
                delete(fullfile(CPS.Final_hmmfolder,'*'));
            end
        end
        copyfile(tgtDir,CPS.Final_hmmfolder);
        msg=sprintf('Copy HMM models from %s to %s',tgtDir,CPS.Final_hmmfolder);
        UpdateLogFile(LogFile,msg);
        msg=sprintf('%s\n','------------------ Training Completed -----------------');
        UpdateLogFile(LogFile,msg);
    end
else
    if (upper(CPS.Train_on)=='N')
        msg=sprintf('No Training');
        UpdateLogFile(LogFile,msg);
    else
        error('You must choose between Y and N for training')
    end
end    % End training
            
        

 % --------------------------------End Main --------------------------------------------------------

% **** Utility Functions **********************************************

% ReadTCF: Reads the Test Config File 
% Modified by Montri to read string variables that are inside ""
%-------------------------------------
function [configParams] = ReadTCF(configfile) 
valid = 0;

config = fopen(configfile, 'r');
while(~feof(config))
    str = fgetl(config);
    switch (str)
     case {'<ENDtool_steps>'}
      valid=0;
     case {'<BEGINtool_steps>'}
      valid=1;
     otherwise
      if (valid)
          [param, val] = strtok(str, ' :');
          if ((~isempty(param))&&(~strcmp(param(1),'%')))
             sf = strfind(val, ':');
             s = strtok(val(sf+1:end),' %');
             if (s(1) == '"') % string variable?
                val = val(sf+1:end);
                sf = strfind(val, '"'); % locate starting point
                s = strtok(val(sf+1:end), '"');
             end
             configParams.(param) = s;
          end
      end
    end
end
fclose(config);

% --------------------------------------------------------
% word2mlf: Convert plain word transcriptions to MLF format
% --------------------------------------------------------
function [rt, msg]= word2mlf(srclist, tgtfile, edfile)
global aOptStr;
rt=0;
msg='No Error';
tgtfolder=strtok(tgtfile,' \');
if ~exist(tgtfolder,'dir')
    mkdir(tgtfolder);
end
arg=sprintf('-i %s -l * -S %s %s', tgtfile, srclist, edfile);
rt= system(sprintf('HLEd %s %s', aOptStr, arg));
if rt
    msg= sprintf('Word to MLF failed %d', rt);
    HError(msg);
end

% ---------------------------------------------------------
% word2phn: Convert word MLF file to phone MLF file
% ---------------------------------------------------------
function [rt1, rt2, msg1, msg2]=word2phn(srcwmlf, dict, phonemlf_nosp, phonemlf_sp, phonelist_nosp,...
                                      phonelist_sp, edfile_nosp, edfile_sp)
global aOptStr;
rt1=0; msg1='No Error';
rt2=0; msg2='No Error';
arg_nosp= sprintf('-i %s -l * -d %s -n %s %s %s',phonemlf_nosp, dict, phonelist_nosp, edfile_nosp, srcwmlf);
rt1= system(sprintf('HLEd %s %s', aOptStr,arg_nosp));
if rt1
    msg1=sprintf('Word to phone MLF failed without sp %d', rt1);
    HError(msg1);
end
arg_sp= sprintf('-i %s -l * -d %s -n %s %s %s',phonemlf_sp, dict, phonelist_sp, edfile_sp, srcwmlf);
rt2=system(sprintf('HLEd %s %s', aOptStr, arg_sp));
if rt2
    msg2=sprintf('Word to phone MLF failed with sp %d', rt2);
    HError(msg2);
end

% decode sequence of number in text format (such as '1;2;4;8;16') 
% into an array of number ([1, 2, 4, 8, 16])
function out = decode_seq(seq)

out = [];

[num, tmp] = strtok(seq, ' ;,');
while ~isempty(num)
    out = [out, str2num(num)];
    [num, tmp] = strtok(tmp, ' ;,');
end

function gen_hmm_pcf(nvar, nstate, nmix, param_kind, out_file)

fp = fopen(out_file, 'wt');

fprintf(fp, '<BEGINproto_config_file>\n\n');

fprintf(fp, '<COMMENT>\n');
fprintf(fp, '   This PCF produces a single stream, %d mixture prototype system\n\n', nmix);

fprintf(fp, '<BEGINsys_setup>\n\n');

fprintf(fp, 'hsKind: P\n');
fprintf(fp, 'covKind: D\n');
fprintf(fp, 'nStates: %d\n', nstate);
fprintf(fp, 'nStreams: 1\n');
fprintf(fp, 'sWidths: %d\n', nvar);
fprintf(fp, 'mixes: %d\n', nmix);
fprintf(fp, 'parmKind: %s\n', param_kind);
fprintf(fp, 'vecSize: %d\n', nvar);
fprintf(fp, 'outDir: proto\n');
fprintf(fp, 'hmmList: lists/monlist\n\n');

fprintf(fp, '<ENDsys_setup>\n\n');

fprintf(fp, '<ENDproto_config_file>\n');

fclose(fp);


%-------------------------------------------------------------------
% HCompV: Calls HCompV tool to initialize HMM model from flat start
%-------------------------------------------------------------------        
function [rt, msg] = HCompV(proto, hmmList, protoDir, tgtDir, datList, hConf)
global aOptStr;
global aClnFlg;

rt = 0;
msg = 'No Error';

if ~exist(protoDir, 'dir')
    mkdir(protoDir); 
elseif aClnFlg
    delete(fullfile(protoDir,'*'));
end


if ~exist(tgtDir, 'dir')
    mkdir(tgtDir);
elseif aClnFlg
    delete(fullfile(tgtDir,'*'));
end

fin  = fopen(hmmList, 'r');
if (fin == -1)
    msg = sprintf('  Initialization (HCompV) failed: Cannot open hmmList (%s)', hmmList);
    HError(msg);
    return
end

hmm = fgetl(fin);  % read only first line (first model name)
fclose(fin);

% create just one prototype
system(sprintf('echo %s>tmp_hmm_list.txt', hmm));
makeProto(proto, 'tmp_hmm_list.txt', protoDir);
delete('tmp_hmm_list.txt');

arg = sprintf('HCompV %s -C %s -f 0.007 -m -S %s -M %s %s', aOptStr, hConf, datList, tgtDir, fullfile(protoDir,hmm));
rt = system (arg);
if rt
    msg = sprintf('  HCompV failed: %d', rt);
    HError(msg);
    return
end
% cloning all HMMs and put them in 'hmmdefs' and 'macros'
clone_hmmdefs(hmmList, hmm, tgtDir, tgtDir); 

% remove original model so that it will not be copied around
delete(fullfile(tgtDir, hmm));
if exist(fullfile(tgtDir,'vFloors'),'file')              % merge the macro with Vfloors
    f_floor=fopen(fullfile(tgtDir,'vFloors'),'rt');
    f_mac=fopen(fullfile(tgtDir,'macros'),'a');
    while ~feof(f_floor)
        row=fgetl(f_floor);
        fwrite(f_mac,sprintf('%s\n',row));
    end
    fclose(f_floor);
    fclose(f_mac);
end
    


function [] = clone_hmmdefs(hmm_list, src_model, src_dir, target_dir)
%function [] = clone_hmmdefs(hmm_list, src_model, src_dir, target_dir)
% clone macros and hmmdefs files from src_model
% input model stored in src_dir and output definition files will be stored
% in target_dir
%

fp_hmm = fopen(hmm_list, 'rt');

fp_def = fopen(fullfile(target_dir, 'hmmdefs'), 'wt');
fp_mac = fopen(fullfile(target_dir, 'macros'), 'wt');


fp_src = fopen(fullfile(src_dir, src_model), 'rt');
hmm_line = {};
nline = 0;
while ~feof(fp_src)
    s = fgetl(fp_src);
    hmm_line = [hmm_line {s}];
    nline = nline + 1;
end
fclose(fp_src);

% writing hmmdefs file
while ~feof(fp_hmm)

    % read model name
    hmm = fgetl(fp_hmm);
    fprintf(fp_def, '~h "%s"\n', hmm);

    % save them in MMF
    for j=5:nline
        fprintf(fp_def, '%s\n', char(hmm_line(j)));
    end
end

% writing macros file
fprintf(fp_mac, '%s\n', char(hmm_line(1)));
fprintf(fp_mac, '%s\n', char(hmm_line(2)));
fprintf(fp_mac, '%s\n', char(hmm_line(3)));

fclose('all');


%-------------------------------------------------------------------------
% HERest: Calls embedded re-estimation tool HERest on all HMMs in hmmList
%         for the required number of iterations
%-------------------------------------------------------------------------
function [rt, msg] = HERest(srcDir, hmmList, datList, labFile, hstats, nIt, hConf, extraOptStr) 
global aOptStr;

tmp_dir = 'tmp.tmp.tmp';

rt = 0;
msg = 'No Error';

copyfile(srcDir, tmp_dir);

src = sprintf('-H %s\\macros -H %s\\hmmdefs', tmp_dir, tmp_dir);

for n=1:str2num(nIt)
    arg=sprintf('-C %s -I %s %s -S %s %s -M %s -s %s %s',hConf, labFile, extraOptStr, datList, src, srcDir, hstats, hmmList);
    rt = system(sprintf('HERest %s %s', aOptStr, arg));
    if rt
        msg = sprintf('  HERest failed %d', rt);
        HError(msg);
    end
    copyfile(srcDir, tmp_dir);
end

if exist(tmp_dir, 'dir'), rmdir(tmp_dir, 's'); end;

%-------------------------------------------------------------------------
% gen_sp: creates a "sp" model in the current hmmdefs file
%-------------------------------------------------------------------------
function [rt,msg]=gen_sp(filename)
rt =0;
msg=' No Error';
fin=fopen(filename,'rt');
if (fin==-1)
    msg=sprintf('Can not open hmmdefs file %s',filename);
    HError(msg);
    rt=1;
end
fout=fopen('hmm_sp','wt');
fwrite(fout,sprintf('~h "sp"\n'));
fwrite(fout,sprintf('<BEGINHMM>\n'));
fwrite(fout,sprintf('<NUMSTATES> 3\n'));
fwrite(fout,sprintf('<STATE> 2\n'));
str=sprintf('~h "sil"');
while (~strcmp(fgetl(fin),str))     % find "sil" row
end
str1=sprintf('<STATE> 3');
while (~strcmp(fgetl(fin),str1))    % find "<STATE> 3" row for sil
end
str3=sprintf('<STATE> 4');
row=fgetl(fin);
while (~strcmp(row,str3))
    fwrite(fout,sprintf('%s\n',row));
    row=fgetl(fin);
end
fwrite(fout,sprintf('<TRANSP> 3\n'));
fwrite(fout,sprintf('0.0 1.0 0.0\n'));
fwrite(fout,sprintf('0.0 0.9 0.1\n'));
fwrite(fout,sprintf('0.0 0.0 0.0\n'));
fwrite(fout,sprintf('<ENDHMM>\n'));

fclose(fin);
fclose(fout);

fout=fopen(filename,'a');
fin=fopen('hmm_sp','rt');
while ~feof(fin)
    row=fgetl(fin);
    fwrite(fout,sprintf('%s\n',row));
end
fclose(fin);
fclose(fout);
if exist('hmm_sp','file')
    delete('hmm_sp');
end

%------------------------------------------------------------------------ 
%  Update HTKtool log file
%------------------------------------------------------------------------

function [] = UpdateLogFile(log_file, message)

fp = fopen(log_file, 'at');
if fp ~= -1
   fprintf(fp, '%s\n', message);
   fclose(fp);
end

%------------------------------------
% HError: report error
%------------------------------------
function [] = HError(varargin)

if length(varargin) == 1
    str = varargin{1};
else
    str = sprintf(varargin{1}, varargin{2:end});
end

warning(str);






    




