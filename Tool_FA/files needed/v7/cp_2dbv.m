function [BvF, BvT] = cp_2dbv(Block_length, N_startf, N_finalf, NumDCS, NumDCTC, F_Warp_Fact, T_Warp_S, T_Warp_E, ...
       BVF_flag, BVT_flag, EnNorm_flag);

%  Advanced version of comp_feat.m   by adding DCS_length changing paras
%  adding energy increasing
%  This comp_feat has a function to compute a [i, j, k] feature matrix by
%  using DCT based transformation method with a frequency-by-time matrix X 
%  Programmer         :  Jiang Wu
%  Creation date      :  11 - 14 - 2007
%  Last Revised data  :  05 - 06 - 2008
%  Version 2.0
%%            Basis vector controlling parameters setting
%  Block_length        =  Length of block in frames / also the DCS length
%  Block_spacing       =  Length of spacing between each block in frames
%  FI_length           =  Number of Frequency Samples
%  NuDCS               =  number of DCS (j) to use 
%  NuDCTC              =  number of DCTC (i) to use
%-------------------------------------------------------------------------%
%%            Warping function parameters setting
%  F_Warp_Fact         =  factor of freq warping function
%  T_Warp_S            =  starting factor of time warping fuction
%  T_Warp_E            =  ending factor of time warping fuction
%-------------------------------------------------------------------------%
%%            Possibly-used sub-routine 
%  GS1.m 
%-------------------------------------------------------------------------%
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Compute frequency warping 
FI_length = N_finalf - N_startf + 1;
w = 1: FI_length+1;
w = ((w-.5).*pi)./(FI_length+1);
fWARP = w +(2*atan((F_Warp_Fact*sin(w))./(1.-(F_Warp_Fact*cos(w)))));    
for f = 1 : FI_length
    Resol(f) =  fWARP(f+1) - fWARP(f) ./ (f+1-f);    %% Compute resolutions
end
Max_DCS  = Block_length;       %% Max_DCS length in frame
Resol_MAX = Resol/max(Resol);
length_DCS = round(Max_DCS.*Resol_MAX);     %% Range_DCS possibly taken
                                            %% Compute Frequency Warping
SLOPE = 2.0* pi/(fWARP(FI_length+1)+ fWARP(FI_length)- fWARP(1)- fWARP(2));
B = 0.5 * (-SLOPE) * (fWARP(1) + fWARP(2)); 
for i = 1 : NumDCTC 
    for f = 1 : FI_length;
        W = (i-1) *( .5* SLOPE * (fWARP(f)+fWARP(f+1)) + B );
        BvF(f,i) = (fWARP(f+1) - fWARP(f)) * cos(W);
    end
    summ = sqrt(sum(BvF(:, i).^2));
    BvF(:, i) = BvF(:, i)/summ;   %% get BVF , a f-by-i matrix
end

if BVF_flag
    BvF = GS1 (BvF);             %% get total i-set BVF(f) 
end
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Compute time-warping
T_Warp_E = T_Warp_S;
delta_warp = (T_Warp_E - T_Warp_S)/ (FI_length-1);   %% Beta controlling
w = 1: FI_length+1;
w = ((w-.5).*pi)./(FI_length+1);
tWARP = zeros(Block_length, FI_length);
if EnNorm_flag
    eDCS = 20*log10(length_DCS(:));                      %% energy ratio
else 
    eDCS = ones(FI_length);
end

%% Time_warping function : theta(t, f)
for f = 1 : FI_length       
    if rem(length_DCS(f), 2) == 0
        length_DCS(f) = length_DCS(f)+1;
    end

    beta       = T_Warp_S + (f-1)*delta_warp;
    pointer    = (Block_length - length_DCS(f))/2 + 1;
    window     = kaiser(length_DCS(f), beta);
    tWARP(pointer : pointer + length_DCS(f)-1, f) = window(:)/eDCS(f); 
end


for f = 1 : FI_length
    dw = tWARP(1:Block_length-1, f) + tWARP(2:Block_length, f);
    dw = [dw; 0]; 
    scale = sum(dw);
    range = (pi/Block_length) * (Block_length-1);
    scale = range/scale;
    dw =dw*scale;  
    for j = 1 : NumDCS   
        w = .5 * pi/Block_length;   
        for t = 1:Block_length;
            BvT(t, f, j) =  tWARP(t,f) * cos(w*(j-1)) / Block_length;
            w = w + dw(t);
        end
    end
end 
BVX = zeros (FI_length, Block_length, NumDCS);
for j = 1:NumDCS
    BVX(:, :, j) = BvT(:, :, j)';
end
BvT = BVX; 

if BVT_flag
    OBVT = zeros (Block_length * FI_length , NumDCS); 
    for i = 1 : NumDCS
        for t = 1 : Block_length
            pointer = (t-1) * FI_length + 1;
            OBVT(pointer:pointer+FI_length-1 ,i) = BvT(1:FI_length, t, i);
        end
    end
    OBVT = GS1 (OBVT);
    BvT = abs(reshape (OBVT, FI_length, Block_length, NumDCS));
else
    for f = 1:FI_length
        % calculate a sum over all values of the first DCS
        btsum = sum(BvT(f,:,1));
        % rescale the basis vectors
        BvT(f,:,:) = BvT(f,:,:) / btsum;
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
 

