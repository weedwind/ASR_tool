function [] =Tool_FA(CmdFile)
% This is the tool to do FA (forced alignment)
% Generally, the INPUTS are:
  % 1. A set of HMM models previously trained from "train FA" step
  % 2. A monophone HMM list. This list should cover all the phones
  %    including or not including "sp".
  % 3. A pronunciation dictionary. This dictionary should contain an
  %    entry "SENT_Boundary sil", and each word should be appended with
  %    a "sp" if your model set has "sp".
  % 4. The word level MLF file for each sentence.
% Generally, the OUTPUTS are:
  % 1. A series of phone level transcriptions with the best pronunciation according to
  %    the acoustic features will be generated.
  %    Eg. aligned_i.mlf will be generated after each FA iteration.
  %    You can choose if you want the time stamps or not in the phone
  %    transcriptions.
  % 2. A set of refined models.
  % 3. A progress report, default to progress_FA.log
% INPUTs of this function:
   % A setup file. Default to Tool_FA.dcf
% OUTPUTs of this function: None

% Global Variables
global aOptStr;              % This sets the trace level
global aClnFlg;              % This sets if the refined hmm folder and the aligned phone MLF file will be cleaned
aOptStr     = '-A -T 1 ';    % Default is to show the progress
aClnFlg     = 0;             % Default is to disable cleaning up
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_FA.dcf'; % This is the default setup file for this program.

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
LogFile = fullfile(CPS.LogDir, 'progress_FA.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Start FA (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Global Initialization -----------------------------------------------------------

% ---------------------------------- Begin FA ----------------------------------------------------------------
if (upper(CPS.FA_on)== 'Y')
    msg=sprintf(' FA Enabled ');
    UpdateLogFile(LogFile,msg);
    
    % Next, do some checking
    if (str2num(CPS.FA_iteration) == 0)                    % Must be at least 1 FA iteration
        msg=sprintf('There should be at least 1 iteration of FA');
        UpdateLogFile(LogFile,msg);
        HError(msg);
        return;
    end
    herestIter = decode_seq(CPS.Embd_iteration);           % Decode embedded training iterations into a vector
    if (length(herestIter)~=str2num(CPS.FA_iteration))
        msg = sprintf('  Wrong format of Embedded Training iterations,  Please correct your setup file: "%s"\n', CmdFile);
        UpdateLogFile(LogFile,msg);
        HError(msg);return;
    end
    if ~exist(CPS.TgtDir_hmm,'dir')
        mkdir(CPS.TgtDir_hmm);
    end            % End checking
    
    msg=sprintf('FA_iteration=%s, Embedded Training iteration=%s, Dictionary=%s, hmmList=%s, Word MLF=%s, Output=%s',...
                 CPS.FA_iteration, CPS.Embd_iteration, CPS.Dict, CPS.hmmList, CPS.WordMLF,'aligned_*.mlf');
    UpdateLogFile(LogFile,msg);
    
    % Next, do cleaning-up
    if aClnFlg
        delete(fullfile(CPS.aligned_folder,'aligned_*.mlf'));  % Delete aligned MLF files
        if ~strcmp(CPS.SrcDir_hmm,CPS.TgtDir_hmm)              % Delete refined models
            delete(fullfile(CPS.TgtDir_hmm,'*'));
        end
    end  % End cleaning up
    if (exist(fullfile(CPS.SrcDir_hmm,'hmmdefs'),'file') && exist(fullfile(CPS.SrcDir_hmm,'macros'),'file'))
        if ~strcmp(CPS.SrcDir_hmm,CPS.TgtDir_hmm)
           copyfile(fullfile(CPS.SrcDir_hmm,'hmmdefs'),fullfile(CPS.TgtDir_hmm,'hmmdefs'));
           copyfile(fullfile(CPS.SrcDir_hmm,'macros'),fullfile(CPS.TgtDir_hmm,'macros'));
        end
    else
        msg=sprintf('No valid hmms in the source directory "%s"',CPS.SrcDir_hmm);
        UpdateLogFile(LogFile,msg);
        HError(msg);
        return;
    end
    FA_iter=str2num(CPS.FA_iteration);
    for i=1:FA_iter
       % First do alignment
       algMLF=fullfile(CPS.aligned_folder,sprintf('aligned_%d.mlf',i));     % This is the aligned file for iteration i
       msg=sprintf('Begin FA iteration %d; The output is %s',i,algMLF);
       UpdateLogFile(LogFile,msg);
       rt = FA(CPS.TgtDir_hmm, algMLF, CPS.Feat_List, CPS.WordMLF, CPS.hmmList, CPS.Dict, CPS.Conf_FA, CPS.Prune_FA, CPS.Output_level);
       if rt
           msg=sprintf('Forced alignment failed at iteration %d',i);
           UpdateLogFile(LogFile,msg);
           HError(msg);
           return;
       else
           msg=sprintf('Check how much change between FA iteration %d and FA iteration %d\n',i, i-1);
           UpdateLogFile(LogFile,msg);
       end
       if (i==1)
          ref=CPS.Init_phoneMLF;
       else
           ref=fullfile(CPS.aligned_folder,sprintf('aligned_%d.mlf',i-1));
       end
       fin=fopen(algMLF,'rt');             % change .lab to .rec for comparison
       rec_name=sprintf('aligned_rec_%d.mlf',i);
       fout=fopen(rec_name,'wt');
       while ~feof(fin)
           inline=fgetl(fin);
           outline=strrep(inline,'.lab','.rec');
           fwrite(fout,sprintf('%s\n',outline));
       end
       fclose(fin);
       fclose(fout);
           
       arg=sprintf('-I %s -e ??? sil -e ??? sp %s %s', ref, CPS.hmmList, rec_name);
       rt = system(sprintf('HResults %s %s >> %s', aOptStr, arg, LogFile));
       if rt
          msg = sprintf('  HResults failed %d', rt);
          UpdateLogFile(LogFile,msg);
          HError(msg);
          return;
       end
       delete(rec_name);
       
       % Then, refine models
       nIter=herestIter(i);
       if nIter>0
           msg=sprintf('Now,begin refining models after FA iteration %d',i);
           UpdateLogFile(LogFile,msg);
           [rt, msg] = HERest(CPS.TgtDir_hmm, CPS.hmmList, CPS.Feat_List, algMLF, ...
                           CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.Prune_embd);
           if rt,UpdateLogFile(LogFile,msg);return; end
       else
           if nIter==0
               msg=sprintf('No model refinement after FA iteration %d',i);
               UpdateLogFile(LogFile,msg);
               msg=sprintf('The refined models after FA iteration %d is copied from iteration %d',i,i-1);
               UpdateLogFile(LogFile,msg);
           end
       end
    end        % end for
    msg=sprintf('\n\n-----------------------Forced alignment and model refinement completed--------------------------');
    UpdateLogFile(LogFile,msg);
else
    if (upper(CPS.FA_on)=='N')
        msg=sprintf('No Forced Alignment and Model Refinement');
        UpdateLogFile(LogFile,msg);
    else
        error('You must choose between Y and N for FA');
    end
end
       
       
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

%-------------------------------------------
% FA: Forced Alignment
%-------------------------------------------
function rt=FA(hmm_folder, algMLF, Feat_List, WordMLF, hmmList, Dict, Conf_FA, Prune_FA,Output_level)
global aOptStr;
rt=0;
msg='No Error';
src = sprintf('-H %s\\macros -H %s\\hmmdefs', hmm_folder, hmm_folder);
arg=sprintf(['-a -m %s -b SENT_Boundary -y lab -C %s %s -S %s -l * -I %s -i %s %s ' ...
             '%s %s'], Output_level, Conf_FA, src, Feat_List, WordMLF, algMLF, Prune_FA, Dict, hmmList);
rt = system(sprintf('HVite %s %s', aOptStr, arg));

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

for n=1:nIt
    arg=sprintf('-C %s -I %s %s -S %s %s -M %s -s %s %s',hConf, labFile, extraOptStr, datList, src, srcDir, hstats, hmmList);
    rt = system(sprintf('HERest %s %s', aOptStr, arg));
    if rt
        msg = sprintf('  HERest failed %d', rt);
        HError(msg);
    end
    copyfile(srcDir, tmp_dir);
end

if exist(tmp_dir, 'dir'), rmdir(tmp_dir, 's'); end;

% decode sequence of number in text format (such as '1;2;4;8;16') 
% into an array of number ([1, 2, 4, 8, 16])
function out = decode_seq(seq)

out = [];

[num, tmp] = strtok(seq, ' ;,');
while ~isempty(num)
    out = [out, str2num(num)];
    [num, tmp] = strtok(tmp, ' ;,');
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



       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
    
    
        
    




