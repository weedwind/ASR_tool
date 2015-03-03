function[]=wr_token(fil_nam,fil_typ,fil_hd,tok_hd,Tagnam,X)
% function[]=wr_token(fil_nam,fil_typ,fil_hd,tok_hd,Tagnam(id,:),X)
%
% Program to write the tokens for the TypeA1 and TypeB1
% 
% Inputs are 
% fil_nam      -  Name  of the output file
% fil_typ      -  Type of the file(TYPEA1 or TYPEB1, or HTK)
% fil_hd(1)    -  rec_len ( record length for binary files )
% fil_hd(2)    -  Ncat ( Number of categories )
% fil_hd(3)    -  Nvar ( Number of variables )
% fil_hd(4)    -  Number of tokens 
% fil_hd(5)    -  Frame rate (in ms) for HTK type
% tok_hd(1)    -  Index
% tok_hd(2)    -  Number of frames for each token
% Tagnam(id,:) -  32 character ASCII label for one token(stimulus)
% X            -  Data matrix of parameter values for one token (nVar x nFrm)
% 
% The token format for the TYPEA1 and TYPEB1 files are
%    1    4    10 j:\temp\files\sx123 vowel de     - Token header
% Index(4) Nframes(4) Nvar(4) Tagnam(32) size are given in braces  
%   Data is written in floating point 32 numbers
%
%   In TYPEA1 the data is displayed as 5 columns for ease of use
% file for the Tfrontm
%
%
%  HTK type: We need to swap data bytes for HTK file format. There is 
%            no Matlab functions to do this. A trick is to write the feature
%            file normally. Then read in the data in the file in 'char' format
%            (byte-by-byte reading) in to a 4xN matrix. Next swap rows then write
%            the data back to file.
%          : As of 1-5-00, no byte swaping is perform with HTK file format. This will
%            make code run faster. However, NATURALREADORDER and NATURALWRITEORDER 
%            parameters must be set to TRUE in HTK tools' command file. See HTK manual
%            for more detail.
%
% Programmer : Jaishree. V.
% Date       : 10\24\99
% Revision   : 11-15-99  Montri K.
%            : 11-23-99  Montri K. -- add HTK file type
%            : 1-5-00    Montri K. -- no byte swapng for HTK file type
%            : 5-25-03   Penny Hix -- Added Nframes and NFeatures to make
%                                     code more readable.
%            : 2-5-04    Penny Hix -- added code to adjust the number of
%                                     features when the file type is HTK and the frame level log
%                                     energy has been included.
% Version    : 0.4

% The file is opened with append permission to append the tokens
%
% Initializing variables
Nframes   = tok_hd(2);
%NFeatures = fil_hd.Num_features;

if ~strcmp(fil_typ,'HTK')
   Rec_len=fil_hd(1);
end
 
% Check the file type 
if strcmp(fil_typ, 'TYPEB1')
   
    fid=fopen(fil_nam,'a'); % append
    % Code to write the token header for TYPEB1 file
    Nrec=floor((10 + (Nframes * fil_hd(3)) + Rec_len)/Rec_len);
    fwrite(fid,tok_hd(1),'integer*4');
    fwrite(fid,Nframes,'integer*4');
    fwrite(fid,Nrec,'integer*4');
    
    % Tagnam must have 32 chars
    if length(Tagnam) ~= 32
      Tagnam = ['                                  ', Tagnam]; 
      Tagnam = Tagnam(length(Tagnam)-31:length(Tagnam));
    end
    
    fwrite(fid,Tagnam,'uchar');
    
    % write all frames at one time
    fwrite(fid,X(1:fil_hd(3),1:Nframes),'float32');
   
    % Code to fill the rest of the token(record) with zeros if
    % the data written < rec_len * Nrec
    fwrite(fid, zeros(Rec_len*Nrec - Nframes*fil_hd(3)-11,1) ,'float32');
    fclose(fid);

elseif strcmp(fil_typ, 'TYPEA1')
   
   fid=fopen(fil_nam,'a'); % append
   %  Code to write the token for the TYPEA1 file
   fprintf(fid,'%6d%6d%6d %s\r\n',tok_hd(1),Nframes,fil_hd(3),Tagnam);
  
   if(mod(fil_hd(3),5)>0)
      fprintf(fid,'\r\n');
   end
          
   %  Code to write and format the data in 5 columns
   %  Each frame starts in a new line          
   for j = 1:tok_hd(2)
      for  k = 1:fil_hd(3)
         fprintf(fid, '%15.6e', X(k,j));
   		  if ~rem(k,5)
       	  fprintf(fid, '\r\n');
         end
      end
      % add new line if (#var % 5) ~= 0
      if rem(fil_hd(3),5)
         fprintf(fid, '\r\n');
      end
   end
   fclose(fid);
elseif strcmp(fil_typ, 'HTK')
    
    NFeatures = fil_hd.Num_features;
    
    fid = fopen(fil_nam, 'wb');
    if fid > 0
        
        HTK_Header = fil_hd;
        HTK_Parameter = Text2HTKParm(HTK_Header.ParmKind);  % Convert text parameter to HTK coded format
        
        % Make sure the number of features is correct when the Log Energy has been included.  In this case 
        % the Log Energy vector has been appended to the 13 component static feature vector
        count_features = size(X,1);
        if (HTK_Header.Num_features+1 == count_features)
            HTK_Header.Num_features = count_features;
            Nfeatures = count_features;
        end
        
        % Write Header to output file 
        fwrite(fid, HTK_Header.nSamples, 'int32');          % num frames
        fwrite(fid, HTK_Header.FrameRate * 10000, 'int32'); % frame rate in 100 ns unit (This is the sample Period)
        fwrite(fid, HTK_Header.Num_features * 4, 'int16');  % number of features per frame 
        fwrite(fid, HTK_Parameter, 'int16');  
        
        % Write features to output file
        fwrite(fid,X(1:NFeatures,1:Nframes),'float32');     % Writes the matrix data to a file.  Stores the data as an
                                                            % (NFeature * Nframes) x 1 vector.  The data goes into the vector
                                                            % column by column  so every NFeatures elements starts a new segment
                                                            % in the vector and there will be Nframes segments.
    else 
        disp('ERROR: -> WR_TOKEN:  Cannot write the token to the output file');
        return;
    end

    fclose(fid);
end
   


