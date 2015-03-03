%    March 21, 2012
%    Update April 3, 2012,  April 4, 2012
%    Update:   April 25, 2012

%   Programmer:  S. A.  Zahorian


%    Test of different nonlinear sigmoidal type functions

%   map  the range of -1  to 1  to same range ,  but with sigmoidal
%   type nonlinearity

     function y =  nonlin5a(a, b, x, Num_steps)


%    this function is is used to nonlinearly map  the x vector
%    to the y vector,  using the sigmoidal nonlinearity defined
%    by parameters  a,  b,  c

%    At a certain point in mapping, there is effectively table lookup
%    Num_steps is the number of steps (levels) in table

%     this is intended for nonlinear amplitude scaling of speech spectral data
%     after log scaling

%     written right now  to work on each frame,  leaving dynamic range
%     unchanged,

%    suggested settings for a, b, c  are given below
%


%     a,b,c,   control  type of nonlinearity

%     Let c = 0 for now

%     suggest trying these four cases

%     a,b =  10,0   =  steep symmetric nonlinearity
%     a,b =  3,0    =  mild  symmetric nonlinearity
%     a,b =  3,3  = compression at low levels,  linear  at high levels
%     a,b =  2,2  = milder from of 3,3, but same general effect
%     a,b =  4,1  = more compression at lows than highs
  

      c= 0;


      x_len = Num_steps;
      x_max = max(x);
      x_min = min(x);



      step_x0 = 2/(x_len-1);
      x0= -1: step_x0: 1;

      K = 2;

      y0 = a*x0 - b;
      z  = K* ((1 ./(1 + exp(-y0))) +c);




%     Now linearly rescale to fit to -1 1 range on z

       z1 = lin_str(z, -1, 1);

%     Map x from x_min to x_max linearly to the range [-1, 1]



       xx =   lin_str(x, -1, 1);

%      Now convert xx to rounded integers
%      1 to x_len


       offset = (x_len+ 1)/2;
       G = (x_len-1)/2;
       i_xx = round (G*xx + offset);




 %  Now map  x1 with the nonlinear sigmoid  to [-1, 1]



      xxx = z1(i_xx);

 %  Now linearly map back to original range


       y = lin_str(xxx, x_min, x_max);



