function []=Tool_Compute_Feat(CmdFile)
% This is the feature computation block.
% This block provides three front-ends:
     % HTK_MFCC
     % HTK_PLP
     % User-Defined DCTC/DCS
  
% Input:
%      CmdFile: given by user, (use default 'DataPrep.dcf', if not specified)
%Output:
%      Feature files will be generated in a user specified folder.
%      A progress log report will be generated in a user specified folder.
%      A feature file list will be generated. The path of this list is user-specified.
%      If you use "User" mode, you need to manually creates this feature
%      file list


% Global Variables
global aOptStr;              % This sets the trace level
global aClnFlg;              % This sets if the target feature folder will be cleaned before use
aOptStr     = '-A -T 1 ';    % Default is to show the progress
aClnFlg     = 0;             % Default is to disable cleaning up
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_Compute_Feat.dcf'; % This is the default setup file for this program.

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
LogFile = fullfile(CPS.LogDir, 'progress_feat.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Starting Data Prep (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Initialization --------------------------------

%-- Begin Feature Extraction ---------------------------------------------

rt=-1;
if (upper(CPS.Feat_On)=='Y')
    msg=sprintf('====Starting Feature Extraction=====');
    UpdateLogFile(LogFile,msg);
    switch (upper(CPS.FrtEnd_opt))
        case 'HTK_MFCC'
            % HTK_MFCC feature
            msg=sprintf('Frontend Method is %s',CPS.FrtEnd_opt);
            UpdateLogFile(LogFile,msg);
            [rt, msg] = HCopy(CPS.Wave_List, CPS.Feat_folder, CPS.Feat_List, CPS.Conf_MFCC);
            if rt, UpdateLogFile(LogFile, msg); return; end;
        case 'HTK_PLP'
            % HTK_PLP feature
            msg=sprintf('Frontend Method is %s',CPS.FrtEnd_opt);
            UpdateLogFile(LogFile,msg);
            [rt, msg] = HCopy(CPS.Wave_List, CPS.Feat_folder, CPS.Feat_List, CPS.Conf_PLP);
            if rt, UpdateLogFile(LogFile, msg); return; end;
        case 'USER'
            msg=sprintf('Frontend Method is User Defined DCTC/DCS');
            UpdateLogFile(LogFile,msg);
            % DCTC-DCSC feature
            if ~exist(CPS.Feat_folder, 'dir')
                mkdir(CPS.Feat_folder);
            elseif aClnFlg                                   % Clean up features before computation
                delete(fullfile(CPS.Feat_folder, '*'));
            end
            [rt, msg] = TFront(CPS.Conf_tfrontm, CPS.Wave_List, CPS.Feat_List, CPS.Feat_folder); 
            if rt, UpdateLogFile(LogFile, msg); return; end;
        otherwise
            msg=sprintf('Unknown feature extraction option %s',CPS.FrtEnd_opt);
            HError(msg);
            UpdateLogFile(LogFile,msg);
            msg=sprintf('Frontend Forced to HTK_MFCC');
            UpdateLogFile(LogFile,msg);
            [rt, msg] = HCopy(CPS.Wave_List, CPS.Feat_folder, CPS.Feat_List, CPS.Conf_MFCC);
            if rt, UpdateLogFile(LogFile, msg); return; end;
    end     % end frontend selection
else
    if (upper(CPS.Feat_On)=='N')
        msg=sprintf('===== No Feature Extraction =====');
        UpdateLogFile(LogFile,msg);
    else
    error('You must choose between Y and N');
    end
end

if ~rt       % if feature extraction is chosen and successful
    % read one feature file to determine feature vector size
    % open list file and read the first entry
      fp = fopen(CPS.Feat_List, 'rt');
      if fp == -1
          msg = sprintf('Cannot read feature file list %s', CPS.Feat_List);
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
      msg = sprintf(' Frontend Method=%s, Feature Dimension=%d', CPS.FrtEnd_opt, num_var); 
      UpdateLogFile(LogFile, msg);
end


% ---- End Main -------------------------------------------------

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


%-------------------------------------------------------------------------
% HCopy: Calls HCopy to convert wave data to HTK feature parameterised ones
%-------------------------------------------------------------------------
function [rt, msg] = HCopy(srcList, tgtDir, tgtList, hConf)
global aOptStr;
global aClnFlg;

rt = 0;
msg = 'No Error';

if ~exist(tgtDir, 'dir')
    mkdir(tgtDir);
elseif (aClnFlg)                           %If Clean_up is set to y, clean features before computation
    delete(fullfile(tgtDir, '*'));
end

fin  = fopen(srcList, 'r');
if (fin == -1), HError('Cannot open wave file list file %s', srcList); end;
fout = fopen(tgtList, 'w');
if (fout == -1), HError('Cannot open feature file list %s', tgtList); end;

while(~feof(fin))
    inFile  = fgetl(fin);
    idx = strfind(inFile, '\');
    fname = strtok(inFile(idx(end)+1:end), '.');
    outFile = fullfile(tgtDir, [fname, '.mfc']);  
    
    rt=system(sprintf('HCopy %s -C %s %s %s',aOptStr, hConf, inFile, outFile));
    if rt
        msg = sprintf('  HTK frontend failed %d', rt);
        HError(msg);
        fclose(fin);
        fclose(fout);
        return;
    end;
    fprintf(fout, '%s\n', outFile);
end
fclose(fin);
fclose(fout);

%-------------------------------------------------------------------------
% TFront: Calls TFrontm to calcuate DCTC/DCS feature
%-------------------------------------------------------------------------
function [rt, msg] = TFront(tDat,srcList, tgtList,tgtFolder)
global aOptStr;

rt = 0;
msg = 'No Error';

tfm = fullfile('tfront','tfrontm');
% no need to use srcList and tgtList, but should keep them
% consistent with tfrontm DAT files
if strfind(aOptStr, '-A')
    disp(sprintf('tfrontm %s', tDat));
end
rt = system(sprintf('%s %s %s %s %s',tfm, tDat,srcList,tgtList,tgtFolder));
if rt
    msg = sprintf('  TFront failed %d', rt); 
    HError(msg);
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


    
  
    
