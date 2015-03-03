function [data] = rd_raw( filename, sample_n_bytes, option )
% function [data] = RD_RAW(filename, readParams)
% read a file with no header
%
% Inputs: 
%       filename            - Name of input file
%
%       sample_n_bytes      - Number of bytes per sample
%
%       option (OPTIONAL)   - parameters to control file reading behavior, if ommitted, all
%                             speech samples in the file will be read in at once
%                             if option = [0, n1, n2], return total number of samples in in 'data',
%                                                    n1 and n2 are ignored
%                             if option = [1, n1, n2], read data from sample #n1 to sample #n2,
%                                                  'data' holds all the samples 
%
% Outputs:
%       data                - Contains speech samples, if option(1) == 0, this variable 
%                             holds number of samples available in the input file
%
% Limitations: 
%                           - support only 1 or 2 data channels 
%                           - only data of 1st channel will be returned for 2-channel data
%                           - no support for bits per sample larger than 16 bits
%                           - no support for bytes per sample larger than 2 bytes
%                           - no support for byte format 10
%
% Programmer : Penny Hix
% Date       : 06/12/2003
% Version    : 0.1
%
% NOTE:     CHANNEL_COUNT is currently set to 1 and should be changed to allow the value to 
%           be set by the user.  The Aurora database consists of one channel.
%
% Local Constants
RESHAPE_DIM = 1;
CHANNEL_COUNT = 1;
OptionArg = -1;
 
switch (nargin)
    
case 0
   disp ( 'Usage: [data] = RD_RAW(filename, BytesPerSample, option)' );
   data = [];
   return
   
case 1
    % only the file name is supplied
    sample_n_bytes = 2;
    
case 2
    % file name and sample_n_bytes supplied
    OptionArg = 0; 
    
case 3
   if option(1) == 0
     OptionArg = 0;    % Option argument requires data = sample_count;
   elseif ( option(1) == 1 & length(option) ~= 3 )
	 disp ('RD_RAW.M -> Error: option must have 3 elements');
     data = [];
     return
   elseif ( option(1) == 1 & length(option) == 3 )
     OptionArg = 1;    % Correct input option supplied
   end
   
otherwise
    disp ( 'Usage: [data] = RD_RAW(filename, BytesPerSample, option)' );
    data = [];
end

% enforce maximum 2 byte sample size or minimum 1 byte sample size
if ( sample_n_bytes > 2 | sample_n_bytes < 1)
   disp('Warning -> RD_RAW: number of bytes per sample must be less than or equal to 2.  Resetting value to 2 bytes per sample');
   sample_n_bytes = 2;
end

% open file for read
fid = fopen(filename,'r');
if fid == -1
   disp ([sprintf('RD_RAW.M -> Error: Cannot open %s!',filename)]);
   data  = [];
return;
end

% read speech samples
if (sample_n_bytes == 2)
  [data,sample_count] = fread(fid, 'int16');
else
  [data,sample_count] = fread(fid, 'uchar');
end

% Calculate offset based on the values in the option variable and  
% re-read the file to get just the data between the given values.
if OptionArg == 1
   if ( option(1) == 1 )
      n1 = option(2);
      n2 = option(3);
      
      if n2 > sample_count
         n2 = sample_count;
		 disp ([sprintf('RD_RAW.M -> Warning: n2 adjusted to sample_count: %d', n2)]);
      end
      
      if  ( n1 < 1 | n2 < n1 )
		  disp ([sprintf('RD_RAW.M -> Error: n1 < n2 or n1 < 1')]);
	      data = [];
	      fclose(fid);
   	  return;
      end
      
      offset  = n1 - 1;
      sample_count = n2 - offset;
      
      % reset the file pointer so the file can be read beginning at the offset value
      frewind(fid)
      
      % skip offset
      offset_skip = fread(fid,offset*sample_n_bytes,'uchar');

     % read speech samples
     switch CHANNEL_COUNT
        case 1
	        if (sample_n_bytes == 2)
              [data,sample_count] = fread(fid, 'int16');
            else
              [data,sample_count] = fread(fid, 'uchar');
            end
        case 2
            if (sample_n_bytes == 2)
	          data = fread(fid, sample_count * CHANNEL_COUNT,'int16');
	        else
	          data = fread(fid, sample_count * CHANNEL_COUNT,'uchar');
            end
        otherwise
            disp('Error -> RD_RAW.M: Channel Count must be 1 or 2');
            data = [];
            fclose(fid);
            return;
     end
    end

  elseif OptionArg == 0
     data = sample_count; 
     return
  end

% reshape data array
data = reshape(data, size(data,RESHAPE_DIM)/CHANNEL_COUNT, CHANNEL_COUNT);
% return only first channel
data = data(:,1);

if size(data, 1) ~= sample_count
   disp ([sprintf('RD_RAW.M -> Error: Unable to properly re-sizing data array for given channel count!')]);
      
   data = [];  
   fclose(fid);
   return;
end
   
fclose(fid);   