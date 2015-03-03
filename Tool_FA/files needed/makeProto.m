function [] = makeProto(config, hmmList, outDir)
%
% makeproto(configFile, hmmList, outDir) can be used to produce
% prototype HMMSets for  PLAINHS and DISCRETEHS systems
%
%
%   Creation date:  Nov.26 2007
%   Programmer   :  Hongbing Hu

% Global Variables
%nStates=0;                         # Number of active HMM states
%nStreams=0;                        # Number of streams
%vecSize=0;                         # Size of feature vector
%pKind="";                          # Parameter kind
%cKind="";                          # Covariance kind
%hsKind="";                         # System kind
%outDir="";                         # Output HMMSet directory
global configParams;                % Global store of config parameters


%***************************** START MAIN ***********************************
if (nargin > 0)
    configParams = ReadPCF(config);
    if (nargin>1)
	configParams.hmmList = hmmList;
    end
    if (nargin>2)
	configParams.outDir = outDir;
    end
    SetVars();
    WriteHMM();
else
    error('USAGE: makeproto ConfigFile [HMM list] [Output Dir]');
end

%******************************* END MAIN *********************************

%************************ Util Functions **********************************

%-------------------------------------
% ReadPCF: Reads the Proto Config File 
%-------------------------------------
function [configParams] = ReadPCF(configfile) 

%local($config)=@_;
%config = configfile
%local($validData,$param,$val)=0;
valid = 0;

config = fopen(configfile, 'r');
while(~feof(config))
    str = fgetl(config); 
    switch (str)
     case '<ENDsys_setup>'
      valid=0;
     case {'<BEGINsys_setup>', '<BEGINtool_steps>'}
      valid=1;
     otherwise
      if (valid)
          [param, val] = strtok(str, ':');
          if ~isempty(param)
              va = strtok(val,':');
              if isempty(str2num(va))
                  configParams.(param) = va(~isspace(va)); 
              else
                  configParams.(param) = str2num(va); 
              end
          end
      end
    end
end
fclose(config);
%configParams


%-----------------------------------------
% SetVars: Set variable from config params
%-----------------------------------------
function [] = SetVars()
global configParams;

nStates = configParams.nStates;
if ~(nStates >= 1), error('nStates must be >= 1'); end
nStreams = configParams.nStreams;
if (nStreams > 4), error('nStreams must be 1,2,3 or 4'); end
vecSize = configParams.vecSize;
if ~(vecSize >= 1), error('vecSize must be >= 1'); end
hsKind = configParams.hsKind;
%if ~(nnz(hsKind==['P','T','D']))
if ~(nnz(hsKind==['P','D']))
    error('hsKind must be P or D'); 
end
cKind = configParams.covKind;
if ~(nnz(cKind==['F','D']))
    error('covKind must be F or D');
end
pKind = configParams.parmKind;
if (hsKind=='D')
    if (pKind(end)~='V')
        error('If hsKind is D then parmKind must have _V appended');
    end
else
    if (pKind(end)=='V')
	error('If hsKind is not D then parmKind must not have _V appended');
    end
end
outDir = configParams.outDir;
if ~exist(outDir, 'dir'), error('Cannot open %s', outDir); end
hmmList = configParams.hmmList;
if ~exist(hmmList, 'file'), error('Cannot find HMM list file %s', hmmList);end


%-------------------------------------------------------
% WriteDiagCMixtures: write a diagonal covariance mixture
%-------------------------------------------------------
function []= WriteDiagCMixtures(pt, streamNum)
global configParams;

for n=1:configParams.mixes(streamNum)
    fprintf(pt, '  <Mixture> %d %1.4f\n', n, 1.0/configParams.mixes(streamNum));
    fprintf(pt, '    <Mean> %d\n', configParams.sWidths(streamNum));
    fprintf(pt, '      ');
    for k=1:configParams.sWidths(streamNum)
        fprintf(pt, '0.0 ');
    end
    fprintf(pt, '\n');
    fprintf(pt, '    <Variance> %d\n',configParams.sWidths(streamNum));
    fprintf(pt, '      ');
    for k=1:configParams.sWidths(streamNum)
        fprintf(pt, '1.0 ');
    end
    fprintf(pt, '\n');
end

%-------------------------------------------------------
% WriteFullCMixtures: write the full covariance mixtures
%-------------------------------------------------------
function [] = WriteFullCMixtures(pt, streamNum)
global configParams;

tmpVecSize=configParams.sWidths(streamNum);

for n=1:configParams.mixes(streamNum)
    fprintf(pt, '  <Mixture> %d %1.4f\n', n, 1.0/configParams.mixes(streamNum));
    fprintf(pt, '    <Mean> %d\n', configParams.sWidths(streamNum));
    fprintf(pt, '      ');
    for k=1:configParams.sWidths(streamNum)
        fprintf(pt, '0.0 ');
    end
    fprintf(pt, '\n');
    fprintf(pt, '    <InvCovar> %d\n', configParams.sWidths(streamNum));
    while (tmpVecSize>=1)
        for k=1:tmpVecSize
            if (k==1)
                fprintf(pt, '1.0 ');
            else
                fprintf(pt, '0.0 ');
            end
        end
        
        fprintf(pt, '\n');
        tmpVecSize = tmpVecSize-1;
    end
    tmpVecSize=configParams.sWidths(streamNum);
end

%----------------------------------------------
% WriteDProbs: Write the discrete probabilities
%----------------------------------------------
function [] =  WriteDProbs(pt, sNum)
global configParams;

mix = configParams.mixes(sNum);
fprintf(pt,'      <DProb> %d\n',-2371.8*log(1/mix)*mix);
%printf(PROTO "      <DProb> %d*$mixes[$s]\n",-2371.8*log(1/$mixes[$s]));


%----------------------------------------------
% WriteStates: Write the contents of the states
%----------------------------------------------
function [] = WriteStates(pt, hmmName) 
global configParams;

for n=1:configParams.nStates
    fprintf(pt, '  <State> %d <NumMixes> ',n+1);
    for k=1:configParams.nStreams
        fprintf(pt, '%d ',configParams.mixes(k));
    end
    fprintf(pt, '\n');
    for k=1:configParams.nStreams
        fprintf(pt, '  <Stream> %d\n',k);
        switch(configParams.hsKind)
         case 'D'
          WriteDProbs(pt, k);
         case 'P'
          if (configParams.covKind == 'D')
              WriteDiagCMixtures(pt, k);
          else
              WriteFullCMixtures(pt, k);
          end
         otherwise
          error('Unknown hsKind %s', configParams.hsKind);
        end
    end
end

%-----------------------------------------------------------
% WriteTransMat: Write the contents of the transition matrix
%-----------------------------------------------------------
function [] = WriteTransMat(pt)
global configParams;

nStates = configParams.nStates;
fprintf(pt, '  <TransP> %d\n', nStates+2);
for n=1:nStates+2
    for k=1:nStates+2
        if ((n==1)&&(k==2))
            fprintf(pt, '   1.000e+0');
        elseif ((n==k)&&(n~=1)&&(n~=nStates+2))
            fprintf(pt, '   6.000e-1');
        elseif (n==(k-1))
            fprintf(pt, '   4.000e-1');
        else
            fprintf(pt, '   0.000e+0');
        end
    end
    fprintf(pt, '\n');
end	    


%----------------------------------------
% WriteHMM: Write the contents of the HMM
%----------------------------------------
function [] = WriteHMM(hmmList)
global configParams;

hlist = fopen(configParams.hmmList, 'r'); 
while(~feof(hlist))
    hmmName = fgetl(hlist); 
    
    pt = fopen(fullfile(configParams.outDir, hmmName), 'w'); 
    if (pt == -1) 
        error('Cannot open %s for writing', hmmName);
    end
    fprintf(pt, '  ~o <VecSize> %d <%s>', configParams.vecSize, configParams.parmKind);
    fprintf(pt, ' <StreamInfo> %d %d \n', configParams.nStreams, configParams.sWidths);
    fprintf(pt, '  ~h "%s"\n', hmmName);
    
    fprintf(pt, '<BeginHMM>\n');
    fprintf(pt, '  <NumStates> %d\n', configParams.nStates+2);
    WriteStates(pt, hmmName);
    WriteTransMat(pt);
    fprintf(pt, '<EndHMM>\n');
    fclose(pt);
end
fclose(hlist);



