function Y = PreFilt(Cmd, X, Len)

%  function Y = PreFilt(Cmd, X, Len)
%
%  Digital filter design and filtering routine
%
%  Inputs:
%    Cmd     -- Command, 'init'=Initialize, 'proc'=Run
%    X       -- If Cmd=='init',  X(1) represents cutoff freq. of the filter
%               If Cmd=='proc',  X is an array of data to be filtered
%    Len     -- If Cmd=='init',  Len is sampling rate (used to design the filter)
%               If Cmd=='proc',  Len is number of elements in X
%  Output:         
%    Y       -- Filtered signal (Y=[] if Cmd ~= 'proc')
%
%  Note 1: It is assumed in this version that X is a one-dimensional array.
%  Note 2: The implementation of this function is based on TFRONTC's Prefilt.c
%
%  Programmer  :  Montri K.
%  Date        :  11/17/99
%  Version     :  0.01
%

persistent A B    % filter coefficients
persistent Zi     % initial conditions

if nargin ~= 3
   disp 'PRE_FILT -> Usage: Y = Pre_File(Cmd, X, Len)'
   Y = [];
   return;
end

if Cmd == 'proc'  % run mode
   [Y Zf] = filter(B, A, X, Zi);
   Zi = Zf;  % update initial conditions for next iteration
   
elseif Cmd == 'init' % initialization mode
   
   ZERO1   = -.95;
	ZERO2   = 0.0;
	POLE_R  = 0.8;
	COEFF   = 6400;

	fPoleThetaPI = pi*2*X(1)/Len; % X is center freq. and Len is sampling rate
	a1 = 2.0*POLE_R*cos(fPoleThetaPI);
   a2 = -(POLE_R*POLE_R);

   fTemp = sqrt(1.0+a1*a1+a2*a2+2.0*(a1*a2-a1)*cos(fPoleThetaPI)-2.0*a2*cos(2.0*fPoleThetaPI));
   
   A  = [1; -a1; -a2];
   B  = [fTemp * 5.0; fTemp*(ZERO1+ZERO2); fTemp*(ZERO1*ZERO2)];
   Zi = zeros(2,1);
   Y  = [];
end

