function KW = Comp_Kaiser(Length, Beta)

%function KW = Comp_Kaiser(Length, Beta)
%
%  This function is used to compute a Kaiser window of length = Length, beta = Beta
%
%
%  Inputs:
%   Length = length of window to compute
%   beta   = window beta
%
%  Output:
%   KW     = a column matrix of Length elements that contains Kaiser window
%
%  Note:  Actually Matlab has the Kaiser function to do this job. However I have
%         difficulties to compile this function with mcc -m command because Matlab's
%         Kaiser calls a mex function.
%
%  See also:  cp_bv2.c (CreateKaiserWnd())
% 
%  Subroutine used: bessel0 (defined at the end of this program)
%
%  Programmer  :  Montri
%  Date        :  12/09/99
%  Version     :  0.01
%


KW = zeros(Length,1);

alpha = (Length-1)/2;
den = bessel0(Beta);

for n=1:Length
   arg = ((n-1-alpha)/alpha)^2;
   arg = sqrt(1-arg) * Beta;
   num = bessel0(arg);
   KW(n) = num/den;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function S = bessel0(X)
% compute modified bessel function of the first kind
%
	dS = 1;
	D  = 0;
	S  = 1;
   
   dT = 1;
	while dT > 0
		D  = D + 2;
		dS = dS * (X*X)/(D*D);
		S  = S + dS;
		dT = dS - 0.2e-8 * S;
   end
   
