function Tool_trainTri(CmdFile)

% Global Variables
global aOptStr;              % This sets the trace level
global aClnFlg;              % This sets if the target hmm folder will be cleaned before use
aOptStr     = '-A -T 1 ';    % Default is to show the progress
aClnFlg     = 0;             % Default is to disable cleaning up
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_trainTri_inword.dcf'; % This is the default setup file for this program.

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
LogFile = fullfile(CPS.LogDir, 'progress_trainTri.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Start Training Triphone HMMs (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Global Initialization -----------------------------------------------------------

% ------------ Next, begin transcription preparation ----------------------------------------

if (upper(CPS.Trans_prep)== 'Y')
    msg=sprintf('First, convert monophone MLF to triphone MLF, conf file= %s', CPS.Conf_mon2tri);
    UpdateLogFile(LogFile,msg);
    [rt,msg]=mon2tri(CPS.PhoneMLF, CPS.Conf_mon2tri, CPS.TriMLF, CPS.Trilist_ini);
    if rt, UpdateLogFile(LogFile, msg); return; end;
else
    if (upper(CPS.Trans_prep)== 'N')
        msg=sprintf('No transcription prep');
        UpdateLogFile(LogFile,msg);
    else
        msg=sprintf('You must choose between Y and N for transcription prep');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
end
% ----------------------- End transcription preparation -------------------------

% --------------------- Begin model training -----------------------------------------
if (upper(CPS.Train_on)== 'Y')
    msg=sprintf('Training triphones enabled');
    UpdateLogFile(LogFile,msg);
       
    if (upper(CPS.Init)== 'Y')                    % Initialization
        msg=sprintf('Start Initialization for triphones');
        % Do some checking first
        SrcHmm=fullfile(CPS.Src_hmmfolder,'hmmdefs');
        SrcMacro=fullfile(CPS.Src_hmmfolder,'macros');
        if (~exist(SrcHmm,'file') || ~exist(SrcMacro,'file'))
            msg=sprintf('Monophone HMM definition %s, %s do not exist', SrcHmm, SrcMacro);
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
        fin=fopen(SrcHmm,'rt');       % check if mixture=1
        if fin==-1
            msg=sprintf('Can not open HMM definition %s', SrcHmm);
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
        found=0;
        while (~feof(fin) && (found==0))
            inline=fgetl(fin);
            if length(inline)>=11
              if strcmp(inline(1:11),'<MIXTURE> 2')
                 found=1;
              end
            end
        end
        fclose(fin);
        if found
            msg=sprintf('Initial number of mixtures can only be 1');
            UpdateLogFile(LogFile,msg);
            error(msg);
        end % End checking
        
        % make mktri.hed file
        Conf=CPS.Conf_init;
        fin=fopen(Conf,'rt');
        if fin==-1
            msg=sprintf('Can not open file %s',Conf);
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
        Conf_file='mktri.hed';
        fout=fopen(Conf_file,'wt');
        header=['CL ',strrep(CPS.Trilist_init,'\','/')];
        fwrite(fout,sprintf('%s\n',header));
        while ~feof(fin)
            inline=fgetl(fin);
            fwrite(fout,sprintf('%s\n',inline));
        end
        fclose(fin); fclose(fout); % end mktri.hed
        
        % Do cleaning up
        if ~exist(CPS.TgtDir_init,'dir')
            mkdir(CPS.TgtDir_init);
        else
            if aClnFlg
                delete(fullfile(CPS.TgtDir_init,'*'));
            end
        end % end cleaning up
        copyfile(SrcHmm, fullfile(CPS.TgtDir_init,'hmmdefs'));
        copyfile(SrcMacro, fullfile(CPS.TgtDir_init,'macros'));
        % start making initial triphones
        msg=sprintf('Making triphones from monophones');
        UpdateLogFile(LogFile,msg);
        arg = sprintf('HHed %s -H %s\\macros -H %s\\hmmdefs %s %s', aOptStr, CPS.TgtDir_init, CPS.TgtDir_init,Conf_file, CPS.hmmlist_mono);
        rt = system (arg);
        if rt
           msg = sprintf('Making initial triphone failed', rt);
           HError(msg);
           UpdateLogFile(LogFile, msg);
           return
        end
        nIter=CPS.Iteration_init;
        msg=sprintf('Train initial triphones for %s iterations', nIter);
        UpdateLogFile(LogFile,msg);
        [rt, msg] = HERest(CPS.TgtDir_init, CPS.Trilist_init, CPS.Feat_List, CPS.Tri_MLF, ...
                           CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
        if rt, UpdateLogFile(LogFile, msg); return; end;
    else
        if (upper(CPS.Init)=='N')
            msg=sprintf('No initialization for triphone training');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose between Y or N for triphone initialization');
            error(msg);
        end
    end     % end initialization
    
    if (upper(CPS.Tie)=='Y')        % tied state triphones
        msg=sprintf('Begin making tied state triphones ');
        UpdateLogFile(LogFile,msg);
        % do cleaning up "
        if ~exist(CPS.Final_hmmfolder,'dir')
            mkdir(CPS.Final_hmmfolder);
        else
            if (aClnFlg && ~strcmp(CPS.Final_hmmfolder, CPS.TgtDir_init))
                delete(fullfile(CPS.Final_hmmfolder,'*'));
            end
        end % end cleaning up
        
        if ~strcmp(CPS.Final_hmmfolder, CPS.TgtDir_init)
            copyfile(fullfile(CPS.TgtDir_init,'hmmdefs'), fullfile(CPS.Final_hmmfolder,'hmmdefs'));
            copyfile(fullfile(CPS.TgtDir_init,'macros'), fullfile(CPS.Final_hmmfolder,'macros'));
        end
        % making tree.hed file
        fp_quest=fopen(CPS.Question,'rt');
        fp_tb=fopen(CPS.TB,'rt');
        if (fp_quest==-1) || (fp_tb==-1)
            msg=sprintf('Can not open question set %s or TB set %s',CPS.Question, CPS.TB);
            UpdateLogFile(LogFile,msg);
            error(msg);
        end
        Conf_file='tree.hed';
        fp_tree=fopen(Conf_file,'wt');
        fwrite(fp_tree,sprintf('RO 100.0 %s\n\n',strrep(CPS.Stat_embd,'\','/')));
        fwrite(fp_tree,sprintf('%s\n\n','TR 0'));
        while ~feof(fp_quest)
            inline=fgetl(fp_quest);
            fwrite(fp_tree,sprintf('%s\n',inline));
        end
        fclose(fp_quest);
        fwrite(fp_tree,sprintf('\n%s\n','TR 2'));
        while ~feof(fp_tb)
            inline=fgetl(fp_tb);
            fwrite(fp_tree,sprintf('%s\n',inline));
        end
        fclose(fp_tb);
        fwrite(fp_tree,sprintf('\n%s\n\n','TR 2'));
        fwrite(fp_tree,sprintf('AU "%s"\n',strrep(CPS.Full_list,'\','/')));
        fwrite(fp_tree,sprintf('CO "%s"\n\n', strrep(CPS.Trilist_tied,'\','/')));
        fwrite(fp_tree,sprintf('ST "%s"\n', strrep(CPS.Tree,'\','/')));
        fclose(fp_tree); % end making tree.hed
        
        arg = sprintf('HHed %s -H %s\\macros -H %s\\hmmdefs %s %s', aOptStr, CPS.Final_hmmfolder, CPS.Final_hmmfolder, Conf_file, CPS.Trilist_init);
        rt = system (arg);
        if rt
           msg = sprintf('Making tied-state triphones failed', rt);
           HError(msg);
           UpdateLogFile(LogFile, msg);
           return
        end
        
        nIter=CPS.Iteration_tie;
        msg=sprintf('Train tied-state triphones for %s iterations', nIter);
        UpdateLogFile(LogFile,msg);
        [rt, msg] = HERest(CPS.Final_hmmfolder, CPS.Trilist_tied, CPS.Feat_List, CPS.Tri_MLF, ...
                           CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
        if rt, UpdateLogFile(LogFile, msg); return; end;
    else
        if (upper(CPS.Tie)=='N')
            msg=sprintf('No tied-state triphones trained');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose Y or N for tied state triphones');
            error(msg)
        end
    end    % End tied state triphones.
    
        % start mixture splitting
        
   if (upper(CPS.Split)=='Y')
       num_mix = decode_seq(CPS.numMixture);
       herestIter = decode_seq(CPS.Iteration);
    % Do some validation checking
       if isempty(num_mix) || isempty(herestIter) || (length(num_mix) ~= length(herestIter))
           msg = sprintf('  Wrong format of numMixture: and/or Iteration:,  Please correct your setup file: "%s"\n', CmdFile);
           HError(msg);
           UpdateLogFile(LogFile, msg);
           return
       end
        msg=sprintf('Start splitting mixtures');
        UpdateLogFile(LogFile,msg);
        msg = sprintf('numMixture=%s, Iteration=%s',CPS.numMixture, CPS.Iteration);
        UpdateLogFile(LogFile, msg);
        
        start_idx=1;
        for i=start_idx:length(num_mix)
            nMix = num_mix(i);
            msg=sprintf('Current number of mixture= %d',nMix);
            UpdateLogFile(LogFile,msg);
            nIter =  sprintf('%d', herestIter(i));
            nState = str2num(CPS.numState);
          
            system(sprintf('echo MU %d {*.state[2-%d].mix}>split_mix.hed', nMix, nState+1));
            arg = sprintf('HHed %s -H %s\\macros -H %s\\hmmdefs split_mix.hed %s', aOptStr, CPS.Final_hmmfolder, CPS.Final_hmmfolder, CPS.Trilist_tied);
            rt = system (arg);
            if rt
               msg = sprintf('  HHed (spliting mixture) failed %d', rt);
               HError(msg);
               UpdateLogFile(LogFile, msg);
               return
            end
           % running HErest 
           [rt, msg] = HERest(CPS.Final_hmmfolder, CPS.Trilist_tied, CPS.Feat_List, CPS.Tri_MLF, CPS.Stat_embd, nIter, CPS.Conf_embd, CPS.embdOptStr);
           if rt, UpdateLogFile(LogFile, msg); return; end;
       end % for splitting mixture
       if exist('split_mix.hed', 'file'), delete('split_mix.hed'); end; 
    else
        if (upper(CPS.Split)=='N')
            msg=sprintf('No mixture splitting');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose Y or N for mixture splitting');
            error(msg)
        end
    end    % End Mixture splitting.
else
    if (upper(CPS.Train_on)=='N')
        msg=sprintf('Triphone training disabled');
        UpdateLogFile(LogFile,msg);
    else
        msg=sprintf('You must choose between Y and N for triphone training');
        error(msg);
    end
    
end   % End training
    

    
    
    
    
%--------------------------------------------------- End Main ----------------------------------------------------------------------------------------------

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

% ------- mon2tri ---------------------------
% Convert monophone MLF to triphone MLF %
% --------------------------------------------
function [rt,msg]=mon2tri(PhoneMLF, Conf_mon2tri, TriMLF, Trilist_ini)
rt=0;
msg='No Error';
global aOptStr;
arg=sprintf('-l * -i %s -n %s %s %s',TriMLF, Trilist_ini, Conf_mon2tri,PhoneMLF);
rt=system(sprintf('HLEd %s %s',aOptStr,arg));
if rt
  msg = sprintf('Transcription prep (monophone to triphone) failed %d', rt);
  HError(msg);
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
