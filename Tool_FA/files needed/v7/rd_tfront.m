function [SNR, FileType, FeatFile,ParmType]= rd_tfront(FileName)
% if no input argument, use default
if nargin == 0, FileName = 'TFRONT.DAT'; end;

fid = fopen(FileName,'r');
if (fid == -1)
   disp ([sprintf('rd_tfdat.m -> Error: cannot open %s!\n', FileName)]);
   return;
end

disp ([sprintf('\nrd_tfdat.m -> Reading %s ...', FileName)]);
% Initialization
SNR       = 200;
FileType   = 'TYPEB1';
FeatFile   = 'CP_FEA13.INI';
ParmType   = 9;     % default to USER parameter type for HTK output

% find and check file ID first
found_id = 0;
while ~feof(fid)
   s = upper(fgetl(fid));
   [varname, s] = strtok(s);	
   [value] = strtok(s);	
   if strcmp(varname, 'FILE_ID:')
      [value] = strtok(s);	
      if ~strcmp(value, 'TFRONT_SPEC')
		   disp ([sprintf('rd_tfdat.m -> Error: invalid file ID\n')]);
		   fclose(fid);
         return;
      else
         found_id = 1;
         break
      end
   end
end

if found_id == 0
   disp ([sprintf('rd_tfdat.m -> Error: cannot find file ID\n')]);
  	fclose(fid);
   return;
end


while feof(fid) ~= 1 
   s = upper(fgetl(fid));
   [varname, s] = strtok(s);
   if  (length(varname) > 1) && (~strcmp(varname(1:2),'//'))   
      % check for length > 1 instead of using isempty to avoid 
      % the Eof char in case of QEdit was used to edit the command file
     
      value = strtok(s);
      % now find what variable it is
      switch (varname)
         case 'SNR:'
           SNR = str2num(value);
         case 'FEAT_FILE:'
           FeatFile = value;
         case 'FILE_TYPE:'
            if ~strcmp(value, 'TYPEA1') && ~strcmp(value, 'TYPEB1') && ~strcmp(value, 'HTK')
               disp ([sprintf('\nRD_TFDAT -> Warning: Unknown output file type %s!\n')])
               disp ([sprintf('                     Forced to "%s"\n', FileType)])
            else
               FileType = value;
            end;
         case 'PARMTYPE:'
            ParmType = value;
          otherwise 
             warning('rd_tfdat -> Unknown variable name: %s',varname);
       end % end switch
    end
end
fclose(fid);
end


