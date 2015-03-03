 function wr_head(fil_nam, fil_typ, fil_hd, flag)

 % Program to write the header for the TypeA1 and TypeB1 and HTK
 % file for the Tfrontm
 % Programmer : Jaishree. V.
 % Date       : 10\24\99
 %            : 11-23-99 Montri K. -- add HTK file type
 %            : 02-14-00 Montri K. -- add flag, to allow updating file header only
 % Version    : 0.3
 % 
 %  function wr_head(fil_nam, fil_typ, fil_hd, flag)
 % 
 % Inputs are 
 % fil_nam     - Name  of the output file
 % fil_typ     - Type of the file(TYPEA1, TYPEB1), or HTK)
 % fil_hd(1)   - rec_len ( for TYPEB1 files )
 % fil_hd(2)   - Ncat - number of categories
 % fil_hd(3)   - Nvar ( Number of variables )
 % fil_hd(4)   - Number of tokens 
 % fil_hd(5)   - Frame rate (in ms) for HTK type                    A structure containing Header info for HTK file
 % flag        - 0: create new file (default)
 %               otherwise: update header only
 %
 % The header format for the TYPEA1 and  TYPEB1 files are
 % 
 % TYPEA1  |  TYPEB1  -  specifies the type of the file                
 %      12  |      21  -  Rec_len(12 - TYPEA1, >= Nvar +11 - TYPEB1) 
 %       1  |       1  -  Number of records
 %       1  |       1  -  Number of categories
 %      10  |      10  -  Number of variables
 %       4  |       4  -  Number of tokens
 %
 %
 % Header for HTK:  
 %  int32: number of frames
 %  int32: frame rate in 100ns unit
 %  int16: number of features in each frame
 %  int32: parameter kind 

if nargin < 3
   disp 'Usage: wr_head(fil_nam, fil_typ, fil_hd, flag)'
   return
end

% set flag to 0 ( overwritten mode) if flag is not specified
if nargin == 3
   flag = 0;
end

% select appropriate open mode
if flag == 0
    if strcmp(fil_typ,'HTK')
       open_mode = 'wb';
   else
       open_mode = 'w';
   end
else
   open_mode = 'r+';
end

% open the file for writing
fid=fopen(fil_nam, open_mode);
if fid < 0
    sprintf('Error:wr_head -> Could not open file: %s',fil_nam)
    return
end

    
%  Code to check the file type
if strcmp(fil_typ,'TYPEB1') 
    
   if fil_hd(1) < fil_hd(3)+11
      Rec_len=fil_hd(3)+11;
      fil_hd(1)=Rec_len;
   else
      Rec_len=fil_hd(1);
   end
 
   Nrec=(9 + 2 * fil_hd(2) + Rec_len ) / Rec_len;
 
% Code to write the file header 
   fprintf(fid,'%6s\r\n%6d\r\n%6d\r\n%6d\r\n%6d\r\n%6d\r\n','TYPEB1',...
   Rec_len,floor(Nrec),fil_hd(2),fil_hd(3),fil_hd(4));

% Code to pad the header with spaces
   hd_len=floor(Nrec) * Rec_len * 4 ;
   filled = 40 + fil_hd(2) * 8;
   skip=hd_len-filled;
   a=' ';
   a(1:skip)=a;
   fwrite(fid,a);
 
elseif strcmp(fil_typ, 'TYPEA1')
          
% Code to write the header for TYPEA1 file   
   Rec_len=12;
   Nrec=(9 + 2 * fil_hd(2) + Rec_len ) / Rec_len;
   
% Code to write the file header 
   fprintf(fid,'%6s\r\n%6d\r\n%6d\r\n%6d\r\n%6d\r\n%6d\r\n','TYPEA1',Rec_len,...
   floor(Nrec),fil_hd(2),fil_hd(3),fil_hd(4));
   
else
    if strcmp(fil_typ, 'HTK')

        HTK_Header = fil_hd;
        % nSamples     - number of frames
        % sampPeriod   - frame rate in 100ns units
        % sampSize     - number of features per frame
        % sampKind     - MFCC_0_E
        
        fwrite(fid, 0, 'int32');                               % num frames to be adjusted after speechfile is read
        fwrite(fid, HTK_Header.FrameRate * 10000, 'int32');    % frame rate in 100 ns unit   (This is the sample Period)
        fwrite(fid, HTK_Header.Num_features * 4, 'int16');     % number of features per frame 
                                                               % 
        HTK_Parameter = Text2HTKParm(HTK_Header.ParmKind);     % Convert text parameter to HTK coded format
        fwrite(fid, HTK_Parameter, 'int16');                   % parameter kind
    end   
end

% close the file
fclose(fid);