function [BV,f,g,h] = genbv(IP, Type, parms, flag)
%
%      General function to compute modifed cosine basis vectors
%      Basis vectors can be computed with several types of warping
%
%      Creation  Date:   August 25, 2008
%      Programmer:       Chen,Zhengqing
%      Modification Dates:   August 27, 2008 ,   Jan 10, 2009
%      Modification Made by: S.A.Zahorian
%      Modi_2nd: Adding Sigmoid as warping option,
%                editting Input-Output dictionary. by CZQ on 16-NOV-2008.
%      Modifications on comments-- Dec 1, 2008

%***********
% Input:
%***********
% * IP: the number of basis vectors to compute

% * TYPE: the specific type of non-linear warping to use.
%   'B' for Bilinear
%   'M' for Mel-scale 
%   'G' is for Gaussian
%   'K' for Kaiser Window
%   'N' for Non-symmetric Window
%   'S' for Sigmoid

%   Generally, B and M are appropriate for frequency warping
%   K, G,  and S  are for time warping
%   N  for ??

% * parms, short for 'parameters'.
%--------------------------------------------------------------------------
%    A 2 or 3 element vector of parameters
%     parms(1)  = N = number of samples for each returned vector
%     parms(2)  =  parameter which controls degree of warping
%     parms(3)  =  parameter which controls degree of warping (not always needed)
%     details of parms(2)  and parms(3)  depend on warping type (see below)

%---------------------------------------------------
% For Bilinear, 'type' is 'B', 'parms' are [N,alpha]
%  range for alpha: usually less than 1 
%  typical values for alpha: choice around 0.45
%---------------------------------------------------

%--------------------------------------------------------------------
% For Mel-scale, 'type' is 'M', 'parms' are [N,k]
  %% k is to control the log mel-scale's shape
  %% the smaller the k, the more mass put on the 'head' of log curve
%   range for k: usually less than 1
%   typical values for k: didn't figure out optimal number yet
%--------------------------------------------------------------------

%--------------------------------------------------------
% For Gaussian Window, parameters are [N,alpha]
% Range of alpha: found to be within [-8,8] 
% The bigger the alpha, the narrower the BV concentrates 
% Typical alpha: choice around 2.5 to 3
%--------------------------------------------------------

%-------------------------------------------
% For Kaiser Window, parameters are [N,beta]
% Range of beta:   0 to 100
% Typical beta:   5
%-------------------------------------------

%--------------------------------------------------------------------
% For Non-symmetric Window, parameters are [N,k1,k2]
  %% k1 control the head half, k2 control the rear half of the curve
  %% the bigger the k1, the smaller k2, the smoother the curve
  %% is. k2 should > k1, at least k2 ONLY slightly < k1
% Hasn't find optimal choice for k1, k2
% But k1 by experimental results is found not to exceed 0.61
%--------------------------------------------------------------------

%--------------------------------------------------------
%% 18-NOV-2008(CZQ)
%% For Sigmoid warping, parameters are [N,a,b]
%%% Where 'a' controls the degree of warping(sharpness)
%%%     without going too wild, let's set a ~ [4,64];
%%%       'b' controls the focus hump, centered on x=b
%%%     without going too wild, let's set b ~ (0,1);
%--------------------------------------------------------
%--------------------------------------------------------------------------

% * Flag:  when set Flag >= 1, othonormalize Basis Vector;
%          when set Falg = 0,do without othonormalization.
% *************************************************************************

%***********
% output:
%***********
%* BV: IP Basis Vectors, each of length N  (dimension(BV) is N-by-IP)
%*  f: the monotonously increasing,differentiable function within [0,1].
%      (f is the warping function)
%*  g: the derivative of f, scaled so that sum over [0,1] = 1. 
%   ?? Do we really need this scaling so that sum(g) = 1 ??
%*  h: the inverse function of f.
%      (also regard 'h' as the non-uniformly distributed samples)
% (the points from the 'h' set, warped by f,
%  will generate uniformly distributed samples between [0,1]) 



if ~strcmp(Type,'d')
    [f,g,h] = nlwarp(Type,parms);
    for i = 1:IP
       BV(:,i) = cos((i-1)*pi*f).*g;
    end

%if (Type == 'B')
%  Still not clear if this normalization should be there
%  for all types of warping and all types of basis vectors
%  particularly basis vectors over time versus those over frequency
%  Also, if orthonormalization is use, this  amplitude normalization
%  should not matter

    for k = 1:IP;
       summ = sqrt(sum(BV(:,k).^2));
       BV(:,k) = BV(:,k)/summ;
    end
else         % generate basis vectors for delta methods
    
    max_len=parms(1);         % this is the number of samples to be padded to
    
    BV(:,1)=[zeros(1,(max_len-1)/2),1,zeros(1,(max_len-1)/2)]';    % the first basis vector is always 0 order
    
    if IP==1      % only first order is needed
        BV(:,2)=[-parms(2):parms(2)]'/(2*sum([1:parms(2)].^2));
    end
    
    if IP==2      % 1st and 2nd order are needed
        BV1=[-parms(2):parms(2)]/(2*sum([1:parms(2)].^2));    % temp first order basis vector
        BV2=[-parms(3):parms(3)]/(2*sum([1:parms(3)].^2));    % temp second order basis vector (reference is delta)
        BV(:,2)=[zeros(1,(max_len-length(BV1))/2),BV1,zeros(1,(max_len-length(BV1))/2)]';  % final 1st order basis vector
        BV(:,3)=(conv(BV1,BV2))';             % final 2nd order basis vector
    end
    
    if IP==3     % 1st, 2nd, and 3rd orders are needed
        BV1=[-parms(2):parms(2)]/(2*sum([1:parms(2)].^2));    % temp first order basis vector
        BV2=[-parms(3):parms(3)]/(2*sum([1:parms(3)].^2));    % temp second order basis vector (reference is delta)
        BV3=[-parms(4):parms(4)]/(2*sum([1:parms(4)].^2));    % temp second order basis vector (reference is delta-delta)
        
        BV(:,2)=[zeros(1,(max_len-length(BV1))/2),BV1,zeros(1,(max_len-length(BV1))/2)]';  % final 1st order basis vector
        BV(:,3)=[zeros(1,(max_len-(length(BV1)+length(BV2)-1))/2),conv(BV1,BV2), zeros(1,(max_len-(length(BV1)+length(BV2)-1))/2)]'; %final 2nd order basis vector
        BV(:,4)=conv(conv(BV1,BV2),BV3);    % final 3rd order basis vector
    end
    f=[];g=[];h=[]; 
        
    

end
        

%end;


if (flag >  0 )
    BV = gs1(BV);
end

% 
%figure(2);
%plot(BV(:,1:3));title('Test Graph to show the first 3 Basis Vectors');
%legend('BV0','BV1','BV2');


%_________________________________________________________________________
% sub-routine for orthonormalization
function Q = gs1(A)              
%GS     Gram-Schmidt process on the columns of A.
%       Uses the Gram-Schmidt process to construct a matrix Q whose columns
%       form an orthogonal basis for the column space of the matrix A.  The
%       columns of A need not be linearly independent. Normalization is 
[m n] = size(A);

col = 1;

while (col<n & A(:,col)==zeros(m,1))
  col = col+1;
end

if (col==n & A(:,col)==zeros(m,1))
  error('The column space of the zero matrix has no basis.')
end

Q= A(:,col);                    %Place first nonzero column of A into Q               

for k = col+1:n                 %Begin Gram Schmidt orthogonalization process
   proj = zeros(m,1);           %Initialize the projection vector
   [r s] = size(Q);
   for j=1:s
      proj = proj + (A(:,k)'*Q(:,j))/(Q(:,j)'*Q(:,j))*Q(:,j);
   end
   newcol = A(:,k)-proj;        %Possible new column for Q
   if max(abs(newcol))<1024*eps %Don't augment Q with a column whose entries
     newcol = [];               %are so small they probably should be zeros
   end
   Q=[Q newcol];
end

format  
[r s] = size(Q);

for j=1:s
    Q(:,j) = Q(:,j)/norm(Q(:,j),2);
end

    

