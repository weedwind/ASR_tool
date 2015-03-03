function Tool_trainLM(CmdFile)


% Global Variables
global aOptStr;              % This sets the trace level
aOptStr     = '-A -T 1 ';    % Default is to show the progress
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_trainLM.dcf'; % This is the default setup file for this program.

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

if ~exist(CPS.LogDir,'dir')
    mkdir(CPS.LogDir);
end
LogFile = fullfile(CPS.LogDir, 'progress_trainLM.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Start Training Language Model (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Global Initialization -----------------------------------------------------------

if upper(CPS.Train_on)=='Y'
    
%---- Simple method 1------
  if (upper(CPS.method1_on)== 'Y')
      msg=sprintf('Use transcriptions to create a simple bigram model');
      UpdateLogFile(LogFile,msg);
      LMfile=fullfile(CPS.LM_folder1,CPS.LM_name1);
      if ~exist(CPS.LM_folder1,'dir');
          mkdir(CPS.LM_folder1);
      end
      [rt, msg]=HLstats(CPS.datalist1, LMfile, CPS.wordlist, CPS.Startword1, CPS.Endword1, CPS.OptString, CPS.Discount );
      if rt, UpdateLogFile(LogFile, msg); return; end;
      msg=sprintf('LM training method 1 completed');
      UpdateLogFile(LogFile,msg);
  else
      if (upper(CPS.method1_on)=='N')
          msg=sprintf('Simple method 1 turned off');
          UpdateLogFile(LogFile,msg);
      else
          msg=sprintf('You must choose between Y and N for method 1');
          UpdateLogFile(LogFile,msg);
          error(msg);
      end
  end
%---- End simple method 1------

%---- method 2 ------
  if (upper(CPS.method2_on)=='Y')
      if (str2num(CPS.LM_order)>0)
         msg=sprintf('Use text data to create an LM or order %s',CPS.LM_order);
         UpdateLogFile(LogFile,msg);
         msg=sprintf('This method will not return a wordlist. Please make one manually for later use');
         UpdateLogFile(LogFile,msg);
         warning(msg);
         LMfile=fullfile(CPS.LM_folder2,CPS.LM_name2);

         % do some checking
         cutoff_seq = decode_seq(CPS.cutoffs);
         if (str2num(CPS.LM_order)>1)
            if isempty(cutoff_seq)
                cutoff_seq=zeros(1,str2num(CPS.LM_order)-1);
            else
               if (length(cutoff_seq)~=str2num(CPS.LM_order)-1)
                   msg = sprintf('  Wrong format of cutoff factors,  Please correct your setup file: "%s"\n', CmdFile);
                   HError(msg);
                   UpdateLogFile(LogFile, msg);
                   return
               end
            end
         end
         if ~(strcmp(upper(CPS.DCtype),'TG')||strcmp(upper(CPS.DCtype),'ABS'))
             msg=sprintf('Wrong discount type, must be TG or ABS');
             HError(msg);
             UpdateLogFile(LogFile,msg);
             return;
         else
             msg=sprintf('LM discount type is %s',upper(CPS.DCtype));
             UpdateLogFile(LogFile,msg);
         end
            
         if ~exist(CPS.LM_folder2,'dir')
             mkdir(CPS.LM_folder2);
         end
         [rt,msg]=BuildLM(CPS.datalist2, CPS.LM_order, cutoff_seq, CPS.LM_format, CPS.Max_vocab, CPS.Startword2, CPS.Endword2, LMfile,CPS.vocabulary, CPS.DCtype);
         if rt, UpdateLogFile(LogFile, msg); return; end;
         msg=sprintf('LM training method 2 completed');
         UpdateLogFile(LogFile,msg);
      end  
  else
      if (upper(CPS.method2_on)=='N')
          msg=sprintf('Method 2 turned off');
          UpdateLogFile(LogFile,msg);
      else
          msg=sprintf('You must choose between Y and N for method 2');
          error(msg);
      end
  end
%------- End method 2 -----------
else
    if (upper(CPS.Train_on)=='N')
        msg=sprintf('No LM training enabled');
        UpdateLogFile(LogFile,msg);
    else
        msg=sprintf('You must choose between Y and N for LM training');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
end          % End LM training 

% Begin converting bigram model to word network

if (upper(CPS.Convert_on)=='Y')
    msg=sprintf('Convert bigram model %s to word network',CPS.Bigram);
    UpdateLogFile(LogFile,msg);
    if ~exist(CPS.Network_folder,'dir')
        mkdir(CPS.Network_folder);
    end
    net=fullfile(CPS.Network_folder,CPS.Network_name);
    if exist(net,'file')
        delete(net);
    end
    if isempty(CPS.Startword)
        CPS.Startword='!ENTER';
    end
    if isempty(CPS.Endword)
        CPS.Endword='!EXIT';
    end
    marker=sprintf('%s %s',CPS.Startword,CPS.Endword);
    
    rt=system(sprintf('HBuild %s -u %s -z -s %s -n %s %s %s', aOptStr, '!!UNK', marker, CPS.Bigram, ...
                   CPS.wrdlist, net));
    if rt
       msg = sprintf('  HBuild failed %d', rt);
       UpdateLogFile(LogFile,msg);
       HError(msg); return;
    end
    msg=sprintf('Bigram model %s has been successfully converted to word network %s',CPS.Bigram, net);
    UpdateLogFile(LogFile,msg);
else
    if (upper(CPS.Convert_on)=='N')
        msg=sprintf('No conversion between bigram model to word netwrok');
        UpdateLogFile(LogFile,msg);
    else
        msg=sprintf('You must choose between Y or N for conversion');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
end
% End conversion


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



%------------------------------------
% HLstats: Build bigram model using trascriptions
%------------------------------------
function [rt, msg] = HLstats(srclist, statFile, wrdList, startword, endword, OptString, discount )
global aOptStr;

rt = 0;
msg = 'No Error';

% Convert word transcription to MLF file format
edfile='tmp_ed';
fp=fopen(edfile,'w');
fclose(fp);
tgtfile='tmp.mlf';
arg=sprintf('-i %s -l * -n %s -S %s %s', tgtfile, wrdList, srclist, edfile);
rt = system(sprintf('HLEd %s %s', aOptStr, arg));
if rt
    msg = sprintf('  HLEd failed %d', rt);
    HError(msg);
    return
end
wrdList2='tmp_wordlist';
system(sprintf('sort %s > %s', wrdList, wrdList2));
replaceChar(wrdList2, wrdList, '''', '\''');

if exist(wrdList2,'file')
    delete(wrdList2);
end

if isempty(startword)
    startword='!ENTER';
end
if isempty(endword)
    endword='!EXIT';
end
marker=sprintf('%s %s',startword,endword);

fp=fopen(edfile,'wt');
fwrite(fp,sprintf('%s\n','NONUMESCAPES=TRUE'));
fwrite(fp,sprintf('DISCOUNT=%s\n',discount));
fclose(fp);

    
% Calculate Bigram 
rt=system(sprintf('HLStats %s -C %s %s -s %s -b %s -o %s %s', aOptStr, edfile, OptString, marker, statFile, ...
               wrdList, tgtfile));
if rt
    msg = sprintf('  HLStats failed %d', rt);
    HError(msg);
    return
end

if exist(edfile,'file')
    delete(edfile);
end

if exist(tgtfile,'file')
    delete(tgtfile);
end

fp=fopen(wrdList,'a');
if (~isempty(startword))
    fwrite(fp,sprintf('%s\n',startword));
else
    fprintf(fp,'!ENTER\n');
end

if (~isempty(endword))
    fwrite(fp,sprintf('%s\n',endword));
else
    fprintf(fp,'!EXIT\n');
end

fclose(fp);

%------------------------------------
% replaceChar: replace characters in a file
%------------------------------------
function [] = replaceChar(srcFile, dstFile, str1, str2)
fin  = fopen(srcFile, 'r');
if (fin == -1), HError('Cannot open file %s', srcFile); end;
fout  = fopen(dstFile, 'w');
if (fout == -1), HError('Cannot open file %s', dstFile); end;

while(~feof(fin))
    str = fgetl(fin);
    fprintf(fout, '%s\n', strrep(str, str1, str2));
end
fclose(fin);
fclose(fout);

function [rt,msg]=BuildLM(srclist, LM_order, cutoff, LM_format, Max_vocab, Startword, Endword, lmfile, vocabulary, DCtype)
global aOptStr;
msg='No Error';

Field='WFC';
Name='lm';
MapFile='empty.wmap';

ldir='lm.0';     % folder to store gram files
if ~exist(ldir,'dir')
    mkdir(ldir);
end

rt=system(sprintf('LNewMap -f %s %s %s',Field, Name, MapFile));   % make empty map file
if rt
    msg = sprintf('  LNewMap failed %d', rt);
    HError(msg);
    return
end
fp=fopen('config1','wt');
if ~isempty(Startword)
    fwrite(fp,sprintf('STARTWORD=%s\n',Startword));
end
if ~isempty(Endword)
    fwrite(fp,sprintf('ENDWORD=%s\n',Endword));
end
fclose(fp);
% make gram files
rt=system(sprintf('LGPrep %s -C config1 -a %s -b 200000 -n %s -S %s -d %s %s',aOptStr, Max_vocab, LM_order, srclist, ldir, MapFile)); 
if rt
    msg = sprintf('  LGPrep failed %d', rt);
    HError(msg);
    return
end
if exist(MapFile,'file')     % Delete the empty map file
    delete(MapFile);
end
% make a list of all the gram.* files
path = fullfile(ldir,'');
directory=dir(path);
l=length(directory);
listfile='list_gram';
fid=fopen(listfile,'w');
for i=3:l-1
   fwrite(fid, sprintf('%s\\%s\n',path, directory(i,1).name));
end
fclose(fid);

ldir1='lm.1';       % folder to store sequenced gram files
if ~exist(ldir1,'dir')
    mkdir(ldir1);
end
rt=system(sprintf('LGCopy -T 1 -C config1 -b 200000 -d %s -S %s %s',ldir1, listfile, [ldir,'\wmap']));
if rt
    msg = sprintf('  LGCopy failed %d', rt);
    HError(msg);
    return
end


% make a list of all the data.* files
path = fullfile(ldir1,'');
directory=dir(path);
l=length(directory);
listfile='list_gram';
fid=fopen(listfile,'w');
for i=3:l
   fwrite(fid, sprintf('%s\\%s\n',path, directory(i,1).name));
end
fclose(fid);

% Begin map OOV words
if ~strcmp(upper(vocabulary),'NONE')
    ldir2='lm.2';
    if ~exist(ldir2,'dir')
        mkdir(ldir2);
    end
    rt=system(sprintf('LGCopy -T 1 -C config1 -o -m %s -a %s -b 200000 -d %s -S %s -w %s %s',[ldir2,'\wmap'],Max_vocab,ldir2,listfile,vocabulary,[ldir,'\wmap']));
    if rt
        msg=sprintf('Mapping OOV words (LGCopy) falied %d',rt);
        HError(msg);
        return;
    end
    % make a list of all the data.* files that contain OOV words
    path=fullfile(ldir2,'');
    directory=dir(path);
    l=length(directory);
    listfile1='list_gram1';
    fid=fopen(listfile1,'w');
    for i=3:l-1
        fwrite(fid, sprintf('%s\\%s\n',path, directory(i,1).name));
    end
    fclose(fid);
    % merge data list together
    fid1=fopen(listfile,'a');
    fid2=fopen(listfile1,'r');
    while ~feof(fid2)
        inline=fgetl(fid2);
        fwrite(fid1,sprintf('%s\n',inline));
    end
    fclose(fid1);
    fclose(fid2);
end
    

% Begin to make LM
fp=fopen('config1','a');
fwrite(fp,sprintf('%s\n','LPCALC: TRACE=3'));
fwrite(fp,sprintf('%s\n','LMODEL: TRACE=3'));
fwrite(fp,sprintf('LPCALC:DCTYPE=%s\n',DCtype));

fclose(fp);

cut_string='';     % make cutoff string
if str2num(LM_order)>1
   for i=2:str2num(LM_order)
      append=sprintf('-c %d %d ',i, cutoff(i-1));
      cut_string=[cut_string,append];
   end
end

if strcmp(upper(LM_format),'TEXT')
    form='-f TEXT';
else
    form='';
end
if ~strcmp(upper(vocabulary),'NONE')
    rt=system(sprintf('LBuild %s %s -C config1 %s -n %s -S %s %s %s',aOptStr, form, cut_string, LM_order, listfile, [ldir2,'\wmap'],lmfile));
else
    rt=system(sprintf('LBuild %s %s -C config1 %s -n %s -S %s %s %s',aOptStr, form, cut_string, LM_order, listfile, [ldir,'\wmap'],lmfile));
end
if rt
    msg = sprintf('  LBuild failed %d', rt);
    HError(msg);
    return
end
if exist('config1','file')
    delete('config1');
end
if exist(listfile,'file')
    delete(listfile);
end
if exist(ldir,'dir')
    rmdir(ldir,'s');
end
if exist(ldir1,'dir')
    rmdir(ldir1,'s');
end
if ~strcmp(upper(vocabulary),'NONE')
    if exist(ldir2,'dir')
       rmdir(ldir2,'s');
    end
    if exist(listfile1,'file')
        delete(listfile1);
    end

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

    



 





