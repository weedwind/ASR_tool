function [data, sample_rate, bits_per_sample] = rd_nist(filename, option)
%
% RD_NIST Read a NIST_1A (sphere format) file
%
% [data, sample_rate, bits_per_sample] = rd_nist(filename, option)
% INPUTS: 
%   filename: Name of input file
%   option  : parameters to control file reading behavior, if ommitted, all
%             speech samples in the file will be read in on shot
%             if option = [0, n1, n2], return total number of
%             samples in in 'data', n1 and n2 are ignored.
%             if option = [1, n1, n2], read data from sample #n1 to
%             sample #n2,'data' holds all those samples.
%
% OUTPUTS:
%   data:     contains speech samples, if option(1) == 0, this variable 
%             holds number of samples available in the input file
%   sample_rate: sampling frequency used in digitizing process
%   bits_per_sample: number of bits per sample used in digitizing process
%                   (useful for scaling)
%
% Limitations: 
%       - support only 1 or 2 data channels 
%       - only data of 1st channel will be returned for 2-channel data
%       - not support bits per sample larger than 16 bits
%       - not support bytes per sample larger than 2 bytes
%       - not support byte format 10

% Programmer : Montri K.
% Date       : 12\2\99
% Version    : 0.1

data=[];
sample_rate=0;
bits_per_sample=0;

if nargin < 1
    error('Usage: [data, sample_rate, bits_per_sample] = RD_NIST(filename, option)');
elseif nargin == 2
    if (option(1) == 1 && length(option) < 3)
        error('RD_NIST.M -> Error: option must have at least 3 elements');
    end
    have2args = 1; % yes we have 2 args
else % 1 nargin 
    have2args = 0;
end


% open file for read
fid = fopen(filename,'r');
if fid == -1
    error('RD_NIST.M -> Error: Cannot open %s!',filename);
end

% check file type
s = fgetl(fid);
if ((~strcmp(s,'NIST_1A')) && (~strcmp(s,'NIST_1A_mic')))
    fclose(fid);
    error('RD_NIST.M -> Error: %s is not an NIST_1A file!',filename);
end

header_size = str2num(fgetl(fid));
endian = 'ieee-le';
   
while ~feof(fid)
   s = fgetl(fid);
   [var_name, s] = strtok(s);
   [dummy, value] = strtok(s);
   
   switch upper(var_name)
    case 'CHANNEL_COUNT'
     channel_count = str2num(value);
     if channel_count > 2
         fclose(fid);
         error('RD_NIST.M -> Error: Not support > 2 channels!');
     elseif channel_count > 1
         warning('RD_NIST.M -> Warning: Multi-channel data, only first channel data will be returned');
     end
     
    case 'SAMPLE_COUNT'
     sample_count = str2num(value);
     
    case 'SAMPLE_RATE'
     sample_rate = str2num(value);
     
    case 'SAMPLE_N_BYTES' 
     sample_n_bytes  = str2num(value);
     bits_per_sample = 8*sample_n_bytes;
     if sample_n_bytes > 2
         fclose(fid);
         error('RD_NIST.M -> Error: Not support > 2 bytes per sample!');
     end
     
    case 'SAMPLE_BYTE_FORMAT'
     sample_byte_format = str2num(value);
     if ( sample_byte_format==1 )
         endian = 'ieee-le';
     elseif ( sample_byte_format==10 )
         endian = 'ieee-be';
     else
         fclose(fid);
         error('RD_NIST.M -> Error: Not support byte format %d!',sample_byte_format);
     end
     
    case 'SAMPLE_SIG_BITS'
     bits_per_sample = str2num(value);
     if bits_per_sample > 16
         fclose(fid);
         error('RD_NIST.M -> Error: Not support bits_per_sample > 16!');
     end
     
    case 'END_HEAD'
     break;
   end % switch
end % end while loop
% go back to the beginning
fclose(fid);

fid = fopen(filename,'r', endian);

if have2args == 1
    if option(1) == 0
        data = sample_count; % return sample_count 
   	fclose(fid);
        return;
    else
        n1 = option(2);
        n2 = option(3);
        
        if n2 > sample_count
            n2 = sample_count;
            warning('RD_NIST.M -> Warning: n2 adjusted to sample_count:%d',n2);
        end
        
        if n1 < 1 || n2 < n1
            fclose(fid);
            error('RD_NIST.M -> Error: n1 < n2 or n1 < 1');
        end
        
        offset  = n1 - 1;
        sample_count = n2 - offset;
    end
else % only 1 input arg
    offset = 0;
end


% before reading speech samples, let's skip header + offset
header = fread(fid,header_size + offset*sample_n_bytes, 'char');

% read speech samples
if channel_count == 1
    if (sample_n_bytes == 2)
        data = fread(fid, sample_count,'short');
    else
        data = fread(fid, sample_count,'char');
    end
else
    if (sample_n_bytes == 2)
        data = fread(fid, sample_count * channel_count,'short');
    else
        data = fread(fid, sample_count * channel_count,'char');
   end
   % reshape data array
   data = reshape(data, size(data,1)/channel_count, channel_count);
   % return only first channel
   data = data(:,1);
end

if size(data, 1) ~= sample_count
   fclose(fid);
   error('RD_NIST.M -> Error: Data reading error!');
end
   
fclose(fid);
