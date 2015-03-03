function [] = wr_feat(featFile, fileType, Feat, iTok, numSenInGrp, frmRate, paramKind, tagnam)
% WR_FEAT Write feature file
%   [] = wr_feat(feat, filename, filetype) Writes features using ECE Speech Lab's
%   feature file (TYPEBA1 and TYPEB1) and HTK binary file formats.
%
% INPUTS:
%   featFile:  Name of feature file
%   fileType:  File type of feature file
%   feat:      feature array
%
% OUTPUTS:
%   None

%   Creation date:  02/06/2008
%   Programmer   :  Hongbing Hu

% Check arguments
if (nargin < 8 || isempty(tagnam))
    tagnam = featFile;
end

[numFeatures, numFrames] = size(Feat); 
switch (fileType)
 case 'TYPEA1'
  FileHdr = [12; 1; numFeatures; numSenInGrp];
  
 case 'TYPEB1'
  FileHdr = [numFeatures + 11; 1;  numFeatures; numSenInGrp];
  
 case 'HTK'
  if (numSenInGrp ~= 1)
      error('HTK formant support only NUM_SEN_GRP=1');
  end
  FileHdr.nSamples     = numFrames;    % nSamples = number of frames 
  FileHdr.FrameRate    = frmRate;      % sampPeriod = Frame Rate
  FileHdr.Num_features = numFeatures;  % sampSize = Num of Features
  
  if isempty(paramKind)	               % sampKind
      FileHdr.ParmKind = 'USER';
  else
      FileHdr.ParmKind = paramKind;      % Aurora Front End uses MFCC_0_E
  end
  
 otherwise
  error('Unknown file type %s', fileType);
end

if iTok == 1
    % create a new output file with header ready
    wr_head(featFile, fileType, FileHdr, 0);
end

% prepare to write features to file, we need only last 32 characters
TokenID = ['                                  ', tagnam];
TokenID = TokenID(length(TokenID)-31:length(TokenID)); 

% write feature into file
wr_token(featFile, fileType, FileHdr, [iTok;numFrames], TokenID, Feat);
  
  
