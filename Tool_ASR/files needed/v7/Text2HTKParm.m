 % ----------------------------------------------------------------------------
 % FUNCTION NAME: TextToParmKind
 %
 % PURPOSE:       Converts ASCII HTK parameter description to parameter kind
 %                integer to be written into HTK header
 %
 % INPUT:
 %   instr        Pointer to input parameter string
 %   parmKind     Pointer to output parameter kind integer
 %
 % OUTPUT
 %                Output parameter kind integer
 %
 % RETURN VALUE
 %   0            If input parameter string is incorrect
 %   1            Otherwise
 %
 % Copyright (c) 1998 Nokia Research Center, Tampere, Finland
 %---------------------------------------------------------------------------*/
function[CodedHTKParm] = TextToCodedHTKParm(inString)
 
CodedHTKParm = 0;
idx = length(inString);
underscore = '_';
while strcmp(inString(idx-1),underscore)
    
  if (idx >= 2)
    switch ( inString(idx) )
      case 'E' 
          CodedHTKParm = CodedHTKParm + 64;     % 64 decimal = 000100  octal = 01 000000  
      case 'N' 
          CodedHTKParm = CodedHTKParm + 128;                 % 000200  octal
      case 'D' 
          CodedHTKParm = CodedHTKParm + 256;                 % 000400  octal
      case 'A' 
          CodedHTKParm = CodedHTKParm + 512;    % 001000  octal
      case 'C' 
          CodedHTKParm = CodedHTKParm + 1024;   % 002000  octal
      case 'Z' 
          CodedHTKParm = CodedHTKParm + 2048;   % 003000  octal
      case 'K' 
          CodedHTKParm = CodedHTKParm + 4096;   % 010000  octal
      case '0' 
          CodedHTKParm = CodedHTKParm + 8192;   % 020000  octal
      otherwise
          % no extension
    end
  end
  idx = idx - 2;
end
inString = inString(1:idx);

switch (inString)
  case 'WAVEFORM'  
      % Waveform is the default;
  case 'LPC'       
      CodedHTKParm = CodedHTKParm + 1;
  case 'LPREFC'    
      CodedHTKParm = CodedHTKParm + 2;
  case 'LPCEPSTRA' 
      CodedHTKParm = CodedHTKParm + 3;
  case 'LPDELCEP'  
      CodedHTKParm = CodedHTKParm + 4;
  case 'IREFC'     
      CodedHTKParm = CodedHTKParm + 5;
  case 'MFCC'      
      CodedHTKParm = CodedHTKParm + 6;
  case 'FBANK'     
      CodedHTKParm = CodedHTKParm + 7;
  case 'MELSPEC'   
      CodedHTKParm = CodedHTKParm + 8;
  case 'USER'      
      CodedHTKParm = CodedHTKParm + 9;
  case 'DISCRETE'  
      CodedHTKParm = CodedHTKParm + 10;
  otherwise 
      disp('Warning -> Text2HTKParm.m: No HTK parameter type'); 
end