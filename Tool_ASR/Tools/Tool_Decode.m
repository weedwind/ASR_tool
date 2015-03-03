function Tool_Decode(CmdFile)

% Global Variables
global aOptStr;              % This sets the trace level
global aClnFlg;              % This sets if the target hmm folder will be cleaned before use
aOptStr     = '-A -T 1 ';    % Default is to show the progress
aClnFlg     = 0;             % Default is to disable cleaning up
global LogFile;              % LogFile is the log file for recording the progress of the program

defCmdFile = 'Tool_Decode.dcf'; % This is the default setup file for this program.

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
LogFile = fullfile(CPS.LogDir, 'progress_decode.log');  % The folder to store progress report
UpdateLogFile(LogFile, sprintf('\n\n____________________________________________________________________________________________________________________'));
msg = sprintf('======Start Decoding (''%s', CmdFile);
msg = [msg ''')'];
UpdateLogFile(LogFile, sprintf('%s %s', datestr(now), msg));
UpdateLogFile(LogFile, '--------------------------------------------------------------------------------------------------------------------');
%-- End Global Initialization -----------------------------------------------------------

% --------- Begin Decoding ---------------------------------------

if (upper(CPS.Decode_on)=='Y')
    if ~exist(CPS.Result_folder,'dir')
        mkdir(CPS.Result_folder);
    end
    % Check start and end word
    if isempty(CPS.Startword)
        msg=sprintf('Missing startword');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
    if isempty(CPS.Endword)
        msg=sprintf('Missing endword');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end % End checking
    if (upper(CPS.Hvite_on)=='Y')&&(upper(CPS.HDecode_on)=='Y')
        msg=sprintf('You can not turn on Hvite and HDecode at the same time');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
    
    %--------------- Begin hvite-------------------
    if (upper(CPS.Hvite_on)=='Y')
        % Check HMM_type first
        if strcmp(upper(CPS.HMM_type),'IWD')
            hvite_conf=CPS.Conf_iwd;
        else
            if strcmp(upper(CPS.HMM_type),'XWD')
                hvite_conf=CPS.Conf_xwd;
            else
                if strcmp(upper(CPS.HMM_type),'MONO')
                    hvite_conf=CPS.Conf_mono;
                else
                    msg=sprintf('Wrong HMM type %s for Hvite, should be either tri or mono',CPS.HMM_type);
                    UpdateLogFile(LogFile,msg);
                    error(msg);
                end
            end
        end   % End checking
        msg=sprintf('Hvite for HMM type %s turned on',CPS.HMM_type);
        UpdateLogFile(LogFile,msg);
        % bigram model decoding
        if (upper(CPS.Bigram_on)=='Y')
            msg=sprintf('Using bigram model %s to do decoding',CPS.Network);
            UpdateLogFile(LogFile,msg);
            % first do cleaning up
            result_path=fullfile(CPS.Result_folder,CPS.Rec_output_bg);
            if ~exist(CPS.Lattice_folder,'dir')
                mkdir(CPS.Lattice_folder);
            end
        
            if exist(result_path,'file')
               delete(result_path);
            end
           
            if aClnFlg
              delete(fullfile(CPS.Lattice_folder,'*'));
            end % End cleaning up
            %Do decoding
            src = sprintf('-H %s\\macros -H %s\\hmmdefs', CPS.HMM_folder_hvite, CPS.HMM_folder_hvite);
            rt=system (sprintf ('HVite %s -C %s -o ST -n 4 1 -z lat %s -S %s -i %s %s -w %s %s %s',...
                                aOptStr, hvite_conf, src, CPS.Feat_list, result_path, CPS.HviteOptstring, CPS.Network, CPS.Dict_hvite, CPS.HMM_list_hvite));
            if rt
               msg=sprintf('Hvite failed %d',rt);
               HError(msg);
               UpdateLogFile(LogFile,msg); return;
            end
            msg=sprintf('Hvite bigram decoding completed, HMM type=%s, bigram network=%s',CPS.HMM_type, CPS.Network);
            UpdateLogFile(LogFile,msg);
            % Make lattice list
            copyfile(fullfile(CPS.Feat_folder,'*.lat'),CPS.Lattice_folder);
            delete(fullfile(CPS.Feat_folder,'*.lat'));
            path_lat = fullfile(CPS.Lattice_folder,'');
            directory=dir(path_lat);
            l=length(directory);
            listfile=CPS.Lattice_list;
            fid=fopen(listfile,'w');
            for i=3:l
               fwrite(fid, sprintf('%s\\%s\n',path_lat, directory(i,1).name));
            end
            fclose(fid); 
        else
            if (upper(CPS.Bigram_on)=='N')
                msg=sprintf('No bigram LM decoding for Hvite');
                UpdateLogFile(LogFile,msg);
            else
                msg=sprintf('You must choose between Y or N for bigram LM decoding using Hvite');
                UpdateLogFile(LogFile,msg);
                error(msg);
            end
        end       % End Bigram model decoding.
        
        % Begin using trigram
        if (upper(CPS.Trigram_on)=='Y')
            msg=sprintf('Using trigram model %s to do decoding, HMM Type=%s',CPS.Trigram, CPS.HMM_type);
            UpdateLogFile(LogFile,msg);
            % Do cleaning up
            result_path=fullfile(CPS.Result_folder,CPS.Rec_output_tg);
            if exist(result_path,'file')
                delete(result_path);
            end  % End cleaning up
            % make conf file
            fp=fopen(CPS.Conf_rescore,'wt');
            if strcmp(upper(CPS.HMM_type),'IWD')
               fwrite(fp,sprintf('%s\n','RAWMITFORMAT=T'));
               fwrite(fp,sprintf('%s\n','STARTWORD=!NULL'));
               fwrite(fp,sprintf('%s\n','ENDWORD=!NULL'));
               fwrite(fp,sprintf('STARTLMWORD=%s\n',CPS.Startword));
               fwrite(fp,sprintf('ENDLMWORD=%s\n',CPS.Endword));
               fwrite(fp,sprintf('%s\n','FIXBADLATS=T'));
               fwrite(fp,sprintf('%s\n','FORCECXTEXP=TRUE'));
               fwrite(fp,sprintf('%s\n','ALLOWXWRDEXP=FALSE'));
            else
                if strcmp(upper(CPS.HMM_type),'XWD')
                    fwrite(fp,sprintf('%s\n','RAWMITFORMAT=T'));
                    fwrite(fp,sprintf('%s\n','STARTWORD=!NULL'));
                    fwrite(fp,sprintf('%s\n','ENDWORD=!NULL'));
                    fwrite(fp,sprintf('STARTLMWORD=%s\n',CPS.Startword));
                    fwrite(fp,sprintf('ENDLMWORD=%s\n',CPS.Endword));
                    fwrite(fp,sprintf('%s\n','FIXBADLATS=T'));
                    fwrite(fp,sprintf('%s\n','FORCECXTEXP=TRUE'));
                    fwrite(fp,sprintf('%s\n','ALLOWXWRDEXP=TRUE'));
                else
                    if strcmp(upper(CPS.HMM_type),'MONO')
                          fwrite(fp,sprintf('%s\n','RAWMITFORMAT=T'));
                          fwrite(fp,sprintf('%s\n','STARTWORD=!NULL'));
                          fwrite(fp,sprintf('%s\n','ENDWORD=!NULL'));
                          fwrite(fp,sprintf('STARTLMWORD=%s\n',CPS.Startword));
                          fwrite(fp,sprintf('ENDLMWORD=%s\n',CPS.Endword));
                          fwrite(fp,sprintf('%s\n','FIXBADLATS=T'));
                    end
                end
            end
            fclose(fp); % end make conf file
           
            % Begin rescoring
            rt=system(sprintf('HLRescore %s -C %s -f -o ST -i %s %s -n %s %s -S %s',...
                      aOptStr, CPS.Conf_rescore, result_path, CPS.HLrescore_Optstring, CPS.Trigram, CPS.Dict_hvite, CPS.Latlist));
            if rt
                msg=sprintf('HLrescore failed %d',rt);
                UpdateLogFile(LogFile,msg);
                HError(msg);return;
            end
            msg=sprintf('Hvite trigram decoding completed, HMM type=%s, trigram model=%s',CPS.HMM_type, CPS.Trigram);
            UpdateLogFile(LogFile,msg);
        else
            if (upper(CPS.Trigram_on)=='N')
                msg=sprintf('No trigram decoding for Hvite');
                UpdateLogFile(LogFile,msg);
            else
                msg=sprintf('You must choose between Y and N for trigram decoding using Hvite');
                UpdateLogFile(LogFile,msg);
                error(msg);
            end
        end          % End trigram
    else
        if (upper(CPS.Hvite_on)=='N')
            msg=sprintf('No Hvite decoding');
            UpdateLogFile(LogFile,msg);
        else
           msg=sprintf('You must choose between Y or N for Hvite');
           UpdateLogFile(LogFile,msg);
           error(msg);
        end
    end      % End Hvite
    
    % Begin HDecode option
    if (upper(CPS.HDecode_on)=='Y')
        % make conf file
        fp=fopen(CPS.Conf_hdecode,'wt');
        fwrite(fp,sprintf('%s\n','BYTEORDER=VAX'));
        fwrite(fp,sprintf('%s\n','SAVEGLOBOPTS = TRUE'));
        fwrite(fp,sprintf('%s\n','KEEPDISTINCT=T'));
        fwrite(fp,sprintf('%s\n','BINARYACCFORMAT=T'));
        fwrite(fp,sprintf('%s\n','NATURALREADORDER=T'));
        fwrite(fp,sprintf('%s\n','NATURALWRITEORDER=T'));
        fwrite(fp,sprintf('%s\n','RAWMITFORMAT=T'));
        fwrite(fp,sprintf('STARTWORD=%s\n',CPS.Startword));
        fwrite(fp,sprintf('ENDWORD=%s\n',CPS.Endword));
        fclose(fp); 
        % End making conf file
        
        if (upper(CPS.Use_bigram)=='Y')     % Decode with bigram
            msg=sprintf('Use HDecode for crossword triphones, bigram=%s',CPS.LM_bigram);
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_hd_bg);
            if exist(result_path,'file')
               delete(result_path);
            end 
            % Begin decoding
            src = sprintf('-H %s\\macros -H %s\\hmmdefs', CPS.HMM_folder_hd, CPS.HMM_folder_hd);
            rt=system (sprintf ('HDecode %s -C %s -l * -o ST %s -S %s -i %s %s -w %s %s %s',...
                      aOptStr, CPS.Conf_hdecode, src, CPS.Feat_list, result_path, CPS.HdecodeOptstring, CPS.LM_bigram, CPS.Dict_hd, CPS.HMM_list_hd));
            if rt
               msg=sprintf('HDecode failed %d',rt);
               HError(msg);
               UpdateLogFile(LogFile,msg);return;
            end
        else
            if ~strcmp(upper(CPS.Use_bigram),'N')
                msg=sprintf('Wrong format of Use_bigram, forced to N');
                HError(msg); UpdateLogFile(LogFile,msg);
            end
        end
        
        if (upper(CPS.Use_trigram)=='Y')     % Decode with trigram
            msg=sprintf('Use HDecode for crossword triphones, trigram=%s',CPS.LM_trigram);
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_hd_tg);
            if exist(result_path,'file')
               delete(result_path);
            end 
            % Begin decoding
            src = sprintf('-H %s\\macros -H %s\\hmmdefs', CPS.HMM_folder_hd, CPS.HMM_folder_hd);
            rt=system (sprintf ('HDecode %s -C %s -l * -o ST %s -S %s -i %s %s -w %s %s %s',...
                      aOptStr, CPS.Conf_hdecode, src, CPS.Feat_list, result_path, CPS.HdecodeOptstring, CPS.LM_trigram, CPS.Dict_hd, CPS.HMM_list_hd));
            if rt
               msg=sprintf('HDecode failed %d',rt);
               HError(msg);
               UpdateLogFile(LogFile,msg);return;
            end
        else
            if ~strcmp(upper(CPS.Use_trigram),'N')
                msg=sprintf('Wrong format of Use_trigram, forced to N');
                HError(msg); UpdateLogFile(LogFile,msg);
            end
        end
        
        
       msg=sprintf('HDecode completed, Use_bigram=%s, Use_trigram=%s', CPS.Use_bigram, CPS.Use_trigram);
       UpdateLogFile(LogFile,msg);
    else
        if (upper(CPS.HDecode_on)=='N')
            msg=sprintf('HDecode turned off');
            UpdateLogFile(LogFile,msg);
        else
            msg=sprintf('You must choose Y or N for HDecode');
            UpdateLogFile(LogFile,msg);
            error(msg);
        end   
    end        % End HDecode
    
    % Begin statistic computation
    
    % Convert word transcription to MLF file
    edfile='tmp_ed';
    fp=fopen(edfile,'w');
    fclose(fp);
    tgtfile='tmp.mlf';
    arg=sprintf('-i %s -l * -S %s %s', tgtfile, CPS.Test_trslist, edfile);
    rt = system(sprintf('HLEd %s %s', aOptStr, arg));
    if rt
      msg = sprintf('  HLEd failed %d', rt);
      HError(msg);
      return
    end   % End conversion
    
    char_file='test_char.mlf';
    % Convert word MLF to character MLF file
    gen_char_mlf(tgtfile,char_file);       % convert Chinese word mlf to character mlf. One character/line
    if exist(tgtfile,'file')
        delete(tgtfile);
    end
    if (upper(CPS.Hvite_on)=='Y')
        if (upper(CPS.Bigram_on)=='Y')
            if (strcmp(upper(CPS.HMM_type),'IWD'))
               msg=sprintf('\nAccuracy for : HMM model type=Internal Word Triphone, Bigram= %s\n',CPS.Network);
            else
                if (strcmp(upper(CPS.HMM_type),'XWD'))
                    msg=sprintf('\nAccuracy for : HMM model type=Cross Word Triphone, Bigram= %s\n', CPS.Network);
                else
                    if (strcmp(upper(CPS.HMM_type),'MONO'))
                        msg=sprintf('\nAccuracy for : HMM model type=Monophone, Bigram= %s\n', CPS.Network);
                    end
                end
            end
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_output_bg);
            % Convert word MLF to character MLF file
            rec_file='Rec_bg_char.mlf';
            gen_char_mlf(result_path,rec_file); % End conversion
            rt=system (sprintf ('HResults -A -I %s %s %s >> %s', char_file, edfile, rec_file, LogFile));
            if rt
                msg=sprintf('HResults failed %d',rt);
                HError(msg); UpdateLogFile(LogFile,msg); return;
            end
            if exist(rec_file,'file')
                delete(rec_file);
            end
        end
        if (upper(CPS.Trigram_on)=='Y')
            if (strcmp(upper(CPS.HMM_type),'IWD'))
               msg=sprintf('\nAccuracy for : HMM model type=Internal Word Triphone, Trigram= %s\n',CPS.Trigram);
            else
                if (strcmp(upper(CPS.HMM_type),'XWD'))
                    msg=sprintf('\nAccuracy for : HMM model type=Cross Word Triphone, Trigram= %s\n', CPS.Trigram);
                else
                    if (strcmp(upper(CPS.HMM_type),'MONO'))
                        msg=sprintf('\nAccuracy for : HMM model type=Monophone, Trigram= %s\n', CPS.Trigram);
                    end
                end
            end
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_output_tg);
            % Convert word MLF to character MLF file
            rec_file='Rec_tg_char.mlf';
            gen_char_mlf(result_path,rec_file); % End conversion
            rt=system (sprintf ('HResults -A -I %s %s %s >> %s', char_file, edfile, rec_file, LogFile));
            if rt
                msg=sprintf('HResults failed %d',rt);
                HError(msg); UpdateLogFile(LogFile,msg); return;
            end
            if exist(rec_file,'file')
                delete(rec_file);
            end
        end
    end
    
    if (upper(CPS.HDecode_on)=='Y')
        if (upper(CPS.Use_bigram)=='Y')
            msg=sprintf('\nAccuracy for : HMM model type=Crossword Triphone, Bigram= %s\n',CPS.LM_bigram); 
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_hd_bg);
            % Convert word MLF to character MLF file
            rec_file='Rec_bg_char.mlf';
            gen_char_mlf(result_path,rec_file); % End conversion
            rt=system (sprintf ('HResults -A -I %s %s %s >> %s', char_file, edfile, rec_file, LogFile));
            if rt
                msg=sprintf('HResults failed %d',rt);
                HError(msg); UpdateLogFile(LogFile,msg); return;
            end
            if exist(rec_file,'file')
                delete(rec_file);
            end
        end
        if (upper(CPS.Use_trigram)=='Y')
            msg=sprintf('\nAccuracy for : HMM model type=Crossword Triphone, Trigram= %s\n', CPS.LM_trigram);
            UpdateLogFile(LogFile,msg);
            result_path=fullfile(CPS.Result_folder,CPS.Rec_hd_tg);
            % Convert word MLF to character MLF file
            rec_file='Rec_tg_char.mlf';
            gen_char_mlf(result_path,rec_file); % End conversion
            rt=system (sprintf ('HResults -A -I %s %s %s >> %s', char_file, edfile, rec_file, LogFile));
            if rt
                msg=sprintf('HResults failed %d',rt);
                HError(msg); UpdateLogFile(LogFile,msg); return;
            end
            if exist(rec_file,'file')
                delete(rec_file);
            end
        end
    end     % End computing statistics
    if exist(edfile,'file')
        delete(edfile);
    end
    if exist(char_file,'file')
        delete(char_file);
    end
    
    
else
    if (upper(CPS.Decode_on)=='N')
        msg=sprintf('Decoders turned off');
        UpdateLogFile(LogFile,msg);
    else
        msg=sprintf('You must choose between Y or N for Decode_on');
        UpdateLogFile(LogFile,msg);
        error(msg);
    end
        
        
    
end      







% --------------------------------------------------- End Main   -------------------------------------------------------------------------------------------------------------------


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

%-------------------------------------------------
%    Convert word MLF file to character MLF file
%-------------------------------------------------
function []=gen_char_mlf(infilename,outfilename)
    fin=fopen(infilename,'r');
    fout=fopen(outfilename,'w');
    while ~feof(fin)
          label=fgetl(fin);
          l=length(label);
          if ~isempty(label)&&((label(1)>=176)||(label(1)==163))  % This row is what we need
             for i=1:2:l-1
                if i==l-1                   % last char
                   fwrite(fout,sprintf('%s',label(i:l)));
                else
                 fwrite(fout,sprintf('%s\n',label(i:i+1)));
                end
             end
          else
                fwrite(fout,sprintf('%s',label));
          end
      fwrite(fout,sprintf('\n'));
   end
  fclose(fin);
  fclose(fout);


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

           
            
          
               
            
        
            
            

            
                   
            
              
                
            
        
    


