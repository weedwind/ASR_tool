function [Pitch, numframes] = readPraat(filename)
% READPRAAT Read Praat output file (Pitch file only)
% [Pitch, numframes] = readPraat(filename) Reads Praat output file 
% (Pitch file only)
%
% INPUTS:
%   filename -- feature file
% OUTPUTS:
%   Pitch    -- output data, an NFRAME x NVAR matrix possible future outputs
%   numframes-- number of frames
%
%  NOTES:
%     Checking corresonding Praat script file to make sure the
%     behavior of the program 


fp = fopen(filename, 'rt');
if (fp == -1)
    error('Cannot open %s!', filename);
end

filetype = fgetl(fp);
if ~strcmp(filetype, 'File type = "ooTextFile"')
    error('Wrong file type. [%s]', filetype);
end
objclass = fgetl(fp);
if (~strcmp(objclass, 'Object class = "Pitch"') &&  ~strcmp(objclass, 'Object class = "Pitch 1"'))
    error('Wrong object class. [%s]', objclass);
end
fgetl(fp);

% Read paramters
% Cotents of Pars: [xmin, xmax, nx, dx, x1, ceil, maxcands]	
Pars = fscanf(fp, '%f', 7);	
% The third item is the number of total frames
numframes = Pars(3);

% Read pitch candidates frame by frame
Pitch = size(1,numframes);
for n=1:numframes
    try
        intensity = fscanf(fp, '%f', 1);	
        ncands = fscanf(fp, '%f', 1);	
        candidates = fscanf(fp, '%f', ncands*2);
        Pitch(n) = candidates(1);
    catch
        error('Error in reading pitch candidates. [%n]', n);    
    end
end
fclose(fp);
