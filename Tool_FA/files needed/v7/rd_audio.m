function[d, fs, l, r, c, b] = rd_audio(filename, filetype, fs)
% RD_AUDIO - Program to read audio files
%   [d, fs, l, r, c, b] = rd_audio(filename, filetype)
%   reads SPHERE(NIST) or WAVE(Microsoft Wave Format-RIFF) files.
%   If the file is of type NIST then the function rdsphere is called.
%   [y, Fs, N, W, A, C, B] = rdsphere(filename)
%   If the file is of type RIFF then wavread  function is called.
% 
% INPUTS: 
%   filename - name of the file with path or partial path
%   filetype - 'SPHERE' or 'WAVE' (OPTIONAL)
%   example [...]=read_audio('foo.wav','SPHERE')
%           or
%           [...]=read_audio('foo.wav','WAVE')
%           or
%           [...]=read_audio('foo.wav')
% OUTPUTS: 
%   d   - data array with columns equalling the number of channels
%   fs  - sampling rate
%   l   - number of data samples
%   r   - number of bits per sample
%   c   - number of channels
%   b   - number of bytes per sample
% 
% NOTE: 1. The function rdsphere.dll and rdsphere.m must be in the working directory
% NOTE: 2. This function return raw samples of speech without scaling
 
% read_audio - Program to read audio files
% Programmer : Jaishree. V
% Date       : 03/01/99
% Revision   : 11-16-99 Montri K.
% Revision   : 11-19-99 Montri K. ( call rdsphere with no scaling option )
% version    : 0.3

N_CHANNELS  = 1;
ONE_BYTE    = 1;
TWO_BYTE    = 2;
d=[];
l=0;
r=0;
c=0;
b=0;

nargchk(1,3,nargin);          % to check the number of input arguments

% if the filetype is not given then it is read from the file
if nargin<2 
    fid=fopen(filename,'r') ;  
    if fid == -1
        error('RD_AUDIO -> Error: Cannot open %s\n',filename);
    end
    ftype=fread(fid,4,'uchar');
    fclose(fid);
    ftype1=ftype';
    filetype=char(ftype1);
end
if nargin<3
    fs = 0;              % Default sampling rate                 
end

switch upper(filetype)
 case {'SPHERE', 'NIST'}
  % reads the NIST or SPHERE file (no scaling)
  [d, fs, r] = rd_nist(filename); 
  l = length(d);
  c = N_CHANNELS;
  if r<=8
      b = ONE_BYTE; 
  elseif r<=16
      b = TWO_BYTE;
  end
  
 case {'WAVE', 'RIFF'}
  % reads the WAVE or RIFF file
  [d,fs,r]=wavread(filename);  
  [l,c]=size(d);
  % number of bytes per sample is 1 if bits per sample is <=8
  if r<=8
      b = ONE_BYTE; 
  elseif r<=16
      b = TWO_BYTE;
  end
  % Amplify data
  d = d * 2^(r-1);
  
  
 case {'RAW'}
  % Read Headless RAW file, make sure the following parameters are correct
  d = rd_raw(filename); % reads the RAW (nohead) file with no scaling
  l = length(d);
  c  = N_CHANNELS;
  b  = TWO_BYTE;
  r  = b*8;
  % Normalize to the range [-1:1]
  % d = d/power(2,b*8-1);
  
 otherwise
  error('Unsupported file type');
end



