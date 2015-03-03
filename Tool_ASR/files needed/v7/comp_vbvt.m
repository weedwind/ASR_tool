function [BVT] =  comp_vbvt(stWarp, edWarp, nFreqMin, nFreqMax, lenBlock, numDCSs, normFlag);
% COMP_VBVT Create Time Variable Basis Vectors
% function [BVT] =  comp_vbvt(stWarp, edWarp, nFreqMin, nFreqMax, lenBlock,
% numDCSs, normFlag) Creates Time Variable Basis Vectors for DCTC/DCS calculation
%
% INPUTS:
%   stWarp:   Start time warping factor
%   edWarp:   Stop time warping factor
%   numVectors: Number of Vectors
%   fileType: File type of feature file
%   feat:     feature array
%
% OUTPUTS:
%   BV:       Basis Vectors

%   Creation date:  02/20/2008
%   Programmer   :  Hongbing Hu, Jiang Wu

numFreqs = nFreqMax - nFreqMin + 1;

warpDelta = (edWarp - stWarp)/ (numFreqs-1); 
%% Time_warping function : theta(t, f)
for f = 1:numFreqs
    beta =  stWarp + (f-1)*warpDelta;
    tWARP(:,f) = kaiser(lenBlock, beta); 
end 

%% Step 2 : compute j sets of theta(t,f)
BVT =  zeros(lenBlock, numFreqs, numDCSs);
for f = 1 :numFreqs
    dw = tWARP(1:lenBlock-1, f) + tWARP(2:lenBlock, f);
    dw = [dw; 0]; 
    scale = sum(dw);
    range = (pi/lenBlock) * (lenBlock-1);
    scale = range/scale;
    dw =dw*scale;  
    
    for n = 1 : numDCSs   
        w = .5 * pi/lenBlock;   
        for t = 1:lenBlock
            BT(t, n) =  tWARP(t,f) * cos(w*(n-1)) / lenBlock;
            w = w + dw(t);
        end
    end
    
    
    if normFlag
        %% Gram-Schmidt process on the columns of A to orthonormal BVT
        BVT(:,f,:) = gs1(BT);
    else
        % calculate a sum over all values of the first DCS
        btsum = sum(BT(:,1));
        % rescale the basis vectors
      	BVT(:,f,:) = BT(:,:) / btsum;
    end
end 
