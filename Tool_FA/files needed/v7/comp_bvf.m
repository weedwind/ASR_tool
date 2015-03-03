function [BV,delta,delta1] =  comp_bvf(BTWC, N_startf, N_finalf, IP, flag);
%  function [BV,delta] =  comp_bvf(BTWC, N_startf, N_finalf, IP, flag);
%
%  This function is used to compute a set of "warped" cosine
%  basis vectors over frequency  
%  Note: This version give identical set of bv as compared to tfrontc
%        IF normalization flag is 1 (orthonormalization is performed),
%        otherwise this version will
%        result in normalized bv. Tfrontc version will not give normalized bv.
%
%  Input variables
%
%  BTWC       =  bilinear warping factor (typically .45 )
%  N_startf   =  Index of first FFT sample to use
%  N_finalf   =  Index of last FFT sample to use
%  IP         =  number of basis vectors to use
%  flag       =  0 for no orthonormalization
%  flag       >= 1 for othonormalization
%
%  Output variables
%
%  BV2  is the (N_f_samp)x(IP) matrix which stores basis vectors
%  where N_f_samp =  N_finalf - N_startf + 1
%
%  Revision - The basis vectors are orthonormalized using the 
%  gram schmidt orthonormalization procedure.

%  Programmer    :  S A. Zahorian
%  Creation date :  April 24, 1999
%  Revision date :  April 24, 1999
%  Revision date :  May   10, 1999 ( Jaishree .V.)
%                : 12-14-99 Montri, Make SLOPE computation match TFRONTC
%                                 , Make BV scaling more efficient
%
N_f_samp = N_finalf - N_startf + 1;

%  w1 =  N_startf: N_finalf+1 ;

w1  = 1: (N_f_samp+1);
w1 =  ((w1-.5).*pi)./(N_f_samp+1);

WARP=w1+(2*atan((BTWC*sin(w1))./(1.-(BTWC*cos(w1)))));
WARP1=w1+(2*atan((-BTWC*sin(w1))./(1.+(BTWC*cos(w1)))));
WARP1 = WARP1- WARP1(1);


%  WARP contains the warping function

%  previous statement
%  SLOPE = 2.0* pi/(WARP(N_f_samp)+ WARP(N_f_samp-1)- WARP(1)- WARP(2));
%  Montri: match with tfrontc


SLOPE = 2.0* pi/(WARP(N_f_samp+1)+ WARP(N_f_samp)- WARP(1)- WARP(2));

B = 0.5 * (-SLOPE) * (WARP(1) + WARP(2));

%  Compute basis vectors--- Normalize
BV = zeros(N_f_samp, IP);
for k = 1:IP;
    for j = 1:N_f_samp;
        W = (k-1) *( .5* SLOPE * (WARP(j)+WARP(j+1)) + B );
        BV(j,k) = (WARP(j+1) - WARP(j)) * cos(W);
    end
    
    summ = sqrt(sum(BV(:,k).^2));
    BV(:,k) = BV(:,k)/summ;
end

%   Compute the derivative of the warping function

     for j = 1:N_f_samp
      delta(j) =  WARP(j+1) - WARP(j);
     end

     delta = delta/(delta(1));

%     plot(delta)
%     pause

%    delta1 is the normalized prewarping function
     delta1 =1+ N_f_samp*(WARP1(1:N_f_samp))/WARP1(N_f_samp); %


%  next orthonormalize the basis vectors using
%  the gram schmidt orthonormalization procedure

if (flag >  0 )
    BV = gs1(BV);
end

